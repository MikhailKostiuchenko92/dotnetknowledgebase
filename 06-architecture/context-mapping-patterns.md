# Context Mapping Patterns

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `context-mapping`, `bounded-context`, `integration`, `ACL`, `shared-kernel`, `published-language`

## Question

> What are the DDD context mapping patterns? Describe Published Language, Open Host Service, and how they differ from Shared Kernel and Anticorruption Layer. How do you document a context map?

## Short Answer

Context mapping patterns describe the integration relationships between bounded contexts. **Open Host Service** exposes a well-defined protocol (REST API, gRPC) that consumers can integrate with independently. **Published Language** is the documented schema/format used by the Open Host Service — often OpenAPI, Protobuf, or a domain event schema registry. Together they enable loose coupling: consumers integrate on their own terms using the published spec. Combined with **Anticorruption Layer** (on the consumer side), this creates the full "provider exposes, consumer translates" architecture used in well-designed microservices.

## Detailed Explanation

### Complete Context Mapping Pattern Catalog

| Pattern | Direction | Coupling | Key characteristic |
|---------|-----------|---------|-------------------|
| **Shared Kernel** | Bidirectional | Very high | Both teams share and co-own code/data |
| **Customer-Supplier** | Upstream→Downstream | Medium | Upstream controls; downstream requests |
| **Conformist** | Upstream→Downstream | Medium | Downstream accepts upstream model as-is |
| **Anticorruption Layer** | Upstream→Downstream | Low | Downstream translates upstream model |
| **Open Host Service** | Provider→Consumers | Low | Provider exposes formal, versioned protocol |
| **Published Language** | Provider→Consumers | Low | The documented schema/format of an Open Host Service |
| **Separate Ways** | None | None | No integration; independent solutions |
| **Partnership** | Bidirectional | High | Two teams co-evolve models together |

### Open Host Service

The upstream team exposes a formal service interface that any consumer can use without direct team coordination. The interface is stable, versioned, and documented.

```csharp
// Inventory Context — Open Host Service exposed as REST API
[ApiController, Route("api/v{version:apiVersion}/inventory")]
[ApiVersion("1.0")]
[ApiVersion("2.0")]
public class InventoryController : ControllerBase
{
    // V1: returns simple availability
    [HttpGet("{productId}/availability"), MapToApiVersion("1.0")]
    public async Task<InventoryAvailabilityV1> GetAvailabilityV1(int productId)
        => await _service.GetAvailabilityAsync(productId);

    // V2: returns richer response without breaking V1 consumers
    [HttpGet("{productId}/availability"), MapToApiVersion("2.0")]
    public async Task<InventoryAvailabilityV2> GetAvailabilityV2(int productId)
        => await _service.GetAvailabilityWithBreakdownAsync(productId);
}
```

### Published Language

The Published Language is the formal schema. In REST APIs: OpenAPI specification. In async messaging: JSON Schema, Avro schema, CloudEvents. The key property: **it's documented and versioned**, enabling consumers to integrate without talking to the producing team.

```csharp
// Schema for an integration event — the "published language"
// This schema is documented in the schema registry
public record OrderConfirmedEvent
{
    [JsonPropertyName("specversion")]
    public string SpecVersion { get; init; } = "1.0"; // CloudEvents

    [JsonPropertyName("type")]
    public string Type { get; init; } = "com.yourcompany.orders.order_confirmed.v1";

    [JsonPropertyName("orderId")]
    public int OrderId { get; init; }

    [JsonPropertyName("customerId")]
    public int CustomerId { get; init; }

    [JsonPropertyName("totalAmount")]
    public decimal TotalAmount { get; init; }

    [JsonPropertyName("currency")]
    public string Currency { get; init; } = "USD";

    // ← v1 schema — any consumer can rely on these fields being present
}
```

### Documenting a Context Map

A context map should be a lightweight diagram, not a formal document. Options:

**Simple ASCII/Mermaid diagram:**
```
graph LR
    Orders["Orders Context"] -->|OrderConfirmed PL| Shipping["Shipping Context"]
    Orders -->|OHS/REST| Inventory["Inventory Context"]
    Shipping -->|ACL| LegacyERP["Legacy ERP (3rd party)"]
    Billing["Billing Context"] -.->|Conformist| Stripe["Stripe (external)"]
    Orders --- CRM["CRM Context"]
    Orders -.->|Shared Kernel: Money, Address| CRM
```

**In code with C# attributes (some teams use this pattern):**

```csharp
// ContextMap.cs — living documentation in code
[BoundedContext("Orders")]
[Uses(typeof(InventoryContext), Pattern = "CustomerSupplier", Direction = "Downstream")]
[Uses(typeof(CrmContext), Pattern = "SharedKernel", SharedType = typeof(Money))]
[Uses(typeof(ShippingContext), Pattern = "PublishedLanguage", EventContract = "OrderConfirmedEvent")]
[Uses("Stripe", Pattern = "Conformist")]
public class OrdersContextMap { } // marker class — compiles if types exist
```

### Partnership Pattern

Both teams co-evolve their models together — high coordination, used when both contexts change together frequently:

```csharp
// Both Orders and Payments teams agree on the PaymentInitiated event contract
// Either team can propose changes; both must agree before publishing
[PartnerContext("Payments")]
public record PaymentInitiatedEvent(
    OrderId OrderId,
    Money Amount,
    string PaymentMethodToken,
    string CorrelationId);
```

## Code Example

```csharp
// Full integration: Orders (OHS/PL) → Shipping (ACL consumer)

// Orders context publishes integration event (Published Language)
public class PublishOrderConfirmedIntegrationEvent(IEventBus bus)
    : INotificationHandler<OrderSubmittedDomainEvent>
{
    public Task Handle(OrderSubmittedDomainEvent e, CancellationToken ct)
        => bus.PublishAsync(new OrderConfirmedEvent
        {
            OrderId = e.OrderId.Value,
            CustomerId = e.CustomerId.Value,
            TotalAmount = e.Total.Amount,
            Currency = e.Total.Currency
        }, ct);
}

// Shipping context consumes event via ACL (translates into Shipping's own model)
public class OrderConfirmedConsumer(IShipmentService shipments)
    : IConsumer<OrderConfirmedEvent> // MassTransit consumer
{
    public async Task Consume(ConsumeContext<OrderConfirmedEvent> context)
    {
        // ACL: translate from Published Language → Shipping domain
        var shipment = CreateShipmentFrom(context.Message);
        await shipments.ScheduleAsync(shipment);
    }

    private static ShipmentRequest CreateShipmentFrom(OrderConfirmedEvent e)
        => new(
            SourceOrderId: new ShippingOrderId(e.OrderId), // Shipping's own ID type
            RecipientId: new ShippingCustomerId(e.CustomerId),
            Value: new ShippingValue(e.TotalAmount, e.Currency));
}
```

## Common Follow-up Questions

- How do you version an integration event schema (Published Language) without breaking consumers?
- How does a Schema Registry (like Confluent) help enforce Published Language contracts?
- When does Open Host Service become a bottleneck — and how do you scale it?
- How do you test that an ACL correctly translates a Published Language event into your domain model?
- What tools exist for visualising context maps in large organisations?

## Common Mistakes / Pitfalls

- **Open Host Service with no versioning**: changing an API used by 10 consumers without version negotiation forces simultaneous upgrades — the antithesis of loose coupling.
- **Published Language that leaks internal domain concepts**: integration events should express business concepts, not internal implementation details (avoid `EfCoreOrderEntity` in the event payload).
- **Treating every integration as Conformist**: passively adopting every external system's model without deliberate ACL eventually corrupts your domain language with foreign terms.
- **Context map that exists only at design time**: document the context map where the team can see it (ADR, architecture diagram in the repo). A context map that exists only in someone's head decays immediately.

## References

- [Context Mapping — DDD Reference, Eric Evans](https://www.domainlanguage.com/ddd/reference/) (verify URL)
- [Published Language and Open Host Service — InfoQ](https://www.infoq.com/articles/ddd-contextmapping/) (verify URL)
- [See: shared-kernel-vs-separate-ways.md](./shared-kernel-vs-separate-ways.md)
- [See: anticorruption-layer.md](./anticorruption-layer.md)
- [See: bounded-context.md](./bounded-context.md)
