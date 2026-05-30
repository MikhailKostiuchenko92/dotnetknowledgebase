# DDoS Mitigation

**Category:** System Design / Security
**Difficulty:** Senior
**Tags:** `ddos`, `layer3`, `layer4`, `layer7`, `waf`, `rate-limiting`, `anycast`, `azure-ddos-protection`

## Question

> How do you protect a distributed .NET system against DDoS attacks? What is the difference between Layer 3/4 and Layer 7 attacks? What mitigation strategies apply at each layer?

- How does Anycast absorb volumetric attacks?
- What is the role of a WAF vs a rate limiter in DDoS defence?

## Short Answer

DDoS (Distributed Denial of Service) attacks overwhelm a system with traffic to make it unavailable. Layer 3/4 attacks (SYN floods, UDP amplification) target network and transport capacity — mitigated by upstream scrubbing centres, Anycast traffic distribution, and cloud DDoS protection services (Azure DDoS Protection, AWS Shield). Layer 7 (application) attacks mimic legitimate traffic but at volume — mitigated by WAF rules, rate limiting, CAPTCHA challenges, bot fingerprinting, and connection concurrency limits. Defence is layered: upstream absorbs volumetric, WAF filters application-layer, and the application applies connection/request rate limits as the last line.

## Detailed Explanation

### Attack Taxonomy

| Layer | Protocol | Attack type | Example |
|-------|----------|-------------|---------|
| **L3 (Network)** | IP | IP spoofing, ICMP flood | Ping-of-death, smurf attack |
| **L4 (Transport)** | TCP/UDP | SYN flood, UDP amplification, reflection | Sending SYN without completing handshake, DNS amplification |
| **L7 (Application)** | HTTP/HTTPS | HTTP flood, Slowloris, credential stuffing | Sending 10M valid GET requests, holding open slow connections |

**Volumetric attacks** (L3/L4): goal is to saturate network bandwidth. Even a 1 Gbps link can be overwhelmed by a botnet sending 1 Tbps. Only upstream absorption (cloud scrubbing, Anycast) can handle this.

**Application attacks** (L7): attack uses valid HTTP traffic — the attack traffic is indistinguishable from legitimate traffic at the network level. Requires intelligent filtering: rate limiting, behavioural analysis, fingerprinting.

### Layer 3/4 Defences

#### Anycast Traffic Distribution

Anycast assigns the same IP to multiple geographically distributed PoPs (Points of Presence). Traffic from a DDoS botnet is absorbed across all PoPs; no single location is overwhelmed:

```
Botnet (10M IPs) → DNS resolves to anycast IP
                  ├─ PoP Frankfurt absorbs EU traffic
                  ├─ PoP Ashburn absorbs US traffic
                  ├─ PoP Tokyo absorbs Asia traffic
                  └─ Total attack traffic shared → manageable per-PoP
```

CDNs (Cloudflare, Akamai, Azure Front Door) provide Anycast automatically.

#### Azure DDoS Protection

Azure provides two tiers:
- **Basic**: automatically enabled for all Azure resources, protects against common L3/L4 attacks.
- **Standard** (now Network): adds ML-based traffic profiling, per-resource attack mitigation policies, rapid response team, DDoS cost protection.

```bicep
// Enable DDoS Protection Standard on a VNet
resource ddosPlan 'Microsoft.Network/ddosProtectionPlans@2023-09-01' = {
  name: 'orders-ddos-plan'
  location: resourceGroup().location
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'orders-vnet'
  properties: {
    enableDdosProtection: true
    ddosProtectionPlan: { id: ddosPlan.id }
  }
}
```

#### SYN Flood Mitigation (OS-level)

For self-managed servers, SYN cookies prevent state exhaustion:

```bash
# Linux: enable SYN cookies (kernel-level protection)
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_max_syn_backlog=4096
sysctl -w net.ipv4.tcp_synack_retries=2  # reduce retransmit timeout
```

### Layer 7 Defences

#### WAF (Web Application Firewall)

A WAF inspects HTTP requests and blocks malicious patterns. Operates at Layer 7 — understands HTTP headers, URLs, bodies:

```
Request → WAF rules evaluation → Allow/Block/Challenge
          ├─ Block known malicious IPs (reputation lists)
          ├─ Block requests matching OWASP ModSecurity rules
          ├─ Block requests with malformed headers
          ├─ Rate-limit by IP, user-agent, or fingerprint
          └─ Challenge suspicious IPs with CAPTCHA (JS challenge)
```

Azure Application Gateway WAF, Cloudflare WAF, and AWS WAF all sit in front of the application and filter before traffic reaches your code.

#### ASP.NET Core Rate Limiting (Last-Resort Application Layer)

The application should apply rate limiting as a final defence layer (not primary — real DDoS should be absorbed upstream):

```csharp
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;

builder.Services.AddRateLimiter(options =>
{
    // Per-IP sliding window: 100 req/min per IP
    options.AddPolicy("per-ip", context =>
    {
        var ip = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        return RateLimitPartition.GetSlidingWindowLimiter(ip, _ => new SlidingWindowRateLimiterOptions
        {
            PermitLimit         = 100,
            Window              = TimeSpan.FromMinutes(1),
            SegmentsPerWindow   = 6,           // 10-second segments
            QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
            QueueLimit           = 0,           // no queue — reject immediately
        });
    });

    // Stricter limit for auth endpoints (prevent credential stuffing)
    options.AddPolicy("auth-strict", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window      = TimeSpan.FromMinutes(1),
                QueueLimit  = 0,
            }));

    options.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        ctx.HttpContext.Response.Headers.RetryAfter = "60";
        await ctx.HttpContext.Response.WriteAsync("Too many requests", ct);
    };
});

app.UseRateLimiter();
app.MapPost("/auth/login", LoginHandler).RequireRateLimiting("auth-strict");
app.MapGet("/api/{**path}", ApiHandler).RequireRateLimiting("per-ip");
```

#### Slowloris Attack Defence

Slowloris holds HTTP connections open by sending headers slowly (one byte every few seconds), exhausting the server's connection pool:

```csharp
// Kestrel configuration: close idle/slow connections
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.KeepAliveTimeout       = TimeSpan.FromSeconds(30);
    options.Limits.RequestHeadersTimeout  = TimeSpan.FromSeconds(10); // Slowloris defence
    options.Limits.MaxConcurrentConnections = 5000;
    options.Limits.MaxRequestBodySize     = 10 * 1024 * 1024; // 10 MB — reject large payloads
});
```

#### Bot Fingerprinting and Behavioural Analysis

Sophisticated L7 attacks use botnets with many IPs, so IP-based rate limiting fails. Fingerprinting uses:
- TLS fingerprint (JA3 hash) — bots often share identical TLS client hello signatures
- HTTP/2 SETTINGS frame fingerprint
- User-agent consistency vs behaviour
- Canvas fingerprint (browser-based)

Cloudflare's Bot Management and Azure WAF Bot Protection rules automate this.

### Defence-in-Depth Architecture

```
Internet
  │
  ▼
[CDN / Anycast PoPs] ← absorbs volumetric L3/L4
  │
  ▼
[DDoS Protection Standard] ← ML-based L3/L4 mitigation
  │
  ▼
[WAF / Application Gateway] ← L7 filtering, OWASP rules, bot management
  │
  ▼
[API Gateway / Rate Limiter] ← per-IP / per-user limits
  │
  ▼
[ASP.NET Core app] ← Kestrel limits, connection timeouts
  │
  ▼
[Database] ← connection pool limits, query timeouts
```

> **Warning:** Do not rely on ASP.NET Core rate limiting as your primary DDoS defence. By the time traffic reaches your application code, network bandwidth, load balancer, and database connections may already be exhausted. Upstream absorption (CDN + DDoS Protection) must be the first line.

## Code Example

```csharp
// Full middleware configuration for DDoS-resilient ASP.NET Core service

builder.WebHost.ConfigureKestrel(kestrel =>
{
    kestrel.Limits.MaxConcurrentConnections        = 10_000;
    kestrel.Limits.MaxConcurrentUpgradedConnections = 1_000;
    kestrel.Limits.RequestHeadersTimeout           = TimeSpan.FromSeconds(10);
    kestrel.Limits.KeepAliveTimeout                = TimeSpan.FromSeconds(30);
    kestrel.Limits.MaxRequestBodySize              = 5 * 1024 * 1024; // 5 MB
});

builder.Services.AddRateLimiter(o =>
{
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new() { PermitLimit = 200, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));

    o.RejectionStatusCode = 429;
});

var app = builder.Build();
app.UseForwardedHeaders();  // trust X-Forwarded-For from CDN/proxy for real client IP
app.UseRateLimiter();
```

## Common Follow-up Questions

- How does a reflection/amplification attack work and why is UDP particularly vulnerable?
- What is IP reputation scoring and how does Cloudflare/Azure WAF use it?
- How do you distinguish a DDoS from a legitimate traffic spike (e.g., viral social media post)?
- What is a CAPTCHA / JS challenge and what attack types do they defeat?
- How do you configure `X-Forwarded-For` header trust in ASP.NET Core behind a proxy?

## Common Mistakes / Pitfalls

- **Rate limiting by IP without proxy support**: behind a CDN/load balancer, all requests appear to come from the proxy IP; use `ForwardedHeaders` middleware to get the real client IP, then rate-limit.
- **Placing WAF behind the load balancer instead of in front**: the WAF must see traffic before it reaches your infrastructure; a WAF behind the load balancer can't stop volumetric attacks from consuming bandwidth.
- **No connection limits on Kestrel**: without `MaxConcurrentConnections`, a Slowloris attack can exhaust all available sockets.
- **Ignoring UDP services**: DNS, NTP, and gaming services using UDP are prime amplification attack targets; apply strict rate limiting at the firewall for these protocols.
- **Not testing DDoS defences**: run load tests and chaos experiments to validate that rate limits and WAF rules actually work before an attack happens.

## References

- [Azure DDoS Protection — Microsoft Docs](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-protection-overview)
- [ASP.NET Core rate limiting — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit)
- [Kestrel connection limits — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/options)
- [OWASP DDoS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html)
- [See: rate-limiting-algorithms.md](./rate-limiting-algorithms.md)
- [See: zero-trust-architecture.md](./zero-trust-architecture.md)
