# What Are the Limitations of Moq?

**Category:** Testing / Mocking
**Difficulty:** 🔴 Senior
**Tags:** `moq`, `limitations`, `non-virtual`, `sealed`, `static`, `extension-methods`

## Question
> What are the limitations of Moq?

## Short Answer
Moq uses Castle DynamicProxy to generate subclasses at runtime, so it can only intercept `virtual` or `abstract` instance members on non-sealed, non-static classes and interfaces. It cannot mock static members, non-virtual methods, sealed classes, extension methods, or structs. For those scenarios, the solution is refactoring (extract interface, use wrapper/adapter) or switching to Fakes / Microsoft Fakes / `NSubstitute` (which has the same underlying limitations).

## Detailed Explanation

### How Moq Works (and Why It Has Limits)
Moq generates a proxy class that inherits from `T` (for classes) or implements `T` (for interfaces). Only members that can be overridden — `virtual`, `abstract`, and interface members — can be intercepted. Anything else is a compile-time resolution.

### Limitation 1: Non-Virtual / Non-Abstract Methods
```csharp
public class CacheService
{
    public string Get(string key) { ... } // NOT virtual
}

var mock = new Mock<CacheService>();
mock.Setup(c => c.Get("k")).Returns("v"); // ❌ Throws at setup time
```
**Fix:** Add `virtual` keyword, or extract `ICacheService` interface.

### Limitation 2: Sealed Classes
```csharp
public sealed class EmailService { }

var mock = new Mock<EmailService>(); // ❌ Cannot create proxy of sealed class
```
**Fix:** Extract interface, use adapter/wrapper pattern.

### Limitation 3: Static Methods and Properties
Moq cannot mock `static` members at all (no proxy subclass can override statics).
```csharp
mock.Setup(x => DateTime.UtcNow); // ❌ Not possible
mock.Setup(x => File.Exists(It.IsAny<string>())); // ❌ Not possible
```
**Fix:** Wrap in a virtual method or interface (`ISystemClock`, `IFileSystem`).

### Limitation 4: Extension Methods
Extension methods are static and resolved at compile time; they cannot be intercepted.
```csharp
// Cannot mock: string.IsNullOrEmpty(), LINQ operators, custom extension methods
```
**Fix:** Test through the interface, not the extension method.

### Limitation 5: Structs
Structs are value types; DynamicProxy cannot create a subclass of a struct.
```csharp
var mock = new Mock<MyStruct>(); // ❌ Cannot proxy value types
```

### Limitation 6: Internal Interfaces (Without `InternalsVisibleTo`)
```csharp
internal interface IInternalService { }
var mock = new Mock<IInternalService>(); // ❌ Proxy can't access internal type from another assembly
```
**Fix:** Add `[assembly: InternalsVisibleTo("DynamicProxyGenAssembly2")]` to the production assembly.

### Limitation 7: Generic Method Return Type Inference
Moq requires explicit type parameters in some lambda setups; inference sometimes fails.

### Limitation 8: `ref` / `out` Parameters (Partially Supported)
`out` parameters are supported with `It.IsAny<T>()` and `callback`; `ref` has limited support.

### Summary Table

| Scenario | Moq Can Mock? | Workaround |
|---|---|---|
| Interface | ✅ Yes | — |
| Abstract class | ✅ Yes | — |
| Class with `virtual` method | ✅ Yes | — |
| Sealed class | ❌ No | Extract interface / adapter |
| Non-virtual method | ❌ No | Make `virtual` or extract interface |
| Static method/property | ❌ No | Wrap in virtual/interface |
| Extension method | ❌ No | Test via interface |
| Struct | ❌ No | Redesign (use interface or class) |
| `protected virtual` | ✅ (via `.Protected()`) | — |
| `internal interface` | ⚠️ Requires `InternalsVisibleTo` | Add assembly attribute |

> 💡 **Moq vs. Microsoft Fakes:** Microsoft Fakes (Visual Studio Enterprise only) can mock non-virtual and static members via IL rewriting. Use it sparingly — it often indicates a design problem that should be fixed instead.

## Code Example
```csharp
namespace Limitations.Tests;

// ❌ Problem: non-virtual method
public class InventoryRepository
{
    public int GetStock(int productId) { /* DB call */ return 0; }
}

// ✅ Fix: extract interface
public interface IInventoryRepository
{
    int GetStock(int productId);
}

public class InventoryService
{
    private readonly IInventoryRepository _repo;
    public InventoryService(IInventoryRepository repo) => _repo = repo;

    public bool IsAvailable(int productId, int qty) =>
        _repo.GetStock(productId) >= qty;
}

public class InventoryServiceTests
{
    [Fact]
    public void IsAvailable_ReturnsFalse_WhenStockInsufficient()
    {
        var repo = new Mock<IInventoryRepository>();
        repo.Setup(r => r.GetStock(1)).Returns(3);

        var sut = new InventoryService(repo.Object);

        sut.IsAvailable(1, 5).Should().BeFalse();
    }
}

// ❌ Problem: sealed class
public sealed class SmtpEmailSender
{
    public void Send(string to, string body) { /* real SMTP */ }
}

// ✅ Fix: interface + wrapper
public interface IEmailSender
{
    void Send(string to, string body);
}

public class SmtpEmailSenderAdapter : IEmailSender
{
    private readonly SmtpEmailSender _inner = new();
    public void Send(string to, string body) => _inner.Send(to, body);
}
```

## Common Follow-up Questions
- How does Moq generate mocks under the hood?
- What is Castle DynamicProxy and what are its constraints?
- What alternatives exist when Moq cannot mock a dependency?
- How does `Microsoft.Fakes` differ from Moq?
- What design principles help avoid untestable code (sealed, static)?
- How do you handle `DateTime.UtcNow` in tests?

## Common Mistakes / Pitfalls
- **Trying to mock a sealed/non-virtual member and getting a runtime exception** — Moq throws at setup time, not at the mock call, so the error appears in Arrange.
- **Assuming NSubstitute solves these problems** — NSubstitute uses the same DynamicProxy under the hood and has identical constraints.
- **Using Microsoft Fakes to paper over design issues** — Fakes enables mocking statics/sealed types but encourages bad design. Prefer refactoring.
- **Forgetting `InternalsVisibleTo`** — missing the `"DynamicProxyGenAssembly2"` entry causes mysterious proxy creation failures for internal interfaces.
- **Marking everything `virtual` just to enable mocking** — this is acceptable but should prompt a review of whether an interface would be cleaner.

## References
- [Moq documentation — Limitations](https://github.com/devlooped/moq/wiki/Quickstart)
- [Castle DynamicProxy](http://www.castleproject.org/projects/dynamicproxy/)
- [Microsoft Fakes overview](https://learn.microsoft.com/en-us/visualstudio/test/isolating-code-under-test-with-microsoft-fakes)
- [InternalsVisibleTo for Moq](https://stackoverflow.com/questions/33695613/moq-mock-internal-interface)
- [NSubstitute limitations](https://nsubstitute.github.io/help/creating-a-substitute/) (verify URL)
