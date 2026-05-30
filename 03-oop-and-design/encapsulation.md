# Encapsulation in C#

**Category:** OOP & Design
**Difficulty:** 🟢 Junior
**Tags:** `encapsulation`, `access-modifiers`, `properties`

## Question
> What is encapsulation in C#, and how do access modifiers, properties, and methods help implement it?

## Short Answer
Encapsulation means an object controls its own state instead of letting any caller change its internals freely. In C#, you usually achieve that with access modifiers, properties, and behavior-focused methods that validate changes. Good encapsulation exposes useful operations like `Deposit` or `Rename`, not raw fields that let outside code break invariants.

## Detailed Explanation
### Encapsulation is about control, not secrecy
A common beginner definition is “encapsulation means making fields private.” That is only part of the story. The deeper idea is information hiding: an object should decide how its data is read and changed so it can stay valid.

For example, a bank account should not allow a negative deposit or a balance to be assigned arbitrarily. If outside code can directly set `Balance`, the class cannot enforce its business rules. Encapsulation moves those rules into the class itself.

### Access modifiers are the first line of defense
C# gives you `private`, `protected`, `internal`, `protected internal`, `private protected`, and `public`. These modifiers define who can access a member. In encapsulation, they are used to narrow the surface area of a type.

| Technique | What it does | Typical use |
| --- | --- | --- |
| `private` field | Hides raw state | Internal implementation details |
| Property with private setter | Allows reads but restricts writes | Controlled state exposure |
| Method | Encodes valid operations | Business actions with validation |
| `internal` member | Shares within assembly only | Library internals |

Access modifiers alone do not create a good design, but they make it possible. If everything is public, the object has almost no control over its own correctness.

### Expose behavior, not just state
Strong encapsulation usually means callers ask an object to do something instead of telling it exactly how to change itself. That is why APIs such as `AddItem`, `Deactivate`, or `Approve` are often better than exposing mutable collections or unrestricted setters.

This approach keeps rules centralized. If a class must log changes, validate values, raise domain events, or update related fields, a method can do all of that in one place. If callers set fields directly, those rules get duplicated or skipped.

> Warning: replacing a public field with a public auto-property is not automatically good encapsulation. If the setter is unrestricted, external code can still put the object into an invalid state.

### Property vs field in real code
Fields are usually implementation details. Properties are the public contract for values because they can add validation, lazy loading, computed values, notifications, or restricted setters without changing the calling syntax much.

| Public field | Property |
| --- | --- |
| No validation hook | Can validate in `set` or constructor |
| Harder to version later | Easier to evolve without breaking callers |
| Exposes storage directly | Exposes a contract, not storage |
| Rarely recommended in domain models | Preferred for public APIs |

That does not mean every property should have complicated logic. Many properties are simple and that is fine. The important part is that the type retains the option to enforce rules.

### Why encapsulation improves maintainability
Encapsulation reduces coupling. Callers depend on what the object can do, not on how it stores data internally. That makes refactoring safer. You can change a field to a computed property, add validation, or change internal storage structures without forcing all callers to rewrite their code.

It also improves testability and debugging. When every state change goes through a small number of methods, bugs are easier to trace. In poorly encapsulated code, state can be mutated from many places with no single source of truth.

### Trade-offs and when to avoid overengineering
Encapsulation should not become ceremony. For simple immutable data carriers, a record or init-only properties may be enough. The right level depends on how many invariants the type must protect and how much behavior belongs with the data.

The key interview point is this: encapsulation is not just hiding fields. It is designing a type so that legal usage is easy and illegal usage is hard.

## Code Example
```csharp
namespace OopAndDesignExamples;

public sealed class BadBankAccount
{
    public decimal Balance; // Before: any caller can assign any value.
}

public sealed class BankAccount
{
    private decimal _balance;

    public BankAccount(string owner)
    {
        Owner = string.IsNullOrWhiteSpace(owner)
            ? throw new ArgumentException("Owner is required.", nameof(owner))
            : owner;
    }

    public string Owner { get; }
    public decimal Balance => _balance; // After: read-only from the outside.

    public void Deposit(decimal amount)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Deposit must be positive.");
        }

        _balance += amount;
    }

    public void Withdraw(decimal amount)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Withdrawal must be positive.");
        }

        if (amount > _balance)
        {
            throw new InvalidOperationException("Insufficient funds.");
        }

        _balance -= amount;
    }
}

public static class Program
{
    public static void Main()
    {
        var bad = new BadBankAccount { Balance = -500m }; // Invalid state is possible.
        Console.WriteLine($"Bad balance: {bad.Balance}");

        var good = new BankAccount("Mila");
        good.Deposit(200m);
        good.Withdraw(50m);

        Console.WriteLine($"{good.Owner} balance: {good.Balance}");
    }
}
```

## Common Follow-up Questions
- What is the difference between encapsulation and abstraction?
- Why are properties usually preferred over public fields in C#?
- When would you use a private setter versus an init-only property?
- Can exposing a mutable collection break encapsulation?
- How do access modifiers help enforce invariants?

## Common Mistakes / Pitfalls
- Using public fields in domain objects and losing all validation points.
- Exposing `List<T>` directly and allowing callers to mutate internal state unexpectedly.
- Adding public setters everywhere “for convenience,” then struggling to track invalid state.
- Putting validation in UI or service code instead of the object that owns the data.
- Assuming encapsulation is unnecessary for internal code because “the team knows how to use it.”

## References
- [Object-oriented programming fundamentals (C#)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)
- [Access Modifiers (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/access-modifiers)
- [Properties (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/properties)
- [Choosing Between Class and Struct (Framework Design Guidelines)](https://learn.microsoft.com/en-us/dotnet/standard/design-guidelines/choosing-between-class-and-struct)
