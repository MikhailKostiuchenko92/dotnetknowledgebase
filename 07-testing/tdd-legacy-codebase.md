# How Do You Apply TDD When Working With a Legacy Codebase?

**Category:** Testing / TDD
**Difficulty:** 🔴 Senior
**Tags:** `TDD`, `legacy-code`, `seams`, `refactoring`, `characterization-tests`

## Question
> How do you apply TDD when working with a legacy codebase?

## Short Answer
Start with **characterization tests** to document existing behaviour, then use **seams** (extract interfaces, introduce DI, use virtual methods) to break hidden dependencies so code becomes testable. Apply the "Strangler Fig" pattern to gradually replace untestable legacy code with well-tested new code — never rewrite large chunks at once.

## Detailed Explanation

### The Problem With Legacy Code
Legacy code (defined by Michael Feathers as "code without tests") typically has:
- Static method calls everywhere
- `new` expressions hardcoded inside logic
- `HttpContext.Current`, `DateTime.Now`, `File.ReadAllText` called directly
- 500-line god classes with no seams

You can't write TDD without first making the code testable.

### Step 1: Write Characterization Tests
Before changing anything, capture current behaviour — even if that behaviour has bugs:

```csharp
[Fact]
public void LegacyOrderProcessor_ProcessOrder_CurrentBehaviour()
{
    // Capture existing output WITHOUT asserting it's "correct"
    // This is your baseline — prevents regressions
    var result = new LegacyOrderProcessor().Process(new Order { Total = 99.99m });
    result.Should().Be("PROCESSED:99.99"); // whatever it returns today
}
```

### Step 2: Identify and Create Seams
A **seam** is a place where you can alter behaviour without modifying the code directly.

**Seam types in C#:**

| Seam type | How |
|---|---|
| **Object seam** | Extract interface + inject via constructor |
| **Virtual method seam** | Make method `virtual`, override in test subclass |
| **Link seam** | Separate assembly, replace in test build |
| **Subclass and Override** | Subclass in test, override problematic method |

```csharp
// Before: hardcoded dependency
public class OrderService
{
    public void Process(Order o)
    {
        var repo = new SqlOrderRepository(); // seam needed here
        repo.Save(o);
    }
}

// After: object seam introduced
public class OrderService(IOrderRepository repo)
{
    public void Process(Order o) => repo.Save(o);
}
```

### Step 3: Apply Sprout Method / Sprout Class
When you need new functionality inside legacy code, "sprout" a new method or class with full TDD, then wire it in:

```csharp
// Sprout method — new logic extracted, tested in isolation
public decimal CalculateDiscount(decimal price, string tier)  // new, fully tested
    => tier == "VIP" ? price * 0.2m : 0m;

// Legacy code calls sprout
public void ProcessOrder(Order o)
{
    // ... legacy untestable code ...
    o.Discount = CalculateDiscount(o.Price, o.CustomerTier); // calls the tested sprout
}
```

### Step 4: Strangler Fig Pattern
Gradually replace legacy components with well-tested new implementations. Route new feature requests to the new code; leave old code in place until it's fully replaced.

### Step 5: Break Static Dependencies
```csharp
// Legacy:
var now = DateTime.Now; // untestable

// After extraction:
public class OrderService(TimeProvider tp)
{
    public void Process(Order o) => o.ProcessedAt = tp.GetUtcNow();
}
```

## Code Example
```csharp
// LEGACY: tightly coupled, no seams
public class InvoiceService
{
    public void Generate(int orderId)
    {
        var db = new SqlConnection("server=prod-sql;..."); // real DB!
        var order = db.QueryFirstOrDefault<Order>("SELECT...", orderId);
        var pdf = new PdfGenerator().Create(order);       // real PDF!
        File.WriteAllBytes($"invoices/{orderId}.pdf", pdf); // real file!
    }
}

// STEP 1: Characterization test (just captures current behaviour)
[Fact]
public void Generate_ExistingOrder_CreatesFile()
{
    // skipped in unit tests — runs against real infra, marks as integration
}

// STEP 2: Extract interfaces (seams)
public interface IOrderReader { Order? Read(int id); }
public interface IPdfService { byte[] Create(Order o); }
public interface IFileStorage { void Write(string path, byte[] data); }

// STEP 3: TDD the refactored class
[Fact]
public void Generate_OrderExists_WritesPdf()
{
    var order = new Order { Id = 1, Total = 100m };
    var reader = Mock.Of<IOrderReader>(r => r.Read(1) == order);
    var pdf = Mock.Of<IPdfService>(p => p.Create(order) == new byte[] { 1, 2, 3 });
    var storage = new Mock<IFileStorage>();

    new InvoiceService(reader, pdf, storage.Object).Generate(1);

    storage.Verify(s => s.Write("invoices/1.pdf", new byte[] { 1, 2, 3 }), Times.Once);
}
```

## Common Follow-up Questions
- What is a characterization test and how is it different from a regression test?
- What is the Sprout Method and Sprout Class pattern?
- What is the Strangler Fig pattern and how does it apply to microservices?
- How do you test legacy code that uses static singletons?
- When should you rewrite legacy code instead of refactoring it?

## Common Mistakes / Pitfalls
- **Rewriting the entire legacy module from scratch** — high risk; you likely don't understand all the edge cases.
- **Adding too many seams at once** — introduce one seam per change; keep steps small and verifiable.
- **Not adding characterization tests before refactoring** — without a baseline, regressions are invisible.
- **Using public field injection as a seam** — breaks encapsulation; prefer constructor injection.

## References
- [Michael Feathers — Working Effectively with Legacy Code](https://www.oreilly.com/library/view/working-effectively-with/0131177052/)
- [Martin Fowler — Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Martin Fowler — Characterization Test](https://martinfowler.com/bliki/CharacterizationTest.html)
