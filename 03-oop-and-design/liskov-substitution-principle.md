# Liskov Substitution Principle (LSP)

**Category:** OOP & Design / SOLID
**Difficulty:** 🟡 Middle
**Tags:** `LSP`, `SOLID`, `subtyping`, `polymorphism`

## Question
> What is the Liskov Substitution Principle, and what rules help you detect an LSP violation in C#?

## Short Answer
The Liskov Substitution Principle says that code using a base type should work correctly when given any subtype. A subtype must preserve the behavioral expectations of the base contract, not just compile against the same members. In practice, LSP violations show up when derived classes throw `NotSupportedException`, strengthen preconditions, weaken postconditions, or break invariants that callers rely on.

## Detailed Explanation
### What LSP really means
LSP is about behavioural substitutability. If a method accepts a base type or interface, callers should not need special-case knowledge about which subtype they received. The subtype must honor the same contract: the same semantic meaning, compatible input expectations, and compatible output guarantees.

That is why LSP is deeper than “inheritance works.” A subclass can satisfy the compiler and still violate the design contract. In interviews, this is an important distinction: polymorphism is only useful when substituted objects remain trustworthy.

### The contract rules interviewers expect
A practical way to explain LSP is with contract rules:

| Contract rule | What a subtype may do | What breaks LSP |
| --- | --- | --- |
| Preconditions | Keep same or weaker | Require more than the base type required |
| Postconditions | Keep same or stronger | Guarantee less than the base type promised |
| Invariants | Preserve object rules | Break assumptions the base type maintained |
| Exceptions/behavior | Stay compatible | Throw for scenarios callers were told are valid |

If a base contract says `Withdraw` works for valid accounts with enough funds, a subtype should not suddenly reject all withdrawals just because it is a special account type. That means the inheritance hierarchy is modeling the domain incorrectly.

### Common C# examples of LSP violations
The classic `Rectangle`/`Square` example is useful academically, but in real C# systems LSP violations usually appear as:
- derived classes that throw `NotSupportedException`
- fake implementations created only to satisfy an interface
- subclasses that silently change side effects, timing, or validation rules
- subclasses that return `null` or partial data where the base contract promised something usable

A common banking example is `BankAccount` with `Withdraw`, then a `FixedTermDepositAccount` subclass that cannot be withdrawn from and throws. That is not just an awkward implementation; it means “fixed-term deposit” is not a substitutable bank account for callers that expect withdrawal behavior.

> Warning: if you often need `if (x is SpecialSubtype)` checks after polymorphic calls, your hierarchy may already be violating LSP.

### How to fix LSP problems
The usual fix is not “override better.” It is to redesign the abstraction. Split contracts so types implement only behaviors they can truly honor. Instead of one broad `BankAccount` abstraction, define smaller abstractions such as `IAccountBalance` and `IWithdrawableAccount`. Then only withdrawable accounts implement the withdrawal contract.

This is why LSP often overlaps with ISP and composition. Better contracts produce safer substitution.

### Why LSP matters and its trade-offs
LSP protects trust in abstractions. It lets service code depend on a type without defensive branching. That improves extensibility, reduces bugs, and makes tests more meaningful.

The trade-off is design effort. You have to think about behavior, not just member names. Some teams overuse inheritance because it looks DRY, then discover that behavioral differences are larger than structural similarities. In modern C#, composition and narrow interfaces are often safer than deep inheritance.

### When not to use inheritance
If two types share data shape but not behavior, inheritance is a poor fit. Prefer composition, separate role interfaces, or separate strategies. A strong interview answer explains that LSP is about preserving expectations for callers, not about maximizing reuse through subclassing.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.LspSample;

// Before: FixedTermDepositAccount : BankAccount overrides Withdraw and throws.
// After: only truly withdrawable accounts implement IWithdrawableAccount.

public interface IAccountBalance
{
    decimal Balance { get; }
}

public interface IWithdrawableAccount : IAccountBalance
{
    void Withdraw(decimal amount);
}

public sealed class CheckingAccount(decimal initialBalance) : IWithdrawableAccount
{
    public decimal Balance { get; private set; } = initialBalance;

    public void Withdraw(decimal amount)
    {
        if (amount <= 0 || amount > Balance)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be positive and within the balance.");
        }

        Balance -= amount;
    }
}

public sealed class FixedTermDepositAccount(decimal initialBalance) : IAccountBalance
{
    public decimal Balance { get; } = initialBalance;

    public DateOnly MaturesOn { get; } = DateOnly.FromDateTime(DateTime.Today.AddMonths(6));
}

public static class AccountOperations
{
    public static void WithdrawMonthlyFee(IEnumerable<IWithdrawableAccount> accounts, decimal fee)
    {
        foreach (var account in accounts)
        {
            account.Withdraw(fee); // Safe because the contract matches the capability.
        }
    }
}

public static class Program
{
    public static void Main()
    {
        var checking = new CheckingAccount(100m);
        AccountOperations.WithdrawMonthlyFee([checking], 10m);

        Console.WriteLine($"Checking balance: {checking.Balance}");
        Console.WriteLine($"Fixed deposit balance: {new FixedTermDepositAccount(500m).Balance}");
    }
}
```

## Common Follow-up Questions
- How is LSP different from simple polymorphism?
- Why is `NotSupportedException` often a code smell in an override?
- How do preconditions and postconditions relate to LSP?
- What is a better real-world example than `Rectangle` and `Square`?
- How does LSP influence interface design?

## Common Mistakes / Pitfalls
- Thinking shared method names are enough for safe substitution.
- Using inheritance to reuse code when the subtype cannot fully honor the base contract.
- Strengthening validation rules in a subtype and surprising callers.
- Weakening guarantees, such as returning partial or nullable data where the base promised more.
- Catching LSP problems late because unit tests only cover the base type, not real subtypes.

## References
- [Polymorphism in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism)
- [Inheritance in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance)
- [Interfaces in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)
- [Refused Bequest code smell](https://refactoring.guru/smells/refused-bequest)
