# Design a File Storage Service

**Category:** System Design / Classic Problems
**Difficulty:** Senior
**Tags:** `file-storage`, `s3`, `chunking`, `deduplication`, `cdn`, `presigned-urls`

## Question

> Design a file storage service like Dropbox or Google Drive. Users can upload, download, share, and sync files. The system must handle files up to 5 GB, serve 100 million users, and store 10 exabytes of data total.

- How do you handle large file uploads reliably?
- How does deduplication work at scale?
- How do you serve files efficiently without proxying through your API servers?

## Short Answer

Files are split into fixed-size **chunks** (4–8 MB each) client-side; each chunk is content-addressed by its SHA-256 hash. Chunks are uploaded to object storage (S3) directly via presigned URLs, bypassing the API servers. The metadata service stores the file's chunk list, size, owner, and permissions in a relational DB. Deduplication works naturally: if a chunk's hash already exists in storage, we skip uploading it. Downloads are served via CDN-cached presigned URLs with short TTLs.

## Detailed Explanation

### Functional Requirements

| Feature | Detail |
|---------|--------|
| Upload | Files up to 5 GB; resumable |
| Download | Fast; CDN-cached for popular files |
| Share | Private links, expiring URLs, public links |
| Sync | Delta sync — only changed chunks transferred |
| Deduplication | Per-user or cross-user (with privacy implications) |

Non-functional: 99.99% durability, <500 ms first-byte for downloads, 100M users, 10 EB total storage.

### Why Chunking?

A single HTTP upload of a 5 GB file is fragile: any network interruption requires restarting from scratch. Chunking gives us:

1. **Resumability**: track which chunks are uploaded; resume from the last successful chunk.
2. **Parallelism**: upload multiple chunks concurrently (e.g., 4 threads × 8 MB = 32 MB/s with good bandwidth).
3. **Deduplication**: each chunk is independently reusable across files and users.
4. **Delta sync**: on re-upload of a modified file, only changed chunks need to be transferred.

### Upload Flow

```
Client
 1. Split file into 8 MB chunks, compute SHA-256 per chunk
 2. POST /files/initiate { filename, size, chunkHashes[] }
    → Server checks which hashes already exist in storage
    → Returns: file_id, uploadUrls[] (presigned S3 PUT URLs for NEW chunks only)
 3. PUT <presigned S3 URL> — upload each new chunk directly to S3 (parallel, no API server)
 4. POST /files/complete { file_id, chunkHashes[] }
    → Server: verify all chunks present, write metadata, return file_id
```

This flow means API servers **never proxy binary data** — they only handle metadata (JSON). Bandwidth cost and latency for large uploads hits S3 directly.

### Data Model

**files table** (PostgreSQL):
```sql
CREATE TABLE files (
    id          UUID PRIMARY KEY,
    owner_id    UUID NOT NULL,
    name        TEXT NOT NULL,
    size_bytes  BIGINT NOT NULL,
    mime_type   TEXT,
    status      TEXT DEFAULT 'pending',  -- pending | active | deleted
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE file_chunks (
    file_id     UUID REFERENCES files(id),
    chunk_index INT,
    chunk_hash  CHAR(64) NOT NULL,  -- SHA-256 hex
    PRIMARY KEY (file_id, chunk_index)
);

CREATE TABLE chunk_storage (
    chunk_hash  CHAR(64) PRIMARY KEY,
    s3_key      TEXT NOT NULL,      -- actual S3 object key
    size_bytes  INT NOT NULL,
    ref_count   INT DEFAULT 1       -- for cross-user dedup GC
);
```

### Deduplication

Two flavours:

| Type | Description | Privacy |
|------|-------------|---------|
| **Per-user** | Dedup only within same user's files | Safe |
| **Cross-user** | Same chunk hash across all users → one copy | Requires careful privacy review |

For cross-user dedup: if two users upload the same 8 MB chunk, `chunk_storage` has one row, both `file_chunks` reference the same `chunk_hash`. This saves massive storage at the cost of needing **reference counting** for safe deletion (only delete from S3 when `ref_count = 0`).

> **Warning:** Cross-user deduplication has been used as a side-channel attack: an attacker can probe whether a specific file exists in the system by checking if a specific chunk hash is "already uploaded" during the initiation call. If privacy is paramount (medical records, legal), limit dedup to per-user.

### Download Flow

```
Client GET /files/{id}/download
 → API server checks permissions
 → Generates presigned S3 GET URL (TTL = 15 min) for each chunk (or one URL for small files)
 → Returns chunk URLs + chunk_index order
 → Client fetches chunks in parallel from S3 (via CDN)
 → Client reassembles in order
```

CDN caches public/shared files. Private files use presigned URLs with no CDN caching (Cache-Control: private, no-store).

### Sync Client (Delta Sync)

The desktop/mobile client tracks which chunks were modified:

1. On file change, re-hash all chunks.
2. Compare chunk hashes against last-synced manifest.
3. Only upload new/changed chunks.
4. Update metadata with new chunk list.

This means editing a line in a 1 GB document uploads only the 8 MB chunk containing that line — not the full file.

### Sharing & Access Control

| Share type | Implementation |
|------------|----------------|
| Private link | UUID token stored in `share_links` table; bearer auth |
| Expiring link | `expires_at` column; presigned URL TTL matches |
| Public link | CDN-cached presigned URL with long TTL |
| Folder share | ACL table: `file_permissions (file_id, grantee_id, permission)` |

### Storage Tiers & Lifecycle

Not all 10 EB needs to be on hot SSD storage:

| Tier | Storage class | Cost | Access |
|------|--------------|------|--------|
| Hot | S3 Standard | $$$  | Immediate |
| Warm | S3-IA / Infrequent | $$ | 50–100 ms |
| Cold | S3 Glacier | $   | Minutes |

Files not accessed in 90 days auto-transition to Warm; 1 year → Glacier. Lifecycle policies set in S3 bucket config.

### Capacity

| Metric | Estimate |
|--------|----------|
| Users | 100M |
| Avg storage per user | 10 GB |
| Total | 1 EB (10 EB at full growth) |
| Daily uploads | 1B files × avg 1 MB = 1 PB/day |
| S3 requests/s (uploads) | ~11,500 PUT/s |
| Metadata DB writes | ~50K/s (PostgreSQL + read replicas) |

### Anti-Virus & Content Scanning

Upload completes → S3 event → Lambda → ClamAV scan. If infected, mark file status=`quarantined`, notify owner, delete chunk only if no other references. NSFW detection for image chunks uses a separate async ML pipeline.

## Code Example

```csharp
// Metadata API — initiate upload, return presigned URLs for new chunks
using Amazon.S3;
using Amazon.S3.Model;

namespace FileStorage;

public sealed class FileUploadService(
    FileStorageDbContext db,
    IAmazonS3 s3,
    IOptions<S3Options> s3Opts)
{
    private const int PresignedUrlTtlMinutes = 30;

    public async Task<InitiateUploadResponse> InitiateAsync(
        InitiateUploadRequest request, Guid ownerId, CancellationToken ct)
    {
        // Find which chunks are NEW (not already in chunk_storage)
        var existingHashes = await db.ChunkStorage
            .Where(c => request.ChunkHashes.Contains(c.ChunkHash))
            .Select(c => c.ChunkHash)
            .ToHashSetAsync(ct);

        var newHashes = request.ChunkHashes
            .Except(existingHashes)
            .ToList();

        // Generate presigned PUT URLs only for new chunks
        var uploadUrls = newHashes.ToDictionary(
            hash => hash,
            hash =>
            {
                var presigned = new GetPreSignedUrlRequest
                {
                    BucketName = s3Opts.Value.BucketName,
                    Key        = $"chunks/{hash}",
                    Verb       = HttpVerb.PUT,
                    Expires    = DateTime.UtcNow.AddMinutes(PresignedUrlTtlMinutes),
                    ContentType = "application/octet-stream",
                };
                return s3.GetPreSignedURL(presigned);
            });

        // Create file record in PENDING state
        var fileId = Guid.NewGuid();
        db.Files.Add(new FileRecord
        {
            Id         = fileId,
            OwnerId    = ownerId,
            Name       = request.FileName,
            SizeBytes  = request.TotalSizeBytes,
            Status     = "pending",
            CreatedAt  = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync(ct);

        return new InitiateUploadResponse(fileId, uploadUrls, existingHashes.ToList());
    }

    public async Task CompleteAsync(
        Guid fileId, IList<string> orderedChunkHashes, CancellationToken ct)
    {
        await using var txn = await db.Database.BeginTransactionAsync(ct);

        // Write chunk list
        var chunks = orderedChunkHashes.Select((hash, idx) => new FileChunk
        {
            FileId     = fileId,
            ChunkIndex = idx,
            ChunkHash  = hash,
        });
        db.FileChunks.AddRange(chunks);

        // Increment ref_count for existing chunks; insert new chunk_storage rows
        foreach (var hash in orderedChunkHashes)
        {
            await db.ChunkStorage.Upsert(new ChunkStorageRow
            {
                ChunkHash = hash,
                S3Key     = $"chunks/{hash}",
            }).On(c => c.ChunkHash)
              .WhenMatched(c => new ChunkStorageRow { RefCount = c.RefCount + 1 })
              .RunAsync(ct);
        }

        // Mark file active
        await db.Files.Where(f => f.Id == fileId)
            .ExecuteUpdateAsync(s => s.SetProperty(f => f.Status, "active"), ct);

        await db.SaveChangesAsync(ct);
        await txn.CommitAsync(ct);
    }
}
```

## Common Follow-up Questions

- How do you handle the case where a client uploads all chunks but crashes before calling `/complete`? (Hint: scheduled cleanup of orphaned chunks)
- A user deletes a file — when and how do you safely delete the underlying S3 objects given reference counting?
- How would you implement versioning (keep last N versions of a file)?
- How do you enforce per-user storage quotas atomically without race conditions?
- A user has 1 million small files (1 KB each). How does chunking change, and does dedup still make sense?

## Common Mistakes / Pitfalls

- **Proxying file data through your API servers**: a single 1 GB upload through the API server consumes 1 GB of server RAM and saturates its NIC; always use presigned URLs to direct-upload to object storage.
- **Not tracking upload status per chunk**: without per-chunk state, any failure requires re-uploading the entire file.
- **Deleting chunks on file delete without checking ref_count**: cross-user dedup means a chunk may be referenced by other users' files; always decrement ref_count and only delete when it reaches 0.
- **Presigned URLs with very long TTLs**: a leaked presigned URL gives unauthenticated access for its entire lifetime; keep TTL ≤30 min for uploads, ≤5 min for sensitive downloads.
- **Not handling S3 eventual consistency on read-after-write**: use `ChecksumAlgorithm` and verify chunk integrity on download; S3 strong read-after-write consistency (since 2020) helps but verify.
- **Single S3 bucket for all users**: use per-region buckets and S3 Transfer Acceleration for global users; a single us-east-1 bucket serving Tokyo users adds 200+ ms.

## References

- [Amazon S3 Multipart Upload](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html)
- [Amazon S3 Presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html)
- [System Design Interview Vol 2, Ch 15 (Google Drive) — Alex Xu](https://www.bytebytego.com)
- [Dropbox Architecture Blog](https://dropbox.tech/infrastructure) (verify URL)
- [See: cdn-fundamentals.md](./cdn-fundamentals.md)
- [See: database-replication.md](./database-replication.md)
