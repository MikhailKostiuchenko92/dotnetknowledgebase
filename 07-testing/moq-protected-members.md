# How Do You Mock Protected Members in Moq?

**Category:** Testing / Mocking
**Difficulty:** 🔴 Senior
**Tags:** `moq`, `protected`, `Moq.Protected`, `HttpMessageHandler`, `template-method`

## Question
> How do you mock protected members in Moq?

## Short Answer
Use the `Moq.Protected` namespace and call `.Protected()` on the `Mock<T>` instance. This gives access to `Setup` and `Verify` overloads that accept the member name as a string along with argument matchers via `ItExpr` (the protected-method equivalent of `It`). It is most commonly needed when testing classes derived from abstract/base classes that expose extension points through protected virtuals (e.g., `HttpMessageHandler.SendAsync`).

## Detailed Explanation

### Why Protected Members Need Special Treatment
Moq generates a dynamic proxy that overrides virtual members. Protected virtual members are not directly accessible via lambda expressions in C# outside the class, so Moq provides a `Protected()` proxy that accepts member names as strings.

### Setup Syntax
```csharp
using Moq.Protected;

var mock = new Mock<MyBase>();
mock.Protected()
    .Setup<ReturnType>("ProtectedMethodName",
        ItExpr.IsAny<Arg1Type>(),
        ItExpr.IsAny<Arg2Type>())
    .Returns(someValue);
```

- Use `ItExpr` (not `It`) for argument matching.
- Use `.Setup("Void Method", ...)` for `void` methods.
- Use `.Setup<TReturn>("Method", ...)` for methods returning a value.

### Async Protected Methods
```csharp
mock.Protected()
    .Setup<Task<HttpResponseMessage>>(
        "SendAsync",
        ItExpr.IsAny<HttpRequestMessage>(),
        ItExpr.IsAny<CancellationToken>())
    .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK));
```

### Verify Protected Method Calls
```csharp
mock.Protected()
    .Verify("SendAsync",
        Times.Once(),
        ItExpr.Is<HttpRequestMessage>(req =>
            req.Method == HttpMethod.Post &&
            req.RequestUri!.PathAndQuery == "/api/orders"),
        ItExpr.IsAny<CancellationToken>());
```

### `ItExpr` vs `It`

| | `It` | `ItExpr` |
|---|---|---|
| Used with | Regular lambdas | `Protected()` string-based setups |
| Syntax | `It.IsAny<T>()` | `ItExpr.IsAny<T>()` |
| Custom predicate | `It.Is<T>(x => ...)` | `ItExpr.Is<T>(x => ...)` |

> ⚠️ If you mix `It` and `ItExpr` in a protected setup, Moq may not match calls correctly. Always use `ItExpr` inside `.Protected().Setup(...)`.

### Template Method Pattern Example
```csharp
public abstract class DataProcessor
{
    public ProcessResult Process(DataBatch batch)
    {
        Validate(batch); // protected virtual
        return Execute(batch); // protected abstract
    }

    protected virtual void Validate(DataBatch batch) { }
    protected abstract ProcessResult Execute(DataBatch batch);
}
```
Testing the base `Process` method by mocking its protected extension points:
```csharp
var mock = new Mock<DataProcessor> { CallBase = true };
mock.Protected()
    .Setup<ProcessResult>("Execute", ItExpr.IsAny<DataBatch>())
    .Returns(ProcessResult.Ok);
```

### When to Use It

| Scenario | Example |
|---|---|
| `HttpClient` testing | Mock `HttpMessageHandler.SendAsync` |
| Template method | Override protected abstract in base class |
| `Stream`-derived classes | Mock `Read`/`Write` |
| Legacy base class | Can't refactor to interface |

> 💡 If you find yourself frequently mocking protected members, consider refactoring to extract an interface instead — it makes the design cleaner and the test code type-safe.

## Code Example
```csharp
namespace Http.Tests;

public class ProductApiClientTests
{
    [Fact]
    public async Task GetProductAsync_ReturnsProduct_WhenApiSucceeds()
    {
        // Arrange
        var json = """{"id":1,"name":"Widget"}""";
        var response = new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };

        var handlerMock = new Mock<HttpMessageHandler>();
        handlerMock.Protected()
                   .Setup<Task<HttpResponseMessage>>(
                       "SendAsync",
                       ItExpr.IsAny<HttpRequestMessage>(),
                       ItExpr.IsAny<CancellationToken>())
                   .ReturnsAsync(response);

        var client = new HttpClient(handlerMock.Object)
        {
            BaseAddress = new Uri("https://api.example.com")
        };
        var sut = new ProductApiClient(client);

        // Act
        var product = await sut.GetProductAsync(1);

        // Assert
        product.Should().NotBeNull();
        product!.Name.Should().Be("Widget");

        // Verify the correct request was sent
        handlerMock.Protected()
                   .Verify(
                       "SendAsync",
                       Times.Once(),
                       ItExpr.Is<HttpRequestMessage>(req =>
                           req.Method == HttpMethod.Get &&
                           req.RequestUri!.ToString().Contains("/products/1")),
                       ItExpr.IsAny<CancellationToken>());
    }
}
```

## Common Follow-up Questions
- What is the difference between `It` and `ItExpr` argument matchers?
- Why does Moq require the method name as a string for protected members?
- How do you verify a protected method was called with specific arguments?
- What alternative exists to avoid mocking protected members?
- How do you test an abstract base class using Moq?
- Can `MockBehavior.Strict` be used with protected member mocking?

## Common Mistakes / Pitfalls
- **Using `It` instead of `ItExpr`** — argument matching silently fails, and the mock doesn't respond as expected.
- **Typo in the method name string** — the string is not compile-time checked; a typo causes runtime `MissingMethodException` or a setup that never matches.
- **Using `.Throws` instead of `.ThrowsAsync` for async protected methods** — exception is not task-wrapped correctly.
- **Forgetting `CallBase = true`** — when testing a base class that has concrete logic calling protected members, `CallBase` must be enabled for the non-mocked parts to run.
- **Over-using protected mocking** — frequent use is a design smell; prefer extracting an interface so tests are type-safe and refactoring-friendly.

## References
- [Moq documentation — Protected members](https://github.com/devlooped/moq/wiki/Quickstart#protected-members)
- [Microsoft Learn — HttpMessageHandler](https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpmessagehandler)
- [Moq GitHub](https://github.com/devlooped/moq)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
