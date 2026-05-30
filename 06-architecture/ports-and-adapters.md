# Ports and Adapters (Hexagonal Architecture)

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟢 Junior
**Tags:** `hexagonal-architecture`, `ports-and-adapters`, `alistair-cockburn`, `adapters`, `driving-vs-driven`, `clean-architecture`

## Question

> What is Hexagonal Architecture (Ports and Adapters)? What is the difference between a driving adapter and a driven adapter, and how does this pattern relate to Clean Architecture?

## Short Answer

Hexagonal Architecture (Alistair Cockburn, 2005) models the application as a hexagon with a core (business logic) and ports — technology-neutral interfaces on the boundary. Adapters connect external technologies to these ports. **Driving adapters** (left side) initiate interaction: HTTP controllers, message consumers, CLI. **Driven adapters** (right side) are called by the application to interact with external systems: database repositories, email senders, file storage. This is structurally identical to Clean Architecture — both put business logic at the center, isolated from infrastructure via interfaces.

## Detailed Explanation

### The Hexagon Mental Model

```
           ┌─────────────────────────────────────┐
           │           DRIVING SIDE              │
           │  (initiates / calls the app)        │
 REST API  →→  [HTTP Adapter]                    │
 MQ Consumer →→ [MQ Adapter]    ┌──────────┐    │
 Test Suite →→ [Test Adapter]   │  APP     │    │
           │                    │  CORE    │    │
           │                    │(hexagon) │    │
           │   [DB Adapter] →→→ │          │    │
           │   [Email Adapter]→ └──────────┘    │
           │            DRIVEN SIDE             │
           │      (called by the app)           │
           └─────────────────────────────────────┘
```

### Ports

A **port** is an interface in the application core — the contract between the core and the outside world. There are two types:

- **Driving ports** (primary/inbound): interfaces that *the adapters call on the application*. Example: `IOrderApplicationService.PlaceOrder(...)`.
- **Driven ports** (secondary/outbound): interfaces that *the application calls on adapters*. Example: `IOrderRepository`, `IEmailSender`.

### Adapters

An **adapter** implements or uses a port, bridging the gap between the technology-neutral port and a specific technology:

| Adapter type | Example | Direction |
|---|---|---|
| HTTP adapter (driving) | ASP.NET Core controller calling `IOrderService` | Calls the app |
| Message consumer (driving) | `OrderCreatedConsumer : IConsumer<OrderCreated>` | Calls the app |
| Test adapter (driving) | xUnit test calling application use case directly | Calls the app |
| EF Core adapter (driven) | `EfOrderRepository : IOrderRepository` | App calls out |
| SMTP adapter (driven) | `SmtpEmailSender : IEmailSender` | App calls out |

### Relation to Clean Architecture

Both patterns share the same core principle: **business logic is isolated at the center with no outward dependencies**. The terminology differs:

| Hexagonal | Clean Architecture |
|---|---|
| Application core | Domain + Application rings |
| Driving port | Input boundary (use case interface) |
| Driven port | Output boundary (repository/service interface) |
| Driving adapter | Controller, consumer, CLI command |
| Driven adapter | Repository implementation, external service |

Clean Architecture adds a more granular ring model (Domain → Application → Infrastructure → UI) and the strict dependency rule, but both lead to the same structure in a .NET project.

### Test Adapter Advantage

The key insight of the name "test adapter": your test suite is **just another driving adapter**. It calls the same ports as the HTTP controller — but without any web server involved. This means you can test the entire application core (use cases, domain logic) without HTTP, without a real database (use an in-memory driven adapter), and without any framework setup.

```csharp
// Driving adapter 1: HTTP controller
app.MapPost("/orders", async (PlaceOrderRequest req, IOrderService svc) 
    => await svc.PlaceOrderAsync(req.CustomerId, req.Total));

// Driving adapter 2: xUnit test — same port, no HTTP needed
[Fact]
public async Task PlaceOrder_WithValidData_CreatesOrder()
{
    var svc = new OrderService(new InMemoryOrderRepository(), new FakeEmailSender());
    var orderId = await svc.PlaceOrderAsync(customerId: 1, total: 99m);
    Assert.True(orderId > 0);
}
```

## Code Example

```csharp
// ── APPLICATION CORE ──────────────────────────────────────────────

// Driving port (primary): what the adapters call on the app
public interface IOrderService
{
    Task<int> PlaceOrderAsync(int customerId, decimal total, CancellationToken ct = default);
}

// Driven port (secondary): what the app calls on infrastructure
public interface IOrderRepository
{
    Task<int> SaveAsync(Order order, CancellationToken ct = default);
}

// Application logic — no framework imports, only ports
public class OrderService(IOrderRepository orders, IEmailSender email) : IOrderService
{
    public async Task<int> PlaceOrderAsync(int customerId, decimal total, CancellationToken ct)
    {
        var order = new Order(customerId, total);
        var id = await orders.SaveAsync(order, ct);
        await email.SendOrderConfirmationAsync(customerId, id, ct);
        return id;
    }
}

// ── DRIVEN ADAPTERS (Infrastructure) ──────────────────────────────

public class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public async Task<int> SaveAsync(Order order, CancellationToken ct)
    {
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
        return order.Id;
    }
}

// ── DRIVING ADAPTER (HTTP / ASP.NET Core) ─────────────────────────

[ApiController, Route("orders")]
public class OrdersController(IOrderService orderService) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create(PlaceOrderRequest req, CancellationToken ct)
    {
        var id = await orderService.PlaceOrderAsync(req.CustomerId, req.Total, ct);
        return CreatedAtAction(nameof(Create), new { id }, id);
    }
}
```

## Common Follow-up Questions

- Why is the hexagon drawn with six sides — does the number matter?
- How does Hexagonal Architecture handle cross-cutting concerns like logging and caching?
- What is the difference between a port and a service interface in plain layered architecture?
- How do you structure a .NET solution to enforce Hexagonal Architecture via project references?
- How does Hexagonal Architecture relate to the Dependency Inversion Principle?

## Common Mistakes / Pitfalls

- **Confusing the two port types**: developers often put `IOrderRepository` on the "wrong" side. Driven ports are defined in the core for *the app to call out* — not for adapters to call in.
- **Over-creating ports**: not every method needs a port. If a collaboration never needs swapping (e.g., a domain value object formatter), an interface adds noise.
- **Putting adapter logic in the core**: parsing HTTP request bodies or constructing SQL strings inside the application service breaks the isolation the pattern is meant to create.
- **Forgetting the test adapter**: the biggest win of Hexagonal Architecture is enabling the test suite to drive the application core directly. If tests only go through the HTTP adapter, you're missing the key benefit.

## References

- [Hexagonal Architecture — Alistair Cockburn (original article)](https://alistair.cockburn.us/hexagonal-architecture/) (verify URL)
- [.NET Architecture guidance — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/architecture/)
- [See: dependency-inversion-in-architecture.md](./dependency-inversion-in-architecture.md)
- [See: layered-vs-clean-architecture.md](./layered-vs-clean-architecture.md)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
