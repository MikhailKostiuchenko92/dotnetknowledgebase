# Interface Segregation Principle (ISP)

**Category:** OOP & Design / SOLID
**Difficulty:** 🟡 Middle
**Tags:** `ISP`, `SOLID`, `interfaces`, `role-interfaces`

## Question
> What is the Interface Segregation Principle, and how do you avoid fat interfaces in C#?

## Short Answer
The Interface Segregation Principle says clients should not be forced to depend on methods they do not use. Instead of one broad interface that mixes unrelated capabilities, you should model smaller role-based interfaces that match real client needs. In C#, that reduces dummy implementations, `NotSupportedException`, and ripple effects when one capability changes.

## Detailed Explanation
### What ISP means
ISP is the interface version of keeping responsibilities focused. A large interface often looks convenient at first because there is “one place for everything.” But that convenience usually shifts complexity to consumers and implementers. If a class needs only two members but the interface exposes ten, the class is now coupled to unrelated behavior and future changes it does not care about.

That is the heart of ISP: depend on the smallest contract that expresses what the client actually needs.

### The fat interface smell
A fat interface typically grows over time as multiple teams add “just one more method.” In C# codebases, examples include service interfaces with create/read/update/export/email/import/report members all mixed together, or infrastructure interfaces that handle logging, caching, retries, and health checks in one contract.

| Smell | Result |
| --- | --- |
| One interface serves many unrelated callers | High coupling between clients |
| Implementers stub unused members | Dummy code or runtime exceptions |
| Small change in one member | Forces rebuilds and retesting for many clients |
| Names become vague (`IManager`, `IProcessor`) | Intent becomes unclear |

### Role interfaces are the usual fix
The standard refactoring is to split a broad contract into role interfaces. A payroll service might need `IPayrollCalculator`, while a reporting page needs `IEmployeeReportSource`, and an approval workflow needs `IBudgetApprover`. Those are not arbitrary slices; they mirror actual usage roles.

This matters because interfaces should express capabilities, not organizational convenience. When interfaces line up with client needs, dependencies become explicit and substitution becomes safer.

> Warning: ISP does **not** mean every interface must have one method. The goal is focused contracts, not maximal fragmentation.

### How ISP affects design and testing
Smaller interfaces improve testability because fakes become simpler and mocks need fewer setups. They also support clearer dependency injection. When a class asks for `IReadOnlyRepository<T>` instead of a giant repository interface with write methods, its intent is obvious and the API boundary is safer.

ISP also reduces accidental violations of LSP. If you force a class to implement members it cannot truly support, you often end up throwing `NotSupportedException`, which usually means the abstraction is wrong.

### Trade-offs and when not to over-segregate
Over-segregation can make a design noisy, especially if you create many tiny interfaces with unclear distinction. If the same clients almost always use the same group of members together, splitting them may add ceremony without benefit. The best guideline is client-based: separate interfaces when different consumers need different slices of behavior.

In interviews, a strong answer mentions “fat interface smell,” “role interfaces,” and “clients should not depend on methods they do not use.” It is also good to connect ISP with better DI, easier testing, and fewer dummy implementations.

## Code Example
```csharp
using System;

namespace OopAndDesign.IspSample;

// Before: one IEmployeeOperations interface with Work, RunPayroll, ExportReport, ApproveBudget.
// After: each client depends only on the role it needs.

public interface ITimeEntryWriter
{
    void WriteHours(string employeeName, int hours);
}

public interface IPayrollCalculator
{
    decimal CalculateMonthlyPay(string employeeName);
}

public sealed class EmployeeBackOffice : ITimeEntryWriter, IPayrollCalculator
{
    public void WriteHours(string employeeName, int hours)
    {
        Console.WriteLine($"Recorded {hours} hours for {employeeName}.");
    }

    public decimal CalculateMonthlyPay(string employeeName)
    {
        return employeeName.Length * 1000m; // Demo logic for a runnable sample.
    }
}

public sealed class TimesheetController(ITimeEntryWriter timeEntryWriter)
{
    public void Submit()
    {
        timeEntryWriter.WriteHours("Mikhail", 8); // Depends only on time entry behavior.
    }
}

public static class Program
{
    public static void Main()
    {
        var backOffice = new EmployeeBackOffice();
        var controller = new TimesheetController(backOffice);

        controller.Submit();
        Console.WriteLine($"Monthly pay: {backOffice.CalculateMonthlyPay("Mikhail"):C}");
    }
}
```

## Common Follow-up Questions
- How do you decide where to split an interface?
- How is ISP related to SRP and LSP?
- Is one-method-per-interface a good rule?
- What are role interfaces, and why are they useful?
- How does ISP improve unit testing?

## Common Mistakes / Pitfalls
- Splitting interfaces mechanically instead of based on client usage.
- Keeping a giant “manager” interface and hiding the problem behind mocks.
- Forcing implementations to throw `NotSupportedException` for unsupported members.
- Creating too many tiny interfaces with no clear domain meaning.
- Injecting write-capable services into read-only consumers and expanding the blast radius of changes.

## References
- [Interfaces in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)
- [Object-oriented programming fundamentals in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)
- [Large Class code smell](https://refactoring.guru/smells/large-class)
- [Refused Bequest code smell](https://refactoring.guru/smells/refused-bequest)
