# Anemic Domain Model

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `anemic-domain-model`, `DDD`, `anti-pattern`, `rich-domain-model`

## Question
> What is an anemic domain model, and how is it different from a rich domain model in Domain-Driven Design?

## Short Answer
An anemic domain model is a model where domain objects mostly hold data while business rules live in separate services. A rich domain model keeps important invariants and behavior close to the state they protect. Anemic models are not always wrong, but in domains with real business complexity they often lead to service bloat, duplicated rules, and objects that cannot defend their own consistency.

## Detailed Explanation
### What “anemic” means
The term describes objects that look like domain entities but behave like DTOs: lots of properties, little or no business behavior. Validation, calculations, state transitions, and invariants are placed into service classes instead. The result is usually a system where domain objects are easy to construct into invalid states and application services become increasingly procedural.

| Model style | Where behavior lives | Main risk |
| --- | --- | --- |
| Anemic domain model | Services | Rules drift and duplicate |
| Rich domain model | Entities/value objects | More design effort up front |
| Pure CRUD model | Database + handlers | Weak domain language |

Martin Fowler criticized anemic domain models because they pay the cost of object modeling without gaining the main benefit: encapsulated business behavior. If your entities are only bags of getters and setters, they are not really modeling the domain.

### Why teams create anemic models
Many teams start with good intentions: keep entities “simple,” put logic into services, and avoid “fat models.” That can be fine for CRUD-heavy systems where there are few true domain rules. The problem appears when the business gets richer. Now every service must remember the same rules, and no single object can enforce them consistently.

For example, a bank account should not allow withdrawal beyond available funds unless overdraft rules say so. If `BankAccount` exposes mutable properties and the rule is enforced only in `BankAccountService`, some other caller can bypass that service and create invalid state. A rich model puts that rule inside the account itself.

> Warning: not every project needs a rich domain model. If the application is mostly simple data entry and reporting, a heavier domain model may add ceremony without enough return.

### Rich model benefits and trade-offs
A rich domain model improves cohesion because the state and the rules that govern it live together. That makes invariants easier to enforce, tests more focused, and the code more aligned with the business language. It also reduces “service bloat,” where a few application services turn into giant scripts manipulating passive objects.

The trade-off is that richer models require better boundaries and more thought. You need to distinguish real domain behavior from application orchestration. Sending email, saving to a repository, and starting a transaction are not usually entity responsibilities. Calculating domain state transitions often are.

### A practical DDD perspective
DDD does not say “everything must be rich.” It says model the parts of the system where domain complexity matters. Use rich entities and value objects where invariants are important. Use simpler data carriers where they are enough. The balanced interview answer is that an anemic domain model becomes a smell when important rules live everywhere except the domain objects that should own them.

## Code Example
```csharp
using System;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        var richAccount = new BankAccount("ACC-1001", 100m);
        richAccount.Deposit(25m);
        richAccount.Withdraw(50m);

        Console.WriteLine($"Balance: {richAccount.Balance:C}");
    }
}

internal sealed class BankAccount
{
    public BankAccount(string number, decimal openingBalance)
    {
        if (openingBalance < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(openingBalance));
        }

        Number = number;
        Balance = openingBalance;
    }

    public string Number { get; }
    public decimal Balance { get; private set; }

    public void Deposit(decimal amount)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount));
        }

        Balance += amount; // The entity protects its own invariant.
    }

    public void Withdraw(decimal amount)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount));
        }

        if (Balance < amount)
        {
            throw new InvalidOperationException("Insufficient funds.");
        }

        Balance -= amount;
    }
}
```

## Common Follow-up Questions
- When is an anemic domain model acceptable in a real project?
- How do you distinguish domain behavior from application-service orchestration?
- What kinds of rules belong inside entities or value objects?
- Why can an anemic model lead to service bloat?
- How does this topic relate to DDD aggregates and invariants?

## Common Mistakes / Pitfalls
- Assuming every class with properties is automatically a valid domain model.
- Putting all logic into services and leaving entities unable to protect their own invariants.
- Swinging too far the other way and making entities responsible for persistence, email, or logging.
- Forcing a rich model onto a simple CRUD problem that does not need it.
- Exposing public setters that let callers bypass business rules.

## References
- [AnemicDomainModel](https://martinfowler.com/bliki/AnemicDomainModel.html)
- [Domain model](https://martinfowler.com/eaaCatalog/domainModel.html)
- [Design a DDD-oriented microservice](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
