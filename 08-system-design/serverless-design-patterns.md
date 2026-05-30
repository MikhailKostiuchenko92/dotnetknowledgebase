# Serverless Design Patterns

**Category:** System Design / Cloud-Native
**Difficulty:** Senior
**Tags:** `serverless`, `azure-functions`, `cold-start`, `durable-functions`, `scale-to-zero`, `faas`

## Question

> What are the advantages and disadvantages of serverless (Function-as-a-Service) architecture? When does serverless hurt rather than help? How do Azure Functions work, and what are Durable Functions used for?

- What is cold start and how do you mitigate it in .NET Azure Functions?
- When should you choose serverless over containers (AKS)?

## Short Answer

Serverless (FaaS) eliminates server management — you provide code and the platform handles provisioning, scaling, and billing per invocation. Azure Functions supports HTTP, queue, timer, and event triggers; scale-to-zero makes it cost-effective for intermittent workloads. Key disadvantages are cold start latency (100ms–5s for .NET on Consumption plan), execution time limits, and limited control over the execution environment. Durable Functions extend Azure Functions with stateful orchestration patterns (fan-out/fan-in, long-running workflows, human approval steps). Serverless hurts when workloads are consistently high-throughput (you'd pay more than a container) or require sustained low latency (cold starts are unpredictable).

## Detailed Explanation

### What Serverless Means

```
Traditional container:        Serverless (Azure Functions, Consumption plan):
  Always running              Only runs when triggered
  You manage scaling          Platform scales automatically (0 → 1000s of instances)
  Fixed cost (24/7)           Pay per invocation (0 cost when idle)
  Full control                Constrained: execution limits, no persistent state
```

Azure Functions Consumption plan:
- **Billing**: pay per 1M executions + GB-seconds of memory.
- **Scale**: 0 → 200 instances automatically.
- **Timeout**: 5 minutes default (configurable up to 10 minutes; unlimited for Durable Functions).
- **Cold start**: first invocation after idle period incurs startup penalty.

### Cold Start in .NET Azure Functions

Cold start = time to provision a new instance + .NET runtime init + app startup:

| Plan | Cold start |
|------|-----------|
| Consumption | 1–5 seconds (.NET); worse for large apps |
| Premium | <1 second (always-warm instances) |
| Dedicated (App Service) | No cold start (always running) |

```csharp
// Mitigation 1: Native AOT (preview) — faster startup, smaller memory footprint
// Publish with: dotnet publish --runtime linux-x64 -p:PublishAot=true

// Mitigation 2: Minimal dependencies — each NuGet package adds startup time
// Don't import heavyweight frameworks into a simple HTTP function

// Mitigation 3: Deferred initialization — don't block constructor with I/O
// ❌ Bad: connecting to DB in constructor
public class OrdersFunction(AppDbContext db)  { ... }  // AppDbContext.OnConfiguring connects

// ✅ Better: lazy connection
public class OrdersFunction(Lazy<AppDbContext> db) { ... }  // connects on first use
```

```csharp
// Mitigation 4: Premium plan with "always ready" instances (no scale-to-zero)
// host.json
{
  "extensions": {
    "http": {
      "maxConcurrentRequests": 100
    }
  }
}
// Azure portal / Bicep: set minimumInstances = 1 for always-warm
```

### Azure Functions Trigger Types

```csharp
// HTTP trigger — REST API endpoint
[Function("CreateOrder")]
public async Task<IActionResult> CreateOrder(
    [HttpTrigger(AuthorizationLevel.Function, "post", Route = "orders")] HttpRequest req,
    FunctionContext ctx)
{
    var order = await req.ReadFromJsonAsync<CreateOrderRequest>();
    // ...
    return new OkObjectResult(new { orderId = order.Id });
}

// Queue trigger — process Service Bus messages (scales with queue depth)
[Function("ProcessOrder")]
public async Task ProcessOrder(
    [ServiceBusTrigger("orders-incoming", Connection = "ServiceBusConnection")]
    ServiceBusReceivedMessage message,
    FunctionContext ctx)
{
    var order = message.Body.ToObjectFromJson<OrderCreatedEvent>();
    await _orders.ProcessAsync(order, ctx.CancellationToken);
}

// Timer trigger — scheduled job (replaces cron)
[Function("CleanupExpiredSessions")]
public async Task CleanupExpiredSessions(
    [TimerTrigger("0 0 * * * *")] TimerInfo timer,  // every hour
    FunctionContext ctx)
{
    await _sessions.DeleteExpiredAsync(DateTimeOffset.UtcNow, ctx.CancellationToken);
}

// Blob trigger — react to new files in storage
[Function("ProcessUploadedFile")]
public async Task ProcessUploadedFile(
    [BlobTrigger("uploads/{name}", Connection = "StorageConnection")] Stream blobStream,
    string name,
    FunctionContext ctx)
{
    await _processor.ProcessAsync(name, blobStream, ctx.CancellationToken);
}
```

### Durable Functions: Stateful Workflows

Standard functions are stateless — they can't wait for something to happen or coordinate multiple steps. Durable Functions solve this by persisting state in Azure Storage:

**Pattern 1: Function Chaining**

```csharp
[Function("OrderOrchestrator")]
public async Task<string> RunOrchestrator(
    [OrchestrationTrigger] TaskOrchestrationContext context)
{
    // Each step runs as a separate function; state is checkpointed between steps
    var validated = await context.CallActivityAsync<bool>("ValidateOrder", context.GetInput<OrderDto>());
    if (!validated) return "Order validation failed";

    var reserved  = await context.CallActivityAsync<bool>("ReserveInventory", context.InstanceId);
    var charged   = await context.CallActivityAsync<bool>("ChargePayment", context.InstanceId);
    var confirmed = await context.CallActivityAsync<string>("SendConfirmation", context.InstanceId);
    return confirmed;
}
```

**Pattern 2: Fan-Out / Fan-In (Parallel Execution)**

```csharp
[Function("GenerateReports")]
public async Task<List<string>> FanOutFanIn(
    [OrchestrationTrigger] TaskOrchestrationContext context)
{
    var reportTypes = new[] { "sales", "inventory", "customers" };

    // Fan-out: start all reports in parallel
    var tasks = reportTypes
        .Select(t => context.CallActivityAsync<string>("GenerateReport", t))
        .ToList();

    // Fan-in: wait for all to complete
    var results = await Task.WhenAll(tasks);
    return results.ToList();
}
```

**Pattern 3: Human Approval (Async External Event)**

```csharp
[Function("ApprovalWorkflow")]
public async Task<string> ApprovalWorkflow(
    [OrchestrationTrigger] TaskOrchestrationContext context)
{
    // Send approval request email (activity function)
    await context.CallActivityAsync("SendApprovalEmail", context.InstanceId);

    // Wait up to 3 days for human to approve via HTTP callback
    using var cts = new CancellationTokenSource();
    var timeout = context.CreateTimer(context.CurrentUtcDateTime.AddDays(3), cts.Token);
    var approval = context.WaitForExternalEvent<bool>("ApprovalResult");

    var winner = await Task.WhenAny(approval, timeout);

    if (winner == approval)
    {
        cts.Cancel();          // cancel timeout timer
        return approval.Result ? "Approved" : "Rejected";
    }
    return "Timed out — escalated";
}

// Approver clicks a link → HTTP trigger sends the external event
[Function("SendApproval")]
public async Task<IActionResult> SendApproval(
    [HttpTrigger(AuthorizationLevel.Function, "post", Route = "approval/{instanceId}/{approved}")]
    HttpRequest req, string instanceId, bool approved,
    [DurableClient] DurableTaskClient client)
{
    await client.RaiseEventAsync(instanceId, "ApprovalResult", approved);
    return new OkResult();
}
```

### When Serverless Hurts

| Scenario | Why serverless hurts | Better choice |
|----------|---------------------|--------------|
| Steady high throughput (>50 req/s) | Per-invocation cost > reserved capacity | AKS / Container Apps |
| Sub-100ms p99 latency SLA | Cold starts are unpredictable | Premium plan or container |
| Long-running compute (>10 min) | Timeout limits | AKS, Batch |
| Complex stateful logic | Durable Functions have overhead | AKS + stateful service |
| Large binary dependencies (>500MB) | Cold start penalty grows | Container |
| Custom runtime/OS requirements | No control over host OS | Container |

> **Warning:** Serverless billing is non-linear. At low invocation rates, Consumption plan is extremely cheap. Above ~10M invocations/month or sustained 50+ req/s, a Premium plan or dedicated container becomes cheaper. Model your expected invocation rate before committing to Consumption plan for high-traffic APIs.

### Serverless vs Containers Decision Guide

```
Is the workload event-driven or intermittent?
├── Yes → Does cold start matter?
│         ├── No  → Azure Functions Consumption plan ✅ (cheapest)
│         └── Yes → Azure Functions Premium plan or Container Apps
└── No  → Is the workload stateless and HTTP-based?
           ├── Yes → Azure Container Apps (simpler than AKS)
           └── No  → AKS (full control, stateful, long-running)
```

## Code Example

```csharp
// Minimal Azure Functions .NET Isolated Worker (recommended for new projects)
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        // Register application services — same as ASP.NET Core DI
        services.AddDbContext<AppDbContext>(o =>
            o.UseNpgsql(Environment.GetEnvironmentVariable("DB_CONNECTION")));
        services.AddScoped<IOrdersService, OrdersService>();
        services.AddApplicationInsightsTelemetryWorkerService();
    })
    .Build();

await host.RunAsync();

// Function class — constructor injection works normally
public sealed class OrdersFunctions(IOrdersService orders, ILogger<OrdersFunctions> logger)
{
    [Function("GetOrder")]
    public async Task<HttpResponseData> GetOrder(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "orders/{id:guid}")] HttpRequestData req,
        Guid id)
    {
        var order = await orders.GetAsync(id);
        if (order is null)
        {
            var notFound = req.CreateResponse(HttpStatusCode.NotFound);
            return notFound;
        }

        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(order);
        return response;
    }
}
```

## Common Follow-up Questions

- What is Azure Container Apps and how does it compare to Azure Functions?
- How does Durable Functions handle replay (determinism requirement)?
- How do you deploy Azure Functions in a private VNet without public internet access?
- What is the difference between Azure Functions Isolated Worker and In-Process model?
- How do you test Azure Functions locally and in a CI pipeline?

## Common Mistakes / Pitfalls

- **Using Consumption plan for sustained high-traffic APIs**: cold starts hurt users; use Premium plan or migrate to Container Apps for >20 req/s sustained.
- **Storing state in static variables**: multiple function instances run independently; static state is not shared and is lost on scale-down.
- **Not setting `FunctionTimeout` explicitly**: default 5 minutes on Consumption can silently truncate long operations; set `functionTimeout` in `host.json` appropriately.
- **Using In-Process model for new .NET projects**: the .NET In-Process model is deprecated; use the Isolated Worker model (runs in a separate process, supported long-term).
- **Infinite Durable Function history**: Durable Functions append events to an Azure Storage table; orchestrations that run millions of iterations without checkpointing create enormous history tables — use `ContinueAsNew` to truncate history for eternal workflows.

## References

- [Azure Functions documentation — Microsoft Docs](https://learn.microsoft.com/en-us/azure/azure-functions/)
- [Durable Functions patterns — Microsoft Docs](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-overview)
- [Azure Functions best practices — Microsoft Docs](https://learn.microsoft.com/en-us/azure/azure-functions/functions-best-practices)
- [Azure Container Apps vs Azure Functions](https://learn.microsoft.com/en-us/azure/container-apps/compare-options)
- [See: containers-and-orchestration.md](./containers-and-orchestration.md)
- [See: event-driven-autoscaling.md](./event-driven-autoscaling.md)
