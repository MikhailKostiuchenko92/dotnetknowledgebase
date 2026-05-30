# Data Ownership in Microservices

**Category:** Architecture / Microservices
**Difficulty:** 🔴 Senior
**Tags:** `microservices`, `data-ownership`, `database-per-service`, `shared-schema`, `integration-events`, `API-composition`

## Question

> What does "each microservice owns its data" mean? How do you handle cross-service data access — API composition, data replication via events, and the cost of no shared schema?

## Short Answer

"Each service owns its data" means no service directly queries another service's database — the DB is an implementation detail hidden behind the service's API. Cross-service reads use **API composition** (caller aggregates data from multiple services) or **data replication via events** (service A subscribes to service B's events and maintains a local copy of needed data). No shared schema eliminates the biggest microservice coupling risk — schema changes in one service can't break another. The cost: no cross-service joins, eventual consistency for replicated data, and more complex read paths.

## Detailed Explanation

### The Rule and Why It Matters

```
❌ Shared DB (anti-pattern — distributed monolith):
  OrderService  ──── direct SQL ──→ InventoryDB.Products
  PaymentService ─── direct SQL ──→ InventoryDB.Products
  
  Problem: InventoryService can never change its DB schema without breaking
  OrderService and PaymentService. Services are coupled through the database.

✅ Database-per-service:
  OrderService  ──→ Orders DB (only Orders data)
  PaymentService ──→ Payments DB (only Payments data)
  InventoryService ──→ Inventory DB (only Inventory data)
  
  Cross-service data access via API or event-based replication
```

### Option 1: API Composition (Synchronous)

The BFF or application service calls multiple services and assembles the response:

```csharp
// Order Detail BFF: assembles data from OrderService + CustomerService + InventoryService
public class OrderDetailAssembler(
    IOrderClient orders,
    ICustomerClient customers,
    IInventoryClient inventory)
{
    public async Task<OrderDetailDto> GetDetailAsync(int orderId, CancellationToken ct)
    {
        // Parallel calls to owning services
        var (order, customer) = await (
            orders.GetByIdAsync(orderId, ct),
            orders.GetCustomerIdAsync(orderId, ct).ContinueWith(
                t => customers.GetByIdAsync(t.Result, ct).Result)
        ).WhenAll();

        return new OrderDetailDto(
            Order: order,
            CustomerName: customer?.Name ?? "Unknown");
    }
}
```

### Option 2: Event-Based Data Replication

Service A subscribes to Service B's events and maintains a local read-only copy:

```csharp
// OrderService subscribes to CustomerService events
// and maintains a local cache of Customer names (for order display)
public class CustomerNameCache(AppDbContext db)
    : INotificationHandler<CustomerNameUpdatedIntegrationEvent>
{
    public async Task Handle(CustomerNameUpdatedIntegrationEvent e, CancellationToken ct)
    {
        // OrderService's local copy of Customer data (read-only, stale by design)
        var cached = await db.Set<CustomerNameSnapshot>()
            .FindAsync([e.CustomerId], ct);

        if (cached is null)
            db.Set<CustomerNameSnapshot>().Add(
                new CustomerNameSnapshot { CustomerId = e.CustomerId, Name = e.NewName });
        else
            cached.Name = e.NewName;

        await db.SaveChangesAsync(ct);
    }
}

// Now OrderService can query customer names without calling CustomerService
var orderWithCustomer = await db.Orders
    .Join(db.Set<CustomerNameSnapshot>(),
        o => o.CustomerId,
        c => c.CustomerId,
        (o, c) => new { o.Id, o.Total, c.Name })
    .ToListAsync(ct);
```

### Data Ownership Decisions

When to use API composition vs event replication:

| Scenario | API Composition | Event Replication |
|----------|----------------|------------------|
| **Freshness needed** | Real-time — use API | Stale ok — use events |
| **Read frequency** | Infrequent | High (many reads) |
| **Source service SLA** | High availability | Can tolerate downtime |
| **Data volume** | Small | Large reference data |
| **Example** | "Get customer credit limit for this order" | "Customer name on every order line" |

### Cross-Service Reporting

The hardest challenge: reports that need data from multiple services:

```csharp
// Option A: API composition for report (slow at scale)
public async Task<RevenueByCustomerReport> GenerateAsync(DateRange range, CancellationToken ct)
{
    var orders = await orderService.GetOrdersInRangeAsync(range, ct);
    var customerNames = await Task.WhenAll(
        orders.Select(o => customerService.GetNameAsync(o.CustomerId, ct)));
    // O(n) HTTP calls — doesn't scale for thousands of orders
}

// Option B: Dedicated reporting service with its own DB
// Subscribes to events from all services and maintains a denormalized reporting DB
public class ReportingService  // ← separate service, owns reporting DB
{
    // Consumes: OrderSubmittedEvent, PaymentCapturedEvent, CustomerUpdatedEvent
    // Maintains a single DB optimised for reports
    // Full outer joins, aggregations — no API calls needed
}
```

## Code Example

```csharp
// Bounded context integration: OrderService publishes integration events
// CustomerService consumes to maintain data sync

// OrderService publishes (integration event — not domain event)
public record OrderCustomerAssociationEvent(
    int OrderId, int CustomerId, string CustomerNameAtOrderTime) : IIntegrationEvent;

// No call to CustomerService at query time — customer name is stored with the order
public class CreateOrderHandler(IOrderRepository orders)
    : IRequestHandler<CreateOrderCommand, int>
{
    public async Task<int> Handle(CreateOrderCommand cmd, CancellationToken ct)
    {
        var customerName = cmd.CustomerName; // ← passed from the client, no service call
        var order = Order.Create(new CustomerId(cmd.CustomerId), customerName);
        // CustomerName is stored in Orders DB at creation time — frozen snapshot
        await orders.AddAsync(order, ct);
        return order.Id.Value;
    }
}
```

## Common Follow-up Questions

- How do you handle a situation where you need a JOIN between data owned by two services?
- What is the "shared database" anti-pattern, and how do you detect it in a code review?
- How do you migrate from a shared DB monolith to database-per-service?
- How do you ensure data consistency when a customer deletes their account across multiple services?
- What is the right granularity for integration events — should they carry full data or just IDs?

## Common Mistakes / Pitfalls

- **Calling another service's DB directly "just this once"**: direct DB access creates hidden coupling that's very hard to remove later. Even read-only direct DB access violates ownership.
- **Integration events with too little data**: an event `CustomerNameChanged { CustomerId: 7 }` with no new name forces every consumer to call the CustomerService to get the new name — defeating the purpose.
- **Over-replicating data**: maintaining a full copy of the Customer entity in OrderService for a single field (Name) is overkill. Replicate only the fields you actually need.
- **Forgetting GDPR when replicating PII**: if CustomerService sends `CustomerNameUpdatedEvent { Name: "John Smith" }` and OrderService stores it, a GDPR "right to erasure" request must be handled in OrderService too.

## References

- [Database per service pattern — microservices.io](https://microservices.io/patterns/data/database-per-service.html) (verify URL)
- [API Composition — microservices.io](https://microservices.io/patterns/data/api-composition.html) (verify URL)
- [See: inter-service-communication.md](./inter-service-communication.md)
- [See: distributed-transaction-patterns.md](./distributed-transaction-patterns.md)
