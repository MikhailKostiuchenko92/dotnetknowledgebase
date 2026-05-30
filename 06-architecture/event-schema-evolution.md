# Event Schema Evolution

**Category:** Architecture / Event Sourcing
**Difficulty:** 🔴 Senior
**Tags:** `event-sourcing`, `schema-evolution`, `upcasters`, `versioned-events`, `forward-compatibility`, `backward-compatibility`

## Question

> How do you handle event schema evolution in Event Sourcing? What is an upcaster, and how do you implement forward and backward compatibility strategies?

## Short Answer

Since stored events are immutable facts, you can never modify them. Schema evolution is handled by **upcasters** — pure functions that transform an old event version into the current version during deserialization. You also need naming strategies (short discriminator strings, not assembly-qualified names) to decouple event type identity from implementation. Forward compatibility (old code reads new events) requires ignoring unknown fields. Backward compatibility (new code reads old events) requires upcasters. The key rule: **never change a stored event's meaning — add new event types instead**.

## Detailed Explanation

### The Core Problem

```
Event stored in 2023:
  { "eventType": "OrderCreated", "orderId": 42, "customerId": 7, "total": 99.99 }

In 2024, you add a currency field to the domain:
  New code expects: { ..., "currency": "USD" }
  Old event: no "currency" field → deserialization fails or returns null

You cannot go back and add "currency" to 5 million stored events.
Solution: upcaster — transform the old event at read time.
```

### Upcaster Implementation

```csharp
// Upcaster: pure function from old version to new version
public static class OrderCreatedUpcasters
{
    // V1 → V2: add default currency
    public static OrderCreatedEvent V1ToV2(OrderCreatedEventV1 v1) =>
        new OrderCreatedEvent(
            OrderId: v1.OrderId,
            CustomerId: v1.CustomerId,
            Total: v1.Total,
            Currency: "USD");  // ← default for events before multi-currency support
}

// Apply upcasters in the deserialization pipeline
public object Deserialize(string eventType, ReadOnlySpan<byte> payload, int schemaVersion)
{
    return (eventType, schemaVersion) switch
    {
        ("OrderCreated", 1) =>
            OrderCreatedUpcasters.V1ToV2(
                JsonSerializer.Deserialize<OrderCreatedEventV1>(payload)!),
        ("OrderCreated", 2) =>
            JsonSerializer.Deserialize<OrderCreatedEvent>(payload)!,
        _ => throw new UnknownEventException(eventType, schemaVersion)
    };
}
```

### Versioning Strategies

**Option A: Versioned event type names** (discriminator strings)

```csharp
// Store event type as a versioned discriminator — NOT the .NET type name
public const string EventTypeName = "OrderCreated";         // v1
public const string EventTypeName = "OrderCreated_v2";      // v2 — new name = new type

// In the event store registry
options.Events.MapEventType<OrderCreatedEvent>("OrderCreated_v2");
options.Events.MapEventType<OrderCreatedEventV1>("OrderCreated");   // old type name kept

// Upcasters registered per event type name
eventRegistry.RegisterUpcaster("OrderCreated", raw => UpcastV1ToV2(raw));
```

**Option B: Schema version field in event metadata**

```json
{
  "eventType": "OrderCreated",
  "schemaVersion": 2,
  "orderId": 42,
  "customerId": 7,
  "total": 99.99,
  "currency": "USD"
}
```

```csharp
// Deserializer reads schemaVersion from metadata envelope and applies upcasters
public object Deserialize(EventRecord record)
{
    var meta = JsonSerializer.Deserialize<EventMetadata>(record.Metadata.Span)!;
    return meta.SchemaVersion < CurrentSchemaVersion
        ? ApplyUpcaster(record.EventType, meta.SchemaVersion, record.Data)
        : JsonSerializer.Deserialize(record.Data.Span, _typeMap[record.EventType])!;
}
```

### Forward Compatibility: New Fields, Old Readers

Old code reading events with new fields should ignore unknown fields:

```csharp
// System.Text.Json: unknown properties are ignored by default
var options = new JsonSerializerOptions { UnknownTypeHandling = JsonUnknownTypeHandling.JsonElement };

// Or be explicit: only deserialize known properties
[JsonPropertyName("orderId")] public int OrderId { get; init; }
[JsonPropertyName("customerId")] public int CustomerId { get; init; }
// New "shippingTier" field from v3 — ignored by v2 code
```

### Breaking Changes That Require New Event Types

Not all changes can be handled by upcasters. These require a new event type:

| Change | Upcaster OK? | Recommendation |
|--------|-------------|----------------|
| Add optional field with default | ✅ Yes | Upcaster sets default value |
| Rename field | ✅ Yes | Upcaster maps old name to new |
| Add required field, no default | ❌ No | New event type or reject old events |
| Change field meaning/semantics | ❌ No | New event type |
| Split event into two events | ❌ No | New event types, retire old one |
| Remove field that's still used | ❌ No | Keep field, mark as deprecated |

```csharp
// Adding a breaking semantic change: instead of upcasting, emit a new event type
// Old: OrderConfirmed (includes payment details — mixing concerns)
// New: OrderConfirmed + PaymentCaptured (separate events)
// → Register both; old streams use OrderConfirmed, new streams use both
```

### Type Name Registration (Decoupling from Assembly Names)

```csharp
// ❌ BAD: brittle — breaks when you rename the class or namespace
eventStore.Register(typeof(OrderCreatedEvent)); // → "MyApp.Domain.Orders.OrderCreatedEvent, MyApp.Domain"

// ✅ GOOD: stable short name
options.Events.MapEventType<OrderCreatedEvent>("OrderCreated");
// Name never changes even if you move/rename the class
```

## Code Example

```csharp
// Full upcasting pipeline with Marten
options.Events.Upcast<OrderCreatedEventV1, OrderCreatedEvent>(
    v1 => new OrderCreatedEvent(v1.OrderId, v1.CustomerId, v1.Total, "USD"));

// Marten applies this upcaster transparently when reading old events
// Code only sees OrderCreatedEvent — never sees OrderCreatedEventV1 directly
var order = await session.Events.AggregateStreamAsync<Order>(orderId);
// ↑ Old events are upcasted; new events are deserialized directly
```

## Common Follow-up Questions

- How do you test upcasters to ensure they don't introduce regressions?
- When is it acceptable to "burn" old events and re-seed the event store?
- How do you handle upcaster chains — v1 → v2 → v3?
- How does schema evolution interact with snapshot invalidation?
- What is an event schema registry, and when do you need one?

## Common Mistakes / Pitfalls

- **Using assembly-qualified type names as event type discriminators**: moving or renaming a class breaks all stored events. Always map events to stable short name strings.
- **Upcasters with side effects**: upcasters must be pure, deterministic functions. An upcaster that calls an external service or has random behavior makes event replay non-deterministic.
- **Not versioning event names from day one**: adding version suffixes retroactively (`OrderCreated` → `OrderCreated_v2`) is much harder when there are already 10 event types in production.
- **Upcaster chains without automated tests**: a chain v1→v2→v3 where v2→v3 was changed without re-testing v1→v2→v3 can silently corrupt data.

## References

- [Event versioning strategies — Versioning in an Event Sourced System (Greg Young)](https://leanpub.com/esversioning/read) (verify URL)
- [Marten event upcasting](https://martendb.io/events/versioning.html)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: event-store-design.md](./event-store-design.md)
