# Event-Driven Autoscaling

**Category:** System Design / Cloud-Native
**Difficulty:** Middle
**Tags:** `keda`, `autoscaling`, `hpa`, `scale-to-zero`, `kubernetes`, `queue-length`, `dotnet`

## Question

> What is event-driven autoscaling and how does KEDA work in Kubernetes? What are the advantages over CPU/memory-based HPA for .NET workloads? How do you handle cold start latency when scaling from zero?

- What types of scalers does KEDA support for .NET applications?
- What is the trade-off between scale-to-zero and keeping a minimum number of replicas running?

## Short Answer

Event-driven autoscaling scales workloads based on the actual work backlog — queue length, Kafka consumer lag, cron schedule — rather than CPU or memory utilisation. KEDA (Kubernetes Event-Driven Autoscaler) extends Kubernetes with scalers for 60+ event sources and enables scale-to-zero for idle workloads. For .NET message consumers, KEDA's Service Bus and Kafka scalers are ideal: when the queue fills, KEDA adds pods; when it empties, pods scale to zero. The main trade-off is cold start latency — a worker scaled to zero takes 5–30 seconds to restart, during which messages queue up. Set `minReplicaCount: 1` to avoid cold starts for latency-sensitive workloads.

## Detailed Explanation

### Why CPU-Based HPA Falls Short for Workers

Standard HPA reacts to CPU or memory metrics:

```
Messages arrive faster than consumers process → queue grows → workers at 100% CPU
HPA detects high CPU → scales up workers → queue drains → workers idle → CPU drops → scale down
```

Problems:
- **Lag in reaction**: CPU metrics take 1–3 minutes to trigger HPA; queue can grow to millions during that lag.
- **CPU is a proxy**: a message consumer may block on I/O (DB call, HTTP call) while using very little CPU — HPA sees low CPU but the queue is growing.
- **No scale-to-zero**: HPA minimum is 1 replica; KEDA supports `minReplicaCount: 0`.

KEDA directly observes the **work backlog** (queue length, consumer group lag) — the root cause metric, not a proxy.

### How KEDA Works

KEDA runs in the cluster and extends Kubernetes with custom `ScaledObject` resources. It polls the event source (Service Bus, Kafka, Redis, etc.) and sets the Deployment's replica count via the Kubernetes HPA API:

```
[External Event Source]
(Service Bus queue depth)
        │
        ▼
   [KEDA Scaler]  ← polls every 30s (configurable)
        │
        ▼
  [Kubernetes HPA]  ← KEDA updates targetReplicas
        │
        ▼
  [Deployment] ← 0..N pods
```

### Azure Service Bus Scaler

The most common .NET scenario — processing a Service Bus queue or topic subscription:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: orders-processor-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: orders-processor          # name of the Deployment to scale
  minReplicaCount: 0                # scale to zero when idle
  maxReplicaCount: 20               # never exceed 20 pods
  pollingInterval: 15               # check queue depth every 15 seconds
  cooldownPeriod: 300               # wait 5 minutes before scaling down
  triggers:
    - type: azure-service-bus
      metadata:
        queueName: orders-incoming
        namespace: orders-servicebus-ns
        messageCount: "10"          # target: 10 messages per pod
        # e.g., 100 messages → KEDA wants 10 pods (100/10)
      authenticationRef:
        name: keda-service-bus-auth  # Managed Identity auth — no secrets in YAML

---
# Workload identity auth for KEDA → Service Bus
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: keda-service-bus-auth
spec:
  podIdentity:
    provider: azure-workload  # uses pod's Workload Identity (no connection string)
```

### Kafka Consumer Lag Scaler

For .NET services consuming from Kafka topics:

```yaml
triggers:
  - type: apache-kafka
    metadata:
      bootstrapServers: kafka-service:9092
      consumerGroup: orders-processor-group
      topic: orders.created
      lagThreshold: "50"    # target: 50 messages lag per pod
      # e.g., 500 messages lag → KEDA wants 10 pods
      offsetResetPolicy: latest
```

### Scale-to-Zero and Cold Start

Scale-to-zero means zero pods when idle — no compute cost when the queue is empty. The trade-off:

```
Queue empty → 0 pods running (cost = 0)
Message arrives → KEDA detects → schedules pod → pod starts → .NET app initializes → message processed
                  ↑ 15-30 seconds delay (cold start)
```

**Mitigations for cold start:**

**1. `minReplicaCount: 1`**: keep one pod always running — eliminates cold start at the cost of one pod's compute.

**2. Fast startup**: minimise startup time in the .NET host:
```csharp
// Don't run migrations at startup (12-Factor: Factor 12)
// Don't block on connection warmup — connect lazily
// Use AddSingleton with lazy initialization for expensive resources

builder.Services.AddSingleton<IServiceBusProcessor>(sp =>
{
    var client = new ServiceBusClient(connStr, new DefaultAzureCredential());
    return client.CreateProcessor("orders-incoming", new ServiceBusProcessorOptions
    {
        MaxConcurrentCalls = 10,
        AutoCompleteMessages = false,
    });
});
```

**3. Startup probe with no readiness delay**: ensure Kubernetes sends traffic as soon as the pod is ready.

**4. Pre-warming with placeholder replicas**: KEDA `minReplicaCount: 1` can be set on a schedule (KEDA `ScaledCron`) — scale to 1 during business hours, 0 overnight:

```yaml
triggers:
  - type: cron
    metadata:
      timezone: "Europe/Warsaw"
      start: "0 8 * * 1-5"     # Monday–Friday 8am: scale to minReplicaCount = 1
      end:   "0 20 * * 1-5"    # Monday–Friday 8pm: scale to minReplicaCount = 0
      desiredReplicas: "1"
```

### .NET Worker Host with KEDA

```csharp
// Minimal .NET Worker consuming Service Bus messages (KEDA manages replica count)
var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddAzureClients(clients =>
{
    clients.AddServiceBusClientWithNamespace(
        builder.Configuration["ServiceBus:Namespace"]);
    clients.UseCredential(new DefaultAzureCredential());
});

builder.Services.AddHostedService<OrdersProcessorWorker>();

// Graceful shutdown: finish current message before exiting (KEDA scale-down)
builder.Services.Configure<HostOptions>(o => o.ShutdownTimeout = TimeSpan.FromSeconds(30));

var host = builder.Build();
await host.RunAsync();

// Worker processes messages; KEDA adds more replicas when queue grows
public sealed class OrdersProcessorWorker(
    ServiceBusClient serviceBus,
    IOrdersService orders) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var processor = serviceBus.CreateProcessor("orders-incoming",
            new ServiceBusProcessorOptions { MaxConcurrentCalls = 5 });

        processor.ProcessMessageAsync += async args =>
        {
            var order = args.Message.Body.ToObjectFromJson<OrderCreatedEvent>();
            await orders.ProcessAsync(order, args.CancellationToken);
            await args.CompleteMessageAsync(args.Message, args.CancellationToken);
        };

        processor.ProcessErrorAsync += args =>
        {
            // Log error; KEDA doesn't affect message retry — that's Service Bus dead-lettering
            return Task.CompletedTask;
        };

        await processor.StartProcessingAsync(ct);
        await Task.Delay(Timeout.Infinite, ct);  // block until cancellation
        await processor.StopProcessingAsync();
    }
}
```

> **Warning:** KEDA's `cooldownPeriod` (default 5 minutes) controls how long to wait before scaling down after the queue empties. Set it long enough to avoid thrashing (rapidly scaling up and down). For burst-heavy workloads, set `cooldownPeriod` to 10–15 minutes.

## Common Follow-up Questions

- How does KEDA interact with Kubernetes HPA — can both be active on the same Deployment?
- What is the difference between KEDA `ScaledJob` and `ScaledObject`?
- How do you observe KEDA's scaling decisions — what metrics does it expose?
- How do you handle a Kafka consumer that is a slow consumer relative to the producer rate?
- What is the KEDA `ScaleTargetRef` and can KEDA scale a `StatefulSet` or `CronJob`?

## Common Mistakes / Pitfalls

- **`minReplicaCount: 0` for latency-sensitive workloads**: if the SLA requires messages to be processed within seconds, scale-to-zero is not acceptable — keep at least one replica running.
- **Too-aggressive `messageCount` per pod**: setting `messageCount: 1` (one pod per message) causes pod churn for moderate-volume queues; set it to match the expected throughput per pod.
- **Not handling `MaxConcurrentCalls` vs pod count**: if each pod processes 10 messages concurrently and you scale to 20 pods, you have 200 concurrent message handlers — ensure the DB connection pool can handle that.
- **KEDA polling interval too long**: `pollingInterval: 300` (5 minutes) means the queue can fill for 5 minutes before KEDA reacts; use 15–30 seconds for queues with variable load.
- **No dead-letter queue monitoring**: KEDA scales based on active message count; if messages are being dead-lettered silently, the queue appears to drain while processing is failing.

## References

- [KEDA — Kubernetes Event-Driven Autoscaler](https://keda.sh/)
- [KEDA Azure Service Bus scaler](https://keda.sh/docs/latest/scalers/azure-service-bus/)
- [KEDA Kafka scaler](https://keda.sh/docs/latest/scalers/apache-kafka/)
- [Azure Service Bus worker in .NET — Microsoft Docs](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-dotnet-how-to-use-topics-subscriptions)
- [See: azure-service-bus-patterns.md](./azure-service-bus-patterns.md)
- [See: kubernetes-for-dotnet-devs.md](./kubernetes-for-dotnet-devs.md)
