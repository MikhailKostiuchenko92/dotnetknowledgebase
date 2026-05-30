# Event Storming

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `event-storming`, `DDD`, `bounded-context`, `domain-events`, `workshop`, `Alberto-Brandolini`, `strategic-design`

## Question

> What is Event Storming? How does the workshop technique help discover bounded contexts and domain events? What are the different Event Storming formats — Big Picture, Process Level, and Design Level?

## Short Answer

**Event Storming** (Alberto Brandolini) is a collaborative, time-boxed workshop where domain experts and developers stand in front of a large paper roll and model a business domain using sticky notes. **Domain events** (orange) are the foundation — participants name things that happen ("Order Placed", "Payment Failed"). From events, the group discovers commands, actors, aggregates, policies, and bounded context boundaries. Event Storming surfaces domain knowledge, aligns vocabulary (Ubiquitous Language), identifies hotspots (conflicting or unclear areas), and produces a context map — in hours rather than weeks of documentation.

## Detailed Explanation

### The Three Formats

**Big Picture Event Storming** — Chaos → Order
- Goal: explore the entire domain in one session
- Duration: 4–8 hours with 10–20 participants
- Output: domain events on a timeline, hotspots (pink = unclear/conflict), bounded context draft

**Process Level Event Storming** — Flow Modelling
- Goal: model a specific business process in detail
- Duration: 2–4 hours with 5–10 participants
- Adds: commands (blue), actors (yellow), external systems (pink), policies (purple)

**Design Level Event Storming** — Software Design
- Goal: translate process model to aggregate/command/event design
- Duration: 2–4 hours with 2–5 developers
- Adds: read models, UI mockups, aggregate boundaries

### The Sticky Note Palette

| Colour | Represents | Example |
|--------|-----------|---------|
| 🟠 **Orange** | Domain event (past tense) | "Order Submitted", "Payment Cleared" |
| 🔵 **Blue** | Command (imperative) | "Submit Order", "Process Payment" |
| 🟡 **Yellow** | Actor / user / external system | "Customer", "Warehouse System" |
| 🟣 **Purple/lilac** | Policy / business rule | "When payment clears, schedule shipment" |
| 🟩 **Green** | Read model / projection | "Order List", "Customer Dashboard" |
| 🔴 **Red/pink** | Hotspot / problem / question | "Who decides price?" |
| 🧡 **Big orange** | Aggregate (Design Level) | `Order`, `Payment` |

### Event Storming Flow (Big Picture)

1. **Chaotic exploration** — everyone puts orange stickies on the wall simultaneously without order
2. **Enforce timeline** — arrange events left-to-right in time order
3. **Identify duplicates and contradictions** — merge duplicates, mark contradictions as hotspots
4. **Add actors and commands** — who triggers what?
5. **Add policies** — "whenever X happens, Y should happen"
6. **Identify pivotal events** — events that significantly change the flow or ownership
7. **Draw bounded context lines** — at the pivotal events, draw vertical lines; each segment is a candidate bounded context

### Discovering Bounded Contexts from Event Storming

Look for:
- **Language changes**: "Order" becomes "Shipment" — different vocabulary = different context
- **Different domain expert ownership**: shipping team vs billing team own different sections
- **Pivotal events** that transfer responsibility: `OrderConfirmed` → Shipping takes over from Orders
- **Hotspots** where experts disagree: usually a boundary or a shared kernel candidate

```
Events on the timeline:
  [Customer Browse] → [Item Added to Cart] → [Order Placed] | ← pivot
  | [Payment Requested] → [Payment Cleared] | ← pivot
  | [Shipment Scheduled] → [Shipment Dispatched] → [Delivered]
   ↑                         ↑                       ↑
  Orders context           Payments context        Shipping context
```

### Design Level: Aggregate Boundaries

At Design Level, each command-event pair gets associated with an aggregate:

```
[Submit Order Command] → [Order] → [Order Submitted Event]
                              ↗
                        [Customer] (actor)

[Process Payment Command] → [Payment] → [Payment Cleared Event]
                                   ↗
                             [Order Submitted Event] (policy trigger)
```

### Running Event Storming in .NET Teams

**Pre-meeting setup**:
- Roll of large paper on the wall (6m+)
- Coloured sticky notes (orange is most important)
- Pens (not pencils — legible from 3 meters)
- 60–90 minutes of uninterrupted time

**Facilitator rules**:
- No architecture decisions yet — only model the business
- Everyone writes, not just senior devs
- Hotspot anything unclear — don't stop to resolve
- 25-minute timeboxes with breaks

**Transition to code**:
- Events become `DomainEvent` records
- Commands become MediatR `IRequest` commands
- Aggregates become `AggregateRoot` classes
- Policies become domain event handlers

## Code Example

```csharp
// From Event Storming output to C# code structure
// Event Storming discovered: Orders, Payments, Shipping bounded contexts

// ── Events discovered in Event Storming ─────────────────────────
// Orange stickies → domain event records
public record OrderPlacedEvent(OrderId OrderId, CustomerId CustomerId, Money Total) : DomainEvent;
public record PaymentRequestedEvent(OrderId OrderId, Money Amount) : DomainEvent;
public record PaymentClearedEvent(PaymentId PaymentId, OrderId OrderId) : DomainEvent;
public record ShipmentScheduledEvent(ShipmentId ShipmentId, OrderId OrderId) : DomainEvent;
public record ShipmentDispatchedEvent(ShipmentId ShipmentId, TrackingNumber Tracking) : DomainEvent;

// ── Policies discovered in Event Storming ────────────────────────
// Purple stickies → domain event handlers / policies
// "When OrderPlaced, request payment"
public class RequestPaymentOnOrderPlaced : INotificationHandler<OrderPlacedEvent>
{
    public Task Handle(OrderPlacedEvent e, CancellationToken ct)
        => _payments.RequestAsync(new PaymentRequest(e.OrderId, e.Total), ct);
}

// "When PaymentCleared, schedule shipment"
public class ScheduleShipmentOnPaymentCleared : INotificationHandler<PaymentClearedEvent>
{
    public Task Handle(PaymentClearedEvent e, CancellationToken ct)
        => _shipments.ScheduleAsync(new ShipmentRequest(e.OrderId), ct);
}

// ── Aggregates discovered in Event Storming ───────────────────────
// Big orange stickies → aggregate roots
// Order, Payment, Shipment — each owns its own events
```

## Common Follow-up Questions

- How do you handle Event Storming with remote teams — what digital tools work?
- How do you prioritize which bounded contexts to build first after Event Storming?
- What is the difference between a domain event discovered in Event Storming and an integration event in code?
- How often should you revisit the Event Storming model as the system evolves?
- How do hotspots (red stickies) turn into product backlog items or architectural risks?

## Common Mistakes / Pitfalls

- **Developers only, no domain experts**: Event Storming without real domain experts produces a developer's guess at the domain, not the actual business model. The whole point is knowledge transfer.
- **Resolving every hotspot in the session**: hotspots are flagged, not solved. Stopping to debate every unclear area kills the momentum. Hotspots become follow-up conversations or ADRs.
- **Going straight to Design Level**: skipping Big Picture gives developers premature closure on bounded context boundaries before the full domain scope is visible.
- **Using Event Storming as a one-time event**: the model drifts as the business evolves. Regular "mini-storming" sessions (1–2 hours) for specific new features keep the model current.

## References

- [Introducing Event Storming — Alberto Brandolini](https://www.eventstorming.com/book/) (verify URL)
- [Event Storming guide — Mariusz Gil](https://github.com/mariuszgil/awesome-eventstorming) (verify URL)
- [DDD and Event Storming — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/azure/architecture/guide/architecture-styles/event-driven)
- [See: ddd-tactical-vs-strategic.md](./ddd-tactical-vs-strategic.md)
- [See: bounded-context.md](./bounded-context.md)
