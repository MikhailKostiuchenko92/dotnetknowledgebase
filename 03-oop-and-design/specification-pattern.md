# Specification Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🔴 Senior
**Tags:** `specification`, `behavioral`, `EF-Core`, `Ardalis`

## Question
> What is the Specification pattern, how do composite specifications work, and how does it integrate with EF Core and libraries like Ardalis.Specification?

## Short Answer
The Specification pattern packages a business rule or query rule into a reusable object, usually behind something like `ISpecification<T>`. Instead of scattering predicates across repositories and services, you compose specifications such as “active customers” and “premium customers” into richer rules. In .NET, the pattern is especially useful with EF Core when specifications expose expression trees, because those expressions can be translated into SQL rather than forcing in-memory filtering.

## Detailed Explanation
### What the pattern is solving
In many codebases, querying and business predicates get duplicated everywhere: repository methods, LINQ calls, controller filters, authorization checks, and report builders. The Specification pattern extracts those rules into named, reusable objects.

A specification usually answers one of two needs:

- **Validation/business rule**: “Is this order eligible for shipping?”
- **Query definition**: “Which customers are active and in a premium tier?”

That naming alone improves readability because `customer.IsSatisfiedBy(activePremiumSpec)` says more than repeating a complex predicate inline.

### How composite specifications work
Specifications become more powerful when they are composable. A common design supports logical combinators such as `And`, `Or`, and `Not`.

| Specification | Meaning |
| --- | --- |
| `IsActiveCustomer` | Customer is enabled and not deleted |
| `IsPremiumCustomer` | Spending or tier threshold is met |
| `IsActiveCustomer.And(IsPremiumCustomer)` | Both conditions must be true |

This composition is one reason the pattern is popular in domain-driven designs: you can model business intent instead of repeating raw boolean logic.

### Why EF Core integration matters
If a specification exposes `Func<T, bool>`, it works only in memory. For EF Core, that is often the wrong abstraction because the database provider cannot translate compiled delegates into SQL. The common approach is to expose `Expression<Func<T, bool>>` so EF Core can inspect the expression tree and translate it.

That is the key “how” detail interviewers want:

| Representation | EF Core translation? |
| --- | --- |
| `Func<T, bool>` | No, usually client-side only |
| `Expression<Func<T, bool>>` | Yes, provider can translate |

> If your specification compiles expressions too early, you can accidentally pull large tables into memory and filter on the application side. That is one of the most common real-world mistakes.

### Ardalis.Specification and practical usage
Ardalis.Specification is a popular .NET library that packages this idea with richer query concerns: criteria, includes, ordering, paging, and projection. That is important because real repositories rarely need only a `Where` clause. They also need eager loading, sorting, pagination, and sometimes post-processing.

The trade-off is abstraction weight. If your app has only a handful of simple queries, a full specification library may be unnecessary. But in larger systems, it can prevent repository-method explosion such as `GetActiveCustomersByRegionWithOrdersPaged...`.

### When to use it and when not to
Use Specification when predicates are reused, business-named, and composable, especially across domain and data-access boundaries. Avoid it when each query is unique and one-off, or when the abstraction starts hiding too much of the generated query behavior from developers.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;

namespace OopAndDesign.SpecificationPattern;

public sealed record Customer(string Name, bool IsActive, decimal TotalSpent);

public interface ISpecification<T>
{
    Expression<Func<T, bool>> Criteria { get; }
    bool IsSatisfiedBy(T candidate) => Criteria.Compile()(candidate);
}

public abstract class Specification<T> : ISpecification<T>
{
    public abstract Expression<Func<T, bool>> Criteria { get; }

    public Specification<T> And(Specification<T> other) => new AndSpecification<T>(this, other);
}

public sealed class ActiveCustomerSpecification : Specification<Customer>
{
    public override Expression<Func<Customer, bool>> Criteria => customer => customer.IsActive;
}

public sealed class PremiumCustomerSpecification(decimal threshold) : Specification<Customer>
{
    public override Expression<Func<Customer, bool>> Criteria => customer => customer.TotalSpent >= threshold;
}

public sealed class AndSpecification<T>(Specification<T> left, Specification<T> right) : Specification<T>
{
    public override Expression<Func<T, bool>> Criteria
    {
        get
        {
            var parameter = Expression.Parameter(typeof(T), "item");
            var leftBody = new ReplaceParameterVisitor(left.Criteria.Parameters[0], parameter).Visit(left.Criteria.Body)!;
            var rightBody = new ReplaceParameterVisitor(right.Criteria.Parameters[0], parameter).Visit(right.Criteria.Body)!;
            return Expression.Lambda<Func<T, bool>>(Expression.AndAlso(leftBody, rightBody), parameter);
        }
    }
}

public sealed class ReplaceParameterVisitor(ParameterExpression source, ParameterExpression target) : ExpressionVisitor
{
    protected override Expression VisitParameter(ParameterExpression node) => node == source ? target : base.VisitParameter(node);
}

public static class Program
{
    public static void Main()
    {
        var customers = new List<Customer>
        {
            new("Ada", true, 1200),
            new("Bob", false, 3000),
            new("Sara", true, 400)
        };

        var specification = new ActiveCustomerSpecification().And(new PremiumCustomerSpecification(1000));
        var result = customers.Where(specification.Criteria.Compile()); // In EF Core, pass the expression tree directly.

        foreach (var customer in result)
        {
            Console.WriteLine(customer.Name);
        }
    }
}
```

## Common Follow-up Questions
- Why should EF Core-facing specifications expose `Expression<Func<T, bool>>` instead of `Func<T, bool>`?
- When does the pattern improve readability, and when does it become unnecessary abstraction?
- How would you compose `And`, `Or`, and `Not` specifications safely?
- What extra query concerns does Ardalis.Specification handle beyond filtering?
- How does the pattern differ for domain validation versus repository querying?
- What risks exist if specifications hide generated SQL complexity?

## Common Mistakes / Pitfalls
- Compiling the expression too early and forcing client-side evaluation.
- Creating a huge library of one-off specifications that are never reused.
- Mixing domain business rules and persistence-specific includes in one incoherent abstraction.
- Assuming the pattern automatically makes repositories cleaner without measuring actual complexity.
- Forgetting that poorly composed expression trees can become hard to debug.

## References
- [Specification Pattern](https://deviq.com/design-patterns/specification-pattern)
- [EF Core querying](https://learn.microsoft.com/ef/core/querying/)
- [Ardalis.Specification documentation](https://specification.ardalis.com/)
- [Ardalis.Specification repository](https://github.com/ardalis/Specification)
