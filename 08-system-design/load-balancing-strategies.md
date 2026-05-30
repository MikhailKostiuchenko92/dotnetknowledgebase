# Load Balancing Strategies

**Category:** System Design / Performance
**Difficulty:** Junior
**Tags:** `load-balancing`, `round-robin`, `least-connections`, `consistent-hashing`, `health-checks`

## Question

> What are the main load balancing algorithms? When would you choose one over another? What is the difference between L4 and L7 load balancing?

- How does health-based load balancing work?
- What is consistent hashing and when is it useful for load balancing?

## Short Answer

The main algorithms are **round-robin** (requests distributed sequentially), **least connections** (route to the least busy backend), **IP hash** (same client always reaches same backend), and **weighted** (route proportionally to server capacity). L4 load balancers (TCP/UDP) are fastest but can only route by IP/port; L7 (HTTP) can route by path, headers, and cookies. Least connections is generally better than round-robin for heterogeneous request sizes; consistent hashing is best when session affinity matters (stateful backends, distributed caches). Health-based routing removes unhealthy backends from the pool automatically.

## Detailed Explanation

### L4 vs L7 Load Balancing

| | L4 (Transport Layer) | L7 (Application Layer) |
|--|---------------------|----------------------|
| Operates at | TCP/UDP | HTTP/HTTPS |
| Routing by | Source/dest IP, port | URL path, headers, cookies, body |
| TLS | Pass-through or terminate | Always terminates |
| Performance | Very fast (NIC offload possible) | Slower (must parse HTTP) |
| Features | Basic | Content routing, auth, rate limiting |
| Examples | AWS NLB, HAProxy TCP mode | AWS ALB, Nginx HTTP, YARP, APIM |

L4 is used for database load balancing, message broker clusters, and any TCP protocol. L7 is used for HTTP microservices.

### Round-Robin

Each incoming request goes to the next server in a cyclic list.

```
Servers: [A, B, C]
Requests: 1→A, 2→B, 3→C, 4→A, 5→B ...
```

**Pros**: dead simple, no state.  
**Cons**: doesn't account for request duration — if some requests are cheap and others expensive, one server may be overloaded while others are idle.

**Use when**: all requests are roughly equal in cost (homogeneous API calls).

### Weighted Round-Robin

Assign weights proportional to server capacity.

```
Servers: A(weight=3), B(weight=1)
Requests: 1→A, 2→A, 3→A, 4→B, 5→A ...
```

**Use when**: backends have different hardware capacities or a canary deployment (5% traffic to v2).

### Least Connections

Route to the server with the fewest active connections.

```
Servers: A(5 active), B(2 active), C(8 active)
Next request → B
```

**Pros**: naturally adapts to long-running requests; no starvation for slow backends.  
**Cons**: requires the load balancer to maintain a connection count (state).

**Use when**: requests have variable durations (mix of fast and slow endpoints), gRPC streaming connections, WebSockets.

### IP Hash (Sticky Sessions)

Client's source IP is hashed to consistently route to the same backend.

```
hash("203.0.113.5") % 3 → always Server B
```

**Pros**: sessions remain on one backend (useful for in-memory session state).  
**Cons**: uneven distribution if few large-IP clients; when a server is removed, ~1/N of clients get a new server (cache miss).

**Use when**: backends are stateful and can't share state (e.g., WebSocket connections on specific server, legacy in-process session).

### Consistent Hashing

Keys are hashed to a ring; each server owns a range of the ring. Adding/removing a server only remaps ~1/N keys, not all of them.

```
Ring: [0 ─────────────────── 360°]
       ^Server A    ^Server B    ^Server C
Key K → hash(K) = 280° → Server C
```

**Use when**: distributing work across cache nodes (same key → same cache server for high hit rate), or when routing sessions with minimal disruption on scale-out.

See [database-sharding.md](./database-sharding.md) for the consistent hashing ring internals.

### Health-Based Routing

Load balancers periodically probe backends:
- **Active check**: HTTP `GET /health/ready` every 10 s.
- **Passive check**: count recent 5xx responses; remove backend if error rate > threshold.

```
Pool: [A ✅, B ❌ (3 consecutive failures), C ✅]
Routing: round-robin between A and C only
B re-checked every 30s; re-added on 2 consecutive successes
```

### Random with Two Choices (Power of Two)

Each request picks **two** random backends, routes to the one with fewer connections. This gives near-optimal distribution with O(1) state:

```
Randomly pick B (5 connections) and C (2 connections) → route to C
```

Used by Netflix Ribbon and gRPC's built-in load balancer.

## Code Example

```csharp
// YARP-based load balancer in .NET — configuring different policies
using Yarp.ReverseProxy.LoadBalancing;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

// Custom least-connections policy (YARP has built-in: Random, RoundRobin, LeastRequests, PowerOfTwoChoices)
builder.Services.AddSingleton<ILoadBalancingPolicy, LeastConnectionsPolicy>();

var app = builder.Build();
app.MapReverseProxy();
app.Run();

// appsettings.json:
// "ReverseProxy": {
//   "Clusters": {
//     "orders-cluster": {
//       "LoadBalancingPolicy": "LeastRequests",   // built-in YARP policy
//       "HealthCheck": {
//         "Active": { "Enabled": true, "Interval": "00:00:10", "Path": "/health/ready" }
//       },
//       "Destinations": {
//         "a": { "Address": "http://orders-a" },
//         "b": { "Address": "http://orders-b" },
//         "c": { "Address": "http://orders-c" }
//       }
//     }
//   }
// }

// HttpClient with weighted round-robin (for service-to-service calls)
builder.Services.AddHttpClient("inventory")
    .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
    {
        ConnectTimeout              = TimeSpan.FromSeconds(2),
        PooledConnectionIdleTimeout = TimeSpan.FromMinutes(2),
        EnableMultipleHttp2Connections = true,  // better for gRPC load balancing
    });
```

## Common Follow-up Questions

- What happens to active WebSocket connections when a backend is removed from the pool for health failure?
- How does gRPC client-side load balancing work, and why does it differ from HTTP/1.1 load balancing?
- What is a "slow start" (warm-up) mode in load balancing and why is it useful after a deployment?
- How do you load balance across multiple geographic regions?
- When does consistent hashing outperform least-connections, and vice versa?

## Common Mistakes / Pitfalls

- **No health checks**: without active health checks, a crashed backend continues receiving traffic, causing a flood of errors until the operator notices.
- **Using IP hash with NAT/CDN**: clients behind a corporate NAT all share one IP → all map to the same backend, defeating load balancing.
- **Sticky sessions for stateless services**: stateless services don't need affinity; adding it reduces fault tolerance (if the pinned backend crashes, that session is lost anyway).
- **Not accounting for long-running connections with round-robin**: a WebSocket connection stays open; round-robin distributes the connection at connect time, not per message — use least-connections.
- **Load balancer as SPOF**: the load balancer itself needs to be highly available (active/passive or active/active pair with VIP failover).

## References

- [YARP Load Balancing — Microsoft docs](https://microsoft.github.io/reverse-proxy/articles/load-balancing.html)
- [The Power of Two Random Choices — Michael Mitzenmacher](https://www.eecs.harvard.edu/~michaelm/postscripts/tpds2001.pdf) (verify URL)
- [Kubernetes Service Load Balancing](https://kubernetes.io/docs/concepts/services-networking/service/#proxy-mode-ipvs)
- [See: design-distributed-cache.md](./design-distributed-cache.md)
- [See: database-sharding.md](./database-sharding.md)
