# Design a News Feed System

**Category:** System Design / Classic Problems
**Difficulty:** Senior
**Tags:** `news-feed`, `fan-out`, `social-network`, `timeline`, `ranking`

## Question

> Design the news feed for a social network like Twitter or LinkedIn. Each user follows others; their feed shows posts from followees sorted by recency or relevance. The system must support 500 million users, with some celebrities having 50 million+ followers.

- Would you use fan-out on write or fan-out on read? Why?
- How do you handle the "celebrity problem"?
- How does ranking/personalisation fit in?

## Short Answer

For most users we use **fan-out on write**: when a user posts, we push the post ID into each follower's feed cache (Redis sorted set) immediately. For celebrities (>10K followers) we use **fan-out on read**: their posts are fetched and merged at read time. The feed service merges pre-computed timelines with on-the-fly celebrity lookups, applies a ranking model, and caches the final page. This hybrid avoids both write amplification for celebrities and read amplification for regular users.

## Detailed Explanation

### Functional Requirements

- User creates a post (text, images, video)
- User sees a personalised feed of posts from followees
- Feed sorted by relevance (default) or recency
- Likes, comments, shares are counted in near real-time
- Feed loads in <500 ms p99

### Two Approaches: Fan-out on Write vs Read

| | Fan-out on Write (Push) | Fan-out on Read (Pull) |
|--|------------------------|----------------------|
| **When** | At publish time | At feed request time |
| **Feed read** | Fast — pre-built in cache | Slow — merge N followees' posts |
| **Write cost** | High for celebrities | Low |
| **Stale risk** | Low | Low |
| **Best for** | Regular users (≤5K followers) | Celebrities (>5K followers) |

### Hybrid Architecture

```
Post Created
   │
   ├── Kafka topic: post_created
   │
   ├── Fan-out service (consumes post_created)
   │    ├── If author followers ≤ 5K:
   │    │    Push post_id into each follower's feed list (Redis sorted set, score=timestamp)
   │    └── If author followers > 5K (celebrity):
   │         Store post in celebrity_posts table only; skip per-follower push
   │
Feed Request (GET /feed)
   ├── Fetch user's pre-built timeline from Redis (fan-out-on-write posts)
   ├── Fetch IDs of celebrities the user follows from graph DB
   ├── Fetch each celebrity's latest posts (from celebrity_posts cache)
   ├── Merge + deduplicate + sort
   ├── Apply ranking model
   └── Cache final page for 60 s
```

### Data Model

**Post table** (DynamoDB or Cassandra — write-heavy, wide rows):
```
post_id     UUID  PK
author_id   UUID
content     TEXT
media_urls  LIST<TEXT>
created_at  TIMESTAMP
like_count  INT
```

**Feed table** (Redis Sorted Set per user):
```
Key:   feed:{user_id}
Score: Unix timestamp (for recency sort)
Member: post_id
TTL:   30 days (trim to latest 1000 entries)
```

**Social graph** (Neo4j or adjacency list in Cassandra):
```
user_id | follows_user_id | followed_at
```

### Ranking

Raw chronological feeds are replaced by a ranking model score:

```
score = w1×recency + w2×author_affinity + w3×engagement_velocity + w4×media_boost
```

- **Recency**: time decay, half-life of ~6 hours
- **Author affinity**: how often the viewer interacts with this author
- **Engagement velocity**: likes + comments in first 10 minutes (signals virality)
- **Media boost**: posts with images/video ranked higher

Ranking runs as a lightweight in-process model (ONNX runtime) to avoid a network hop.

### Handling the Celebrity Problem

A celebrity with 50M followers posting once would require 50M Redis writes — unacceptable (~500 s with 100K writes/s).

Solution:
1. Mark accounts with >5K followers as "high-fanout" (store flag in user profile).
2. Skip per-follower push; store post in a shared `celebrity_posts:{author_id}` sorted set.
3. At read time, the feed service fetches the viewer's celebrity follow list (cached in Redis for 5 min), queries each celebrity's post sorted set, and merges into the timeline.
4. The merge is bounded: a user typically follows ≤50 celebrities → 50 small Redis reads, parallelised in ~10 ms.

### Storage Capacity

| Resource | Estimate |
|----------|----------|
| Posts/day | 50M posts × 500 B avg = 25 GB/day |
| Feed entries (Redis) | 500M users × 1000 entries × 8 B (post_id) = ~4 TB |
| Redis nodes (256 GB each) | ~16 nodes |
| Read QPS peak | 500M users × 10 feed loads/day / 86400 × 3× peak = ~175K QPS |

### Media Storage

Post media (images, video) is stored in object storage (S3/Azure Blob), served via CDN. Posts reference URLs only; the feed service never proxies media — CDN handles all media traffic.

> **Warning:** Never store media in your relational or NoSQL post table — even as BLOBs. Always use object storage + CDN. Even a 1 MB average image turns the post table into a write bottleneck and destroys cache efficiency.

### Read Path: Step by Step

1. User opens feed → `GET /feed?userId=123&page=0`
2. Check Redis feed cache: key `feed_page:{userId}:{page}` (60 s TTL)
3. If miss: fetch `feed:{userId}` sorted set from Redis (last 200 post IDs)
4. Hydrate post IDs → post service (batch GET, cache per-post 5 min)
5. Merge celebrity posts (parallel Redis reads)
6. Apply ranking model
7. Return top 20; store rendered page in short-lived cache

## Code Example

```csharp
// Feed service — hybrid fan-out
using StackExchange.Redis;

namespace NewsFeed;

public sealed class FeedService(
    IDatabase redis,
    IPostRepository posts,
    ISocialGraphService graph)
{
    private const int PageSize = 20;
    private const int FeedDepth = 1000; // max entries per user feed

    // Write path: fan-out on write for regular users
    public async Task FanOutAsync(Post post, CancellationToken ct = default)
    {
        var followerIds = await graph.GetFollowerIdsAsync(post.AuthorId, ct);

        // Skip fan-out for high-fanout (celebrity) accounts — handled at read time
        if (followerIds.Count > 5_000)
        {
            await redis.SortedSetAddAsync(
                $"celebrity_posts:{post.AuthorId}",
                post.Id.ToString(),
                post.CreatedAt.ToUnixTimeSeconds());
            return;
        }

        // Push post_id into each follower's feed sorted set (batch pipeline)
        var batch = redis.CreateBatch();
        var tasks = followerIds.Select(followerId =>
            batch.SortedSetAddAsync(
                $"feed:{followerId}",
                post.Id.ToString(),
                post.CreatedAt.ToUnixTimeSeconds()));

        batch.Execute();
        await Task.WhenAll(tasks);

        // Trim to most recent FeedDepth entries per user
        foreach (var followerId in followerIds)
            await redis.SortedSetRemoveRangeByRankAsync(
                $"feed:{followerId}", 0, -(FeedDepth + 1));
    }

    // Read path: merge pre-built timeline + celebrity posts
    public async Task<IReadOnlyList<Post>> GetFeedAsync(
        Guid userId, int page, CancellationToken ct = default)
    {
        var skip = page * PageSize;
        var take = PageSize * 3; // fetch extra for ranking re-sort

        // 1. Pre-built timeline post IDs (most recent first)
        var timelineIds = await redis.SortedSetRangeByRankAsync(
            $"feed:{userId}", -skip - take, -skip - 1, Order.Descending);

        // 2. Celebrity posts (parallel fetch)
        var celebIds = await graph.GetCelebrityFolloweesAsync(userId, ct);
        var celebPostTasks = celebIds.Select(cid =>
            redis.SortedSetRangeByRankAsync(
                $"celebrity_posts:{cid}", -take, -1, Order.Descending));
        var celebResults = await Task.WhenAll(celebPostTasks);

        // 3. Merge, deduplicate, hydrate
        var allIds = timelineIds
            .Concat(celebResults.SelectMany(r => r))
            .Select(r => Guid.Parse((string)r!))
            .Distinct();

        var hydratedPosts = await posts.GetByIdsAsync(allIds, ct);

        // 4. Rank and paginate
        return hydratedPosts
            .OrderByDescending(p => RankScore(p, userId))
            .Take(PageSize)
            .ToList();
    }

    private static double RankScore(Post post, Guid viewerId)
    {
        var ageSecs = (DateTimeOffset.UtcNow - post.CreatedAt).TotalSeconds;
        var recency = Math.Exp(-ageSecs / 21_600); // half-life 6 hours
        return recency * 0.6 + post.EngagementVelocity * 0.4;
    }
}
```

## Common Follow-up Questions

- How would you implement "hide post" or "mute user" without removing entries from the shared feed sorted set?
- A viral post gets 10M likes in 10 minutes. How do you update `like_count` without a thundering herd on the post row?
- How do you ensure a post appears in a follower's feed even if that follower was offline during fan-out?
- What changes if you need to support private accounts with a follow request/accept flow?
- How would you add a "Top Posts" tab (not chronological, but highest engagement in the last 24 h)?

## Common Mistakes / Pitfalls

- **Pure fan-out on write for all users**: 50M-follower celebrity post → 50M Redis writes; the fan-out workers fall behind and feeds become stale.
- **Pure fan-out on read for all users**: aggregating N followees' timelines per request at scale causes N × 200 ms database reads per feed load.
- **Storing full post content in the feed sorted set**: store only post IDs; hydrate lazily. Otherwise a post edit invalidates millions of feed entries.
- **Single sorted set for all users on one Redis node**: shard by `userId % N`; don't put all feeds on a single instance.
- **Applying ranking in the database with ORDER BY on computed columns**: run ranking in-process on a small candidate set, not in SQL.
- **Forgetting TTL on feed sorted sets**: feeds grow unboundedly; always trim to the latest N entries.

## References

- [Instagram Engineering: Lessons Learned Scaling](https://instagram-engineering.com/sharding-ids-at-instagram-1cf5a71e5a5c) (verify URL)
- [Twitter's Approach to Fan-out](https://www.infoq.com/presentations/Twitter-Timeline-Scalability/) (verify URL)
- [System Design Interview Vol 1, Ch 11 — Alex Xu](https://www.bytebytego.com)
- [Redis Sorted Sets](https://redis.io/docs/data-types/sorted-sets/)
- [See: redis-fundamentals.md](./redis-fundamentals.md)
- [See: event-driven-architecture.md](./event-driven-architecture.md)
