# How Do You Approach Testing in a CQRS Architecture?

**Category:** Testing / Advanced Topics
**Difficulty:** 🔴 Senior
**Tags:** `CQRS`, `testing`, `MediatR`, `commands`, `queries`, `handlers`

## Question
> How do you approach testing in a CQRS architecture (handlers, queries, commands)?

## Short Answer
Test **command handlers** for side effects (repository calls, domain events published). Test **query handlers** for result correctness. Keep handlers thin by delegating to domain objects — test domain logic separately. Use the real `IMediator` for integration tests and inject direct handler instances for focused unit tests.

## Detailed Explanation

### CQRS Testing Matrix

| Layer | What to test | How |
|---|---|---|
| Command handler | Side effects: repository saved, events published | Mock deps, assert Save/Publish calls |
| Query handler | Returns correct data | Mock repo, assert result content |
| Domain model | Business rules, invariants | No mocks, pure unit tests |
| Pipeline behaviour | Validation, logging, transaction | Integration test with real mediator |
| Controller/endpoint | Routing, binding, HTTP contract | Integration test (WAF) |

### Testing a Command Handler
```csharp
public class PlaceOrderHandler(IOrderRepository repo, IEventPublisher events)
    : IRequestHandler<PlaceOrderCommand, Guid>
{
    public async Task<Guid> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(cmd.ProductId, cmd.Quantity);
        await repo.SaveAsync(order, ct);
        await events.PublishAsync(new OrderPlaced { OrderId = order.Id }, ct);
        return order.Id;
    }
}

[Fact]
public async Task Handle_ValidCommand_SavesAndPublishesEvent()
{
    var repo = new Mock<IOrderRepository>();
    var events = new Mock<IEventPublisher>();
    var sut = new PlaceOrderHandler(repo.Object, events.Object);

    var id = await sut.Handle(new PlaceOrderCommand { ProductId = 1, Quantity = 2 }, default);

    id.Should().NotBeEmpty();
    repo.Verify(r => r.SaveAsync(It.IsAny<Order>(), default), Times.Once);
    events.Verify(e => e.PublishAsync(It.IsAny<OrderPlaced>(), default), Times.Once);
}
```

### Testing a Query Handler
```csharp
public class GetOrderQueryHandler(IOrderReadRepository repo)
    : IRequestHandler<GetOrderQuery, OrderDto?>
{
    public async Task<OrderDto?> Handle(GetOrderQuery q, CancellationToken ct) =>
        await repo.GetByIdAsync(q.OrderId, ct);
}

[Fact]
public async Task Handle_ExistingOrder_ReturnsDto()
{
    var expected = new OrderDto { Id = 1, Total = 99m };
    var repo = Mock.Of<IOrderReadRepository>(r =>
        r.GetByIdAsync(1, default) == Task.FromResult<OrderDto?>(expected));

    var sut = new GetOrderQueryHandler(repo);
    var result = await sut.Handle(new GetOrderQuery { OrderId = 1 }, default);

    result.Should().BeEquivalentTo(expected);
}
```

### Testing MediatR Pipeline Behaviours
```csharp
// Integration test — real mediator + real pipeline
services.AddMediatR(cfg => {
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>();
    cfg.AddBehavior<IPipelineBehavior<,>, ValidationBehavior<,>>();
});

var mediator = sp.GetRequiredService<IMediator>();

// ValidationBehavior should reject invalid command
var act = async () => await mediator.Send(new PlaceOrderCommand { Quantity = -1 });
await act.Should().ThrowAsync<ValidationException>();
```

### Don't Mock `IMediator` in Controller Tests
```csharp
// ❌ Wrong — tests nothing meaningful
var mediator = new Mock<IMediator>();
mediator.Setup(m => m.Send(It.IsAny<IRequest>(), default)).ReturnsAsync(Guid.NewGuid());

// ✅ Correct — test the handler directly
var handler = new PlaceOrderHandler(repo.Object, events.Object);
```

## Code Example
```csharp
// Testing domain logic independently of CQRS infrastructure
public class Order
{
    public static Order Create(int productId, int quantity)
    {
        if (quantity <= 0) throw new DomainException("Quantity must be positive");
        return new Order { ProductId = productId, Quantity = quantity, Id = Guid.NewGuid() };
    }
}

[Fact]
public void Order_Create_NegativeQuantity_ThrowsDomainException()
{
    var act = () => Order.Create(1, -1);
    act.Should().Throw<DomainException>().WithMessage("*Quantity*");
}

[Fact]
public void Order_Create_ValidArgs_ReturnsOrder()
{
    var order = Order.Create(1, 5);
    order.ProductId.Should().Be(1);
    order.Quantity.Should().Be(5);
    order.Id.Should().NotBeEmpty();
}

// Handler test — uses domain object, mocks infra only
[Fact]
public async Task PlaceOrder_ValidCommand_PersistsOrder()
{
    var repo = new Mock<IOrderRepository>();
    var events = new Mock<IEventPublisher>();
    var sut = new PlaceOrderHandler(repo.Object, events.Object);

    await sut.Handle(new PlaceOrderCommand { ProductId = 1, Quantity = 5 }, default);

    repo.Verify(r => r.SaveAsync(It.Is<Order>(o => o.Quantity == 5), default), Times.Once);
}
```

## Common Follow-up Questions
- How do you test MediatR pipeline behaviours (validation, logging, transactions)?
- Should query handlers return domain objects or DTOs?
- How do you test event sourcing with CQRS?
- How do you test read models that are built from domain events?
- What is the difference between testing CQRS in a clean architecture vs. a traditional layered architecture?

## Common Mistakes / Pitfalls
- **Mocking `IMediator`** — tests nothing; mock handler dependencies instead.
- **No domain object tests** — if all logic lives in handlers, handlers become fat; extract domain logic and test it separately.
- **Integration-testing every handler** — use unit tests for business logic, integration tests for pipeline behaviours.
- **Coupling query and command tests** — keep separate test classes; commands → side effects, queries → result correctness.

## References
- [MediatR GitHub](https://github.com/jbogard/MediatR)
- [Jimmy Bogard — CQRS with MediatR](https://jimmybogard.com/tag/mediatr/)
- [See also: testing-messaging-mediatr.md](testing-messaging-mediatr.md)
