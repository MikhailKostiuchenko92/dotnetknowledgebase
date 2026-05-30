# Zero Trust Architecture

**Category:** System Design / Security
**Difficulty:** Middle
**Tags:** `zero-trust`, `mtls`, `workload-identity`, `network-policy`, `service-mesh`, `least-privilege`

## Question

> What is Zero Trust Architecture? How does it differ from perimeter-based (castle-and-moat) security? How do you implement Zero Trust principles in a microservices system running in Kubernetes?

- What does "never trust, always verify" mean in practice for service-to-service calls?
- How do mutual TLS (mTLS) and workload identity relate to Zero Trust?

## Short Answer

Zero Trust Architecture (ZTA) abandons the assumption that anything inside the network perimeter is safe. Instead, every request — regardless of source — must be authenticated, authorized, and encrypted. In microservices, this means services authenticate to each other using workload identities (e.g., SPIFFE/SPIRE, Kubernetes service accounts), communicate over mTLS (mutual TLS where both sides verify certificates), and follow least-privilege policies so a compromised service can only access the specific resources it needs. A service mesh like Istio automates most of this without requiring code changes.

## Detailed Explanation

### Traditional Perimeter Security (Castle-and-Moat)

```
[Internet]──[Firewall]──[Internal Network]
                        └── All traffic trusted after firewall
                        └── Service A can call Service B without auth
                        └── DB allows connections from any internal IP
```

**Failure modes**:
- Attacker breaches one internal service → lateral movement to all services.
- Insider threat — internal user/service can access anything.
- Stolen VPN credentials → full internal access.

### Zero Trust Principles

1. **Never trust, always verify**: every request requires authentication, even within the same network/namespace.
2. **Least privilege**: each service/user has only the minimum permissions needed.
3. **Assume breach**: design assuming attackers are already inside; limit blast radius.
4. **Explicit verification**: use multiple signals (identity, device health, location) not just network position.
5. **Encrypt everything**: all traffic encrypted in transit, even within the cluster.

### Zero Trust in Microservices: Implementation Layers

#### Layer 1: Workload Identity (SPIFFE/SPIRE)

Every service gets a cryptographic identity — a short-lived X.509 certificate with a SPIFFE ID:

```
spiffe://cluster.local/ns/orders/sa/orders-service
         ├── trust domain
                       ├── namespace
                                  ├── service account
```

Certificates are automatically issued and rotated by SPIRE or the service mesh. No shared secrets.

#### Layer 2: Mutual TLS (mTLS)

Both client and server present certificates. The server verifies the client's identity; the client verifies the server's identity. This prevents spoofing in both directions:

```
Service A                        Service B
    │── ClientHello ──────────────►│
    │◄─ ServerHello + Certificate──│
    │── Client Certificate ────────►│  ← Server verifies Service A's identity
    │── Verify Server Cert ─────────│  ← Client verifies Service B's identity
    │── Encrypted channel established │
```

In Istio, mTLS is applied automatically via sidecar proxies (Envoy) — **zero code changes required**:

```yaml
# Istio PeerAuthentication: require mTLS for all services in namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # reject plaintext connections
```

#### Layer 3: Service-Level Authorization (AuthorizationPolicy)

Even with verified identity, each service only talks to the services it needs:

```yaml
# Orders service: only allow calls from API gateway and recommendations service
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: orders-authz
  namespace: production
spec:
  selector:
    matchLabels:
      app: orders-service
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/production/sa/api-gateway"
              - "cluster.local/ns/production/sa/recommendations-service"
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/orders/*"]
```

If `payments-service` tries to call `orders-service` directly (which it should never do), the connection is rejected at the sidecar — not by application code.

#### Layer 4: Kubernetes Network Policies

At the network layer, restrict which pods can communicate:

```yaml
# Only allow pods in the 'production' namespace to talk to the orders service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: orders-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: orders-service
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: production
          podSelector:
            matchLabels:
              role: api-gateway
  policyTypes:
    - Ingress
```

Network policies are enforced by the CNI plugin (Calico, Cilium, etc.) — packets are dropped at the kernel level, before they reach the application.

#### Layer 5: Zero Trust for External Traffic (API Gateway + JWT)

External requests (browser/mobile/third-party) use the standard OAuth 2.0 / JWT flow:

```
[Client]──JWT──►[API Gateway]──validates JWT──►[Service (mTLS, no JWT needed)]
```

Internal service-to-service calls don't need JWTs if mTLS workload identity is sufficient. If user context is needed downstream (e.g., row-level access control), pass a signed **on-behalf-of token** or include the `sub` claim in a stripped, forwarded header.

### .NET: Enabling mTLS with `HttpClient`

When using a service mesh, mTLS is transparent — the sidecar handles it. For self-managed mTLS:

```csharp
// Load client certificate from Key Vault or Kubernetes secret
var certBytes = await File.ReadAllBytesAsync("/mnt/certs/client.pfx");
var clientCert = new X509Certificate2(certBytes);

var handler = new HttpClientHandler();
handler.ClientCertificates.Add(clientCert);
handler.ServerCertificateCustomValidationCallback = (_, cert, _, _) =>
    cert?.Issuer.Contains("orders-ca.internal") == true;  // validate against known CA

var httpClient = new HttpClient(handler)
{
    BaseAddress = new Uri("https://inventory-service.internal"),
};
```

In Kubernetes with Istio, this code is unnecessary — the sidecar intercepts and upgrades connections automatically.

### Zero Trust and Least Privilege at the Database Layer

Zero Trust extends to databases:

- Services connect to the database using unique service accounts (not a shared `app_user`).
- Each service has only the SQL permissions it needs (`SELECT` on `orders` for read-only services; `INSERT/UPDATE` for write services).
- Database credentials rotate automatically (HashiCorp Vault dynamic secrets).
- No service can directly access another service's database schema.

```sql
-- Least-privilege DB roles per service
CREATE ROLE orders_read_role;
GRANT SELECT ON orders, order_lines TO orders_read_role;

CREATE ROLE orders_write_role;
GRANT SELECT, INSERT, UPDATE ON orders, order_lines TO orders_write_role;

CREATE USER orders_svc_v1 WITH ROLE orders_write_role;
-- This user can't DELETE, can't touch customers table, can't read payments
```

> **Warning:** Zero Trust is not binary — it's a spectrum. Start with the highest-risk paths: external traffic authentication (API gateway), service-to-service authentication (mTLS), and database access controls. You don't need a fully automated SPIFFE/SPIRE setup on day 1; enforce mTLS in Istio with default service account isolation first.

## Code Example

```csharp
// ASP.NET Core: enforce that only requests with a valid client certificate are accepted
// (useful when service mesh sidecar isn't available)
builder.Services.AddAuthentication(CertificateAuthenticationDefaults.AuthenticationScheme)
    .AddCertificate(options =>
    {
        options.AllowedCertificateTypes = CertificateTypes.Chained;
        options.ValidateCertificateUse  = true;
        options.RevocationMode          = X509RevocationMode.Online;
        options.Events = new CertificateAuthenticationEvents
        {
            OnCertificateValidated = ctx =>
            {
                // Validate the SPIFFE ID from the SAN extension
                var spiffeId = ctx.ClientCertificate.GetSubjectAlternativeNames()
                    .FirstOrDefault(s => s.StartsWith("spiffe://"));
                if (spiffeId is null || !_allowedSpiffeIds.Contains(spiffeId))
                {
                    ctx.Fail("Certificate identity not in allowlist");
                    return Task.CompletedTask;
                }
                ctx.Success();
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("InternalServiceOnly", policy =>
        policy.RequireAuthenticatedUser()
              .AddAuthenticationSchemes(CertificateAuthenticationDefaults.AuthenticationScheme));
});
```

## Common Follow-up Questions

- How does SPIFFE (Secure Production Identity Framework For Everyone) work?
- What is the difference between mTLS at the sidecar/service mesh layer vs application layer?
- How do you implement Zero Trust in a legacy system that doesn't support mTLS?
- What is the relationship between Zero Trust and BeyondCorp (Google's model)?
- How do you audit service-to-service calls in a Zero Trust system?

## Common Mistakes / Pitfalls

- **Zero Trust as a VPN replacement only**: blocking external access is not Zero Trust if internal traffic is still fully trusted after the perimeter.
- **mTLS in permissive mode**: Istio's `PERMISSIVE` mode allows both mTLS and plaintext — useful during migration but must be switched to `STRICT` to actually enforce identity.
- **Assuming a service account = service identity**: Kubernetes service accounts are cluster-scoped — any pod with that service account has that identity. Use fine-grained RBAC and SPIFFE workload IDs for per-workload identity.
- **Not auditing service-to-service calls**: Zero Trust requires continuous verification *and* audit trails; no-log mTLS traffic defeats the "assume breach" principle.
- **Neglecting the human plane**: Zero Trust for services is useless if developers have broad cluster admin access. Apply least privilege to human identities too.

## References

- [Zero Trust Architecture — NIST SP 800-207](https://csrc.nist.gov/publications/detail/sp/800-207/final)
- [Zero Trust in Azure — Microsoft Docs](https://learn.microsoft.com/en-us/azure/security/fundamentals/zero-trust)
- [Istio PeerAuthentication — mTLS](https://istio.io/latest/docs/reference/config/security/peer_authentication/)
- [SPIFFE/SPIRE — workload identity](https://spiffe.io/)
- [Certificate authentication in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/certauth)
- [See: service-mesh-vs-api-gateway.md](./service-mesh-vs-api-gateway.md)
- [See: secrets-management-at-scale.md](./secrets-management-at-scale.md)
