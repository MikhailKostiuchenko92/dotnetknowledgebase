# Task-Based UI and CQRS

**Category:** Architecture / CQRS
**Difficulty:** 🔴 Senior
**Tags:** `CQRS`, `task-based-UI`, `CRUD-UI`, `intention-revealing`, `UX`, `commands`

## Question

> What is a task-based UI, and why does it align better with CQRS than a CRUD UI? How do you design intention-revealing commands that capture business intent rather than generic property updates?

## Short Answer

A **task-based UI** exposes operations in terms of business tasks ("Confirm Order", "Reject Application", "Transfer Funds") rather than generic CRUD forms ("Edit Order"). Each task maps to a specific command with clear intent. A **CRUD UI** surfaces a generic form with all editable fields — the client sends a full object update (`PUT /orders/42`), losing the business intent. CQRS's command model thrives with task-based UIs: `ConfirmOrderCommand`, `RejectApplicationCommand`, and `TransferFundsCommand` map cleanly to aggregate methods with appropriate invariant checks, business events, and audit trails.

## Detailed Explanation

### The CRUD UI Problem

A typical CRUD form sends `PUT /orders/42` with a full `Order` object. The server must guess what changed:

```csharp
// ❌ CRUD-style: what changed? We don't know the intent
public class UpdateOrderRequest
{
    public string Status { get; set; } = "";
    public decimal Total { get; set; }
    public string ShippingAddress { get; set; } = "";
    public string CustomerNotes { get; set; } = "";
    // ... 20 more fields
}

// Handler has to figure out what the "intent" was
public async Task Handle(UpdateOrderCommand cmd, CancellationToken ct)
{
    var order = await orders.GetByIdAsync(cmd.OrderId, ct);
    // If status changed to "Cancelled" — what business rule? What event?
    // If total changed — was this a price correction? A discount? A product change?
    // We've lost all business context
    order.Status = cmd.Status;
    order.Total = cmd.Total;
    await uow.SaveChangesAsync(ct);
}
```

### Task-Based UI: Intention-Revealing Commands

Each action the user takes maps to a distinct command:

```csharp
// ✅ TASK-BASED: each command expresses a specific intent
public record ConfirmOrderCommand(int OrderId, int ConfirmedBy) : ICommand;
public record CancelOrderCommand(int OrderId, string Reason) : ICommand;
public record UpdateShippingAddressCommand(int OrderId, Address NewAddress) : ICommand;
public record ApplyDiscountCommand(int OrderId, decimal DiscountPercent, string AuthorisedBy) : ICommand;
public record AddOrderNoteCommand(int OrderId, string Note, int AddedBy) : ICommand;

// Each handler maps to a specific domain method
public class ConfirmOrderHandler(IOrderRepository orders, IUnitOfWork uow)
    : IRequestHandler<ConfirmOrderCommand>
{
    public async Task Handle(ConfirmOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(new OrderId(cmd.OrderId), ct);
        order.Confirm(new UserId(cmd.ConfirmedBy)); // ← domain enforces: must be Submitted first
        await uow.SaveChangesAsync(ct); // ← raises OrderConfirmedEvent with full context
    }
}
```

### UI Design Patterns for Task-Based UIs

Instead of one big "Edit" form, the UI offers specific action buttons/forms:

```
Order Detail Page
  ┌─────────────────────────────────────────────────────────┐
  │  Order #42 — Status: Submitted                          │
  │                                                         │
  │  [Confirm Order]  [Cancel Order ▼]  [Update Address]    │
  │                                                         │
  │  Lines:                                                 │
  │  Widget × 2  $49.99 each    [Remove Line]               │
  │  Gadget × 1  $99.00 each    [Remove Line]               │
  │                             [Add Line]                  │
  │                                                         │
  │  [Add Note]                                             │
  └─────────────────────────────────────────────────────────┘
```

Each button maps to a specific command:
- `[Confirm Order]` → `POST /orders/42/confirm` with `ConfirmOrderCommand`
- `[Cancel Order]` → `POST /orders/42/cancel` with reason selection
- `[Update Address]` → `POST /orders/42/shipping-address` with new address form

### REST API Design for Task-Based Commands

Sub-resource routes make the intent explicit:

```csharp
// ✅ Task-based endpoints (each expresses a specific action)
app.MapPost("/orders/{id}/confirm", (int id, ISender s, CancellationToken ct)
    => s.Send(new ConfirmOrderCommand(id), ct));

app.MapPost("/orders/{id}/cancel", (int id, CancelOrderRequest req, ISender s, CancellationToken ct)
    => s.Send(new CancelOrderCommand(id, req.Reason), ct));

app.MapPut("/orders/{id}/shipping-address", (int id, Address addr, ISender s, CancellationToken ct)
    => s.Send(new UpdateShippingAddressCommand(id, addr), ct));

// ❌ Generic CRUD (loses intent)
app.MapPut("/orders/{id}", (int id, UpdateOrderRequest req, ISender s, CancellationToken ct)
    => s.Send(new UpdateOrderCommand(id, req), ct)); // ← what does "update" mean here?
```

### When CRUD Is Fine

Task-based UI adds UX and code complexity. CRUD is appropriate when:
- The entity has no meaningful state transitions (product catalog, user profile settings)
- All fields are equally optional and independent updates
- The "task" genuinely is "edit these fields" (configuration data, content management)

> **Rule of thumb**: if a business user would describe the action as a verb beyond "change" (confirm, approve, reject, cancel, suspend), you need a task-based command. If the action is genuinely "set this field to this value" with no other implications, CRUD is fine.

## Code Example

```csharp
// The difference in domain event richness:

// CRUD update — what event do you raise?
order.Status = "Confirmed";  // ← no context: who confirmed it? why? what's the business impact?
Raise(new OrderStatusChangedEvent(Id, "Confirmed")); // ← meaningless event

// Task-based confirm — rich event with business context
public void Confirm(UserId confirmedBy)
{
    if (Status != OrderStatus.Submitted)
        throw new DomainException("Only submitted orders can be confirmed.");
    Status = OrderStatus.Confirmed;
    ConfirmedBy = confirmedBy;
    ConfirmedAt = DateTime.UtcNow;
    Raise(new OrderConfirmedEvent(Id, CustomerId, confirmedBy, Total, Lines.Count));
    // ← now you can: send confirmation email, reserve inventory, update analytics,
    //   calculate commissions — all triggered by this single rich event
}
```

## Common Follow-up Questions

- How do you handle a UI that allows editing multiple fields at once — do you split into multiple commands?
- How do you design task-based commands for SPA (React/Angular) frontends that use form-based editing?
- How does task-based UI affect API client code generation (NSwag, Kiota)?
- How do you handle optimistic locking in a task-based UI — what does the user see when a concurrent edit occurs?
- How do you communicate task availability (what commands are valid in the current state) to the UI?

## Common Mistakes / Pitfalls

- **Task-based commands for every field**: `UpdateCustomerFirstNameCommand`, `UpdateCustomerLastNameCommand`, `UpdateCustomerEmailCommand` taken too far produces excessive granularity for a simple profile edit with no business implications.
- **CRUD endpoints with task names in the URL**: `POST /orders/42/update` is still a CRUD update hidden behind a task-sounding URL. The command must carry intent, not just the endpoint name.
- **Task-based commands that return data**: `ConfirmOrderCommand` returning a full `OrderDto` with all fields merges command and query side. Return minimal confirmation data; let the client issue a read query if needed.
- **Combining multiple tasks into one "big update" command**: `UpdateOrderCommand` with optional fields that internally branches on "what changed" is CRUD thinking with a task-based name.

## References

- [Task-based UI and CQRS — Greg Young (original essay)](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf) (verify URL)
- [Intention-revealing interfaces — Eric Evans (DDD)](https://www.dddcommunity.org/book/evans_2003/) (verify URL)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: command-vs-query.md](./command-vs-query.md)
- [See: cqrs-and-ddd.md](./cqrs-and-ddd.md)
