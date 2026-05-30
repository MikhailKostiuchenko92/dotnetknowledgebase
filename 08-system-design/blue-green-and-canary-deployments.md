# Blue-Green and Canary Deployments

**Category:** System Design / Cloud-Native
**Difficulty:** Middle
**Tags:** `blue-green`, `canary`, `zero-downtime`, `feature-flags`, `traffic-splitting`, `rollback`

## Question

> What are blue-green and canary deployment strategies? How do they differ from a standard rolling update? When would you choose each one? How do you implement traffic splitting in Kubernetes?

- How do you roll back instantly from a bad deployment?
- How do feature flags relate to canary deployments?

## Short Answer

Blue-green maintains two identical environments (blue = live, green = new version); after validating green, traffic is switched atomically from blue to green, enabling instant rollback by switching back. Canary gradually routes a percentage of traffic to the new version — starting with 1–5% and increasing if metrics remain healthy. Rolling updates (Kubernetes default) replace pods incrementally with no traffic control. Blue-green is best for high-risk releases requiring instant rollback; canary is best for validating behaviour under real production traffic before full rollout; feature flags decouple deployment from feature release, enabling code to be deployed without activating the feature.

## Detailed Explanation

### Rolling Update (Kubernetes Default)

```
Before: [v1][v1][v1][v1]
Step 1: [v2][v1][v1][v1]  ← new pod passes readiness → added to LB
Step 2: [v2][v2][v1][v1]  ← old pod removed
Step 3: [v2][v2][v2][v1]
After:  [v2][v2][v2][v2]
```

**Drawbacks**: both versions serve traffic simultaneously during rollout (5–10 minutes for a large deployment). Not suitable if v1 and v2 are incompatible (different DB schema, different API contract).

### Blue-Green Deployment

Two identical environments. Traffic switch is atomic (DNS or load balancer):

```
Blue (current):  [v1][v1][v1] ← receives 100% traffic
Green (new):     [v2][v2][v2] ← warm, tested, receives 0% traffic

Switch:
  → Update load balancer or service selector to point to green
  → Blue stays idle (instant rollback target)

After switch:
Blue (idle):     [v1][v1][v1] ← instant rollback by switching back
Green (live):    [v2][v2][v2] ← receives 100% traffic
```

**Kubernetes blue-green via Service label selector:**

```yaml
# Blue Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api-blue
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: orders-api
        version: blue
    spec:
      containers:
        - name: orders-api
          image: orders-api:v1.2.0

---
# Green Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api-green
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: orders-api
        version: green
    spec:
      containers:
        - name: orders-api
          image: orders-api:v1.3.0

---
# Service: switch traffic by changing selector
apiVersion: v1
kind: Service
metadata:
  name: orders-api
spec:
  selector:
    app: orders-api
    version: blue    # change to 'green' to switch traffic — atomic
  ports:
    - port: 80
      targetPort: 8080
```

Switch traffic:
```bash
kubectl patch service orders-api -p '{"spec":{"selector":{"version":"green"}}}'
# Instant traffic switch — rollback is the same command with 'blue'
```

### Canary Deployment

Route a small percentage of traffic to the new version, observe metrics, then gradually increase:

```
5% → new version (canary)    monitor error rate, latency, business metrics
95% → old version (stable)

If metrics healthy:
25% → canary
50% → canary
100% → canary (fully rolled out)
```

**Kubernetes canary via replica ratio** (simple but coarse):

```yaml
# Stable: 9 replicas (90% of traffic under round-robin)
# Canary: 1 replica (10% of traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api-canary
spec:
  replicas: 1   # 1 canary pod out of 10 total = ~10% traffic
  template:
    metadata:
      labels:
        app: orders-api  # same selector as stable Service → shares load balancer
    spec:
      containers:
        - name: orders-api
          image: orders-api:v1.3.0
```

**Limitation**: replica-ratio canary only works for roughly equal request size; precise percentage requires a service mesh or Ingress with traffic weights.

**Nginx Ingress canary** (precise weight-based):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders-api-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"   # 10% traffic to canary
    # Or route by header: nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
spec:
  rules:
    - host: orders.example.com
      http:
        paths:
          - path: /
            backend:
              service:
                name: orders-api-v2
                port:
                  number: 80
```

**Flagger** (progressive delivery operator) automates canary promotion/rollback based on metrics:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: orders-api
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: orders-api
  progressDeadlineSeconds: 300
  service:
    port: 80
  analysis:
    interval: 1m
    threshold: 5          # max 5 failed metric checks before rollback
    maxWeight: 50         # max 50% canary traffic
    stepWeight: 10        # increment by 10% per analysis interval
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99         # rollback if success rate drops below 99%
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500        # rollback if p99 latency exceeds 500ms
        interval: 1m
```

### Feature Flags vs Canary

| | Canary deployment | Feature flag |
|--|------------------|-------------|
| What's controlled | % of users get new *code* | % of users get new *feature* (same binary) |
| Rollback | Redeploy old image | Disable flag — instant, no deploy |
| Targeting | By traffic percentage | By user, segment, region, account |
| Coupling | Code and feature coupled | Deployed separately |

Feature flags complement canary: deploy code to 100% (dark launch), then gradually enable the feature via flag:

```csharp
// Microsoft.FeatureManagement
builder.Services.AddFeatureManagement()
    .AddFeatureFilter<PercentageFilter>()    // enable for X% of requests
    .AddFeatureFilter<TargetingFilter>();    // enable for specific users/groups

// In controller
public async Task<IActionResult> Checkout(CheckoutRequest request)
{
    if (await _featureManager.IsEnabledAsync("NewCheckoutFlow",
            new TargetingContext { UserId = User.GetUserId() }))
    {
        return await NewCheckoutAsync(request);
    }
    return await LegacyCheckoutAsync(request);
}
```

Azure App Configuration provides centralised feature flag management with real-time updates — no redeploy required to toggle a flag.

> **Warning:** Blue-green requires double the infrastructure cost during the transition period (both environments running simultaneously). For cost-sensitive deployments, canary or rolling updates may be preferable, accepting the tradeoff of slower rollback.

## Code Example

```bash
# GitOps workflow: canary via Argo Rollouts (Kubernetes progressive delivery)

# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Rollout definition
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: orders-api
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 20         # 20% to canary
        - pause: {duration: 5m} # wait 5 minutes, check metrics
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 100        # full rollout
      canaryMetadata:
        labels:
          version: canary
      stableMetadata:
        labels:
          version: stable
  selector:
    matchLabels:
      app: orders-api
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
        - name: orders-api
          image: orders-api:v1.3.0  # update this to trigger rollout

# Promote or abort manually:
# kubectl-argo-rollouts promote orders-api
# kubectl-argo-rollouts abort orders-api
```

## Common Follow-up Questions

- How does database schema migration interact with blue-green deployment — how do you deploy a breaking schema change?
- What is a "dark launch" and how does it relate to shadow testing?
- How do you implement instant rollback if a deployed container image has already been updated in a Deployment?
- How does Argo Rollouts differ from Flagger in its approach to progressive delivery?
- What is GitOps and how does it enforce that all deployments are driven by Git changes?

## Common Mistakes / Pitfalls

- **Breaking DB schema change during blue-green**: if v2 removes a column that v1 reads, the instant you switch to green, v1 (if switched back on rollback) will error; use expand/contract migrations (add column, deploy, remove old column in a later release).
- **Not warming up the green environment**: switching traffic to green before it has JIT-compiled and warmed up connection pools causes an initial latency spike; use startup probes and synthetic warmup traffic.
- **Forgetting session affinity during canary**: if a user's session starts on stable but their next request goes to canary (different version), they may see inconsistent behaviour; ensure sticky sessions or stateless design during canary.
- **No automatic rollback criteria**: a manual canary with "someone will check the metrics and decide" often leads to delayed rollbacks when engineers aren't watching; automate rollback on error rate or latency thresholds.
- **Long-lived blue environment**: keeping blue running for "just in case" rollback for weeks means paying double; define a rollback window (e.g., 24 hours) and decommission blue after it passes.

## References

- [Kubernetes rolling updates — kubernetes.io](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)
- [Flagger — progressive delivery for Kubernetes](https://flagger.app/)
- [Argo Rollouts — progressive delivery controller](https://argoproj.github.io/rollouts/)
- [Feature management in ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/azure/azure-app-configuration/use-feature-flags-dotnet-core)
- [See: kubernetes-for-dotnet-devs.md](./kubernetes-for-dotnet-devs.md)
- [See: containers-and-orchestration.md](./containers-and-orchestration.md)
