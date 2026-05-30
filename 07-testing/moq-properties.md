# How Do You Mock Properties with Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `properties`, `SetupProperty`, `SetupGet`, `SetupSet`, `property-mocking`

## Question
> How do you mock properties with Moq?

## Short Answer
Use `mock.Setup(x => x.Property).Returns(value)` to stub a getter. For a settable property that you also need to track, use `mock.SetupProperty(x => x.Property)` which enables Moq to store and return the assigned value. For write-only verification, use `mock.SetupSet(x => x.Property = It.IsAny<T>())` and then `mock.VerifySet`.

## Detailed Explanation

### Read-Only Getter Stub
```csharp
var config = new Mock<IConfiguration>();
config.Setup(c => c.MaxRetries).Returns(3);

// SUT accesses config.MaxRetries → returns 3
```

### Read-Write Property Tracking (`SetupProperty`)
`SetupProperty` makes the property "live" — its value is stored in the mock and returned on subsequent gets. This is useful when the SUT assigns a value and later reads it back:

```csharp
var entity = new Mock<IEntity>();
entity.SetupProperty(e => e.Name); // default initial value = null/default

entity.Object.Name = "Alice";       // SUT sets the property
entity.Object.Name.Should().Be("Alice"); // returns the assigned value
```

Optional initial value:
```csharp
entity.SetupProperty(e => e.Status, EntityStatus.Active);
```

### `SetupAllProperties()`
Enables tracking for **all** properties in one call:
```csharp
var mock = new Mock<IMyInterface>();
mock.SetupAllProperties();
// All properties behave like SetupProperty — get/set round-trips
```

> ⚠️ **Warning:** `SetupAllProperties()` is convenient but sets up *everything*, including properties you may want to control manually. Prefer `SetupProperty(x => x.Prop)` for specific properties.

### Verifying a Property Was Set (`VerifySet`)
```csharp
var order = new Mock<IOrder>();
order.SetupSet(o => o.Status = It.IsAny<OrderStatus>());

sut.UpdateOrderStatus(order.Object, OrderStatus.Shipped);

order.VerifySet(o => o.Status = OrderStatus.Shipped, Times.Once);
```

### Verifying a Property Was Read (`VerifyGet`)
```csharp
var config = new Mock<IConfiguration>();
config.Setup(c => c.MaxRetries).Returns(3);

sut.ProcessWithRetry();

config.VerifyGet(c => c.MaxRetries, Times.AtLeastOnce);
```

### Indexed Properties
```csharp
var cache = new Mock<ICache>();
cache.Setup(c => c["user:1"]).Returns(cachedUser);
```

### Callback on Set
```csharp
var capturedStatus = default(OrderStatus);
order.SetupSet(o => o.Status = It.IsAny<OrderStatus>())
     .Callback<OrderStatus>(s => capturedStatus = s);
```

## Code Example
```csharp
namespace Configuration.Tests;

public interface IAppConfig
{
    int MaxConnections { get; }
    string ConnectionString { get; set; }
    bool IsDebugMode { get; set; }
}

public class ConnectionPoolTests
{
    [Fact]
    public void Initialize_UsesMaxConnectionsFromConfig()
    {
        // Stub read-only property
        var config = new Mock<IAppConfig>();
        config.Setup(c => c.MaxConnections).Returns(10);
        config.Setup(c => c.ConnectionString).Returns("Server=localhost");

        var sut = new ConnectionPool(config.Object);
        sut.Initialize();

        sut.MaxSize.Should().Be(10);
    }

    [Fact]
    public void Initialize_SetsDebugModeToFalseInProduction()
    {
        var config = new Mock<IAppConfig>();
        config.Setup(c => c.MaxConnections).Returns(5);
        config.Setup(c => c.ConnectionString).Returns("Server=prod");
        config.SetupProperty(c => c.IsDebugMode, true); // starts true

        var sut = new ConnectionPool(config.Object);
        sut.Initialize(); // should disable debug mode in production

        config.Object.IsDebugMode.Should().BeFalse();
    }

    [Fact]
    public void Initialize_SetsConnectionStringOnConfig()
    {
        var config = new Mock<IAppConfig>();
        config.Setup(c => c.MaxConnections).Returns(5);
        config.SetupSet(c => c.ConnectionString = It.IsAny<string>());

        var sut = new ConnectionPool(config.Object);
        sut.Initialize();

        // Verify the SUT set the connection string
        config.VerifySet(c => c.ConnectionString = It.Is<string>(s => s.Contains("Server")),
                         Times.Once);
    }
}
```

## Common Follow-up Questions
- What is the difference between `SetupProperty` and `Setup(x => x.Prop).Returns(...)`?
- How do you verify that a property was set to a specific value?
- How does `SetupAllProperties()` work and when should you avoid it?
- Can you mock auto-properties on concrete classes?
- How do you mock an indexed property (e.g., `this[string key]`)?
- How do callbacks work on property setters?

## Common Mistakes / Pitfalls
- **Forgetting `SetupProperty` for read-write tracking** — without it, setting `mock.Object.Prop = value` is ignored; reads still return the `Returns(...)` value.
- **`SetupAllProperties()` overriding manual setups** — call `SetupAllProperties` first, then override specific properties with `Setup(x => x.Prop).Returns(...)`.
- **Mocking non-virtual properties of concrete classes** — Moq uses Castle DynamicProxy; only virtual or interface members can be mocked.
- **`VerifySet` without `SetupSet`** — you may get a false-negative; always set up the property you intend to verify.
- **Asserting `mock.Object.Property` after set** — only works if `SetupProperty` or `SetupAllProperties` was called; otherwise returns the `Returns` value, not the assigned value.

## References
- [Moq documentation — Property mocking](https://github.com/devlooped/moq/wiki/Quickstart#properties)
- [Moq GitHub — SetupProperty source](https://github.com/devlooped/moq)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
