# What is Shotgun Surgery?

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `shotgun-surgery`, `code-smell`, `SRP`, `refactoring`

## Question
> What is shotgun surgery in code, why does it usually indicate an SRP problem, and how would you fix it?

## Short Answer
Shotgun surgery is a code smell where one small requirement change forces edits in many scattered places. It usually means behavior that should live in one module is duplicated across layers or split across the wrong abstractions, which is often a Single Responsibility Principle problem. The fix is to identify the changing concept and centralize it behind one cohesive policy, type, or boundary.

## Detailed Explanation
### What it is
Shotgun surgery happens when a single change request causes a lot of small edits across unrelated files. For example, changing a discount rule might require updates in an API controller, an application service, a report formatter, and an export job. None of those changes are hard individually, but together they make the system fragile.

The smell matters because change is the real unit of design quality. If one business rule is scattered everywhere, the codebase is telling you that the rule has no proper home.

| Symptom | Likely underlying issue |
| --- | --- |
| Same rule updated in many classes | Logic is duplicated or misplaced |
| Small requirement triggers broad retesting | Boundaries do not isolate change |
| Easy to miss one edit | Knowledge is scattered across layers |
| Frequent regression after business changes | No single source of truth |

### Why it often points to SRP problems
SRP is about having one reason to change. If a pricing rule affects controllers, repositories, email templates, and scheduled jobs directly, those components now all change for the same business reason. That means responsibilities are not well separated.

A common cause is mixing business policy with delivery concerns. Controllers should handle HTTP, repositories should handle persistence, and notification services should send notifications. If each of them also knows how to calculate discounts or determine customer priority, the design invites shotgun surgery.

> Warning: teams often respond by "being careful" during releases, but careful people cannot compensate forever for a design where the same rule lives in five places.

### Real-world impact
The biggest danger is incomplete change. A developer updates three places and forgets the fourth, so the UI shows one price while an export file or invoice shows another. These are exactly the kinds of bugs that pass compilation and sometimes even basic tests.

Shotgun surgery also increases coordination cost. Multiple teams may own different parts of the codebase, so a simple business change turns into a cross-team delivery problem. That slows down releases and makes the system resistant to change.

### How to fix it
Start by asking: **what concept is changing together?** That might be a pricing policy, a validation rule, a state transition, or a formatting rule. Then centralize that behavior into one cohesive component.

Typical fixes include:

- Extracting a domain service or policy object.
- Moving duplicated logic into an entity or value object.
- Introducing a shared formatter or mapper when representation rules are duplicated.
- Reorganizing modules so the rule has one clear owner.

The goal is not to eliminate all collaboration. The goal is to make each business rule editable in one place.

### Trade-offs
Do not overreact by creating a giant shared helper full of unrelated rules. That just turns shotgun surgery into a God class. Centralize by business concept, not by convenience. In interviews, the strongest answer connects the smell directly to scattered responsibility and then explains how a single source of truth reduces regression risk.

## Code Example
```csharp
namespace InterviewKnowledgeBase.Examples;

internal static class Program
{
    private static void Main()
    {
        var customer = new Customer("Ada", isPremium: true, orderTotal: 1_000m);

        Console.WriteLine(BadCheckoutController.GetDiscount(customer));
        Console.WriteLine(BadInvoiceService.GetDiscount(customer));

        var policy = new DiscountPolicy();
        Console.WriteLine(GoodCheckoutController.GetDiscount(customer, policy));
        Console.WriteLine(GoodInvoiceService.GetDiscount(customer, policy));
    }
}

internal sealed record Customer(string Name, bool IsPremium, decimal OrderTotal);

internal static class BadCheckoutController
{
    public static decimal GetDiscount(Customer customer)
    {
        // Bad: business rule duplicated in the API layer.
        return customer.IsPremium && customer.OrderTotal >= 500m ? 0.15m : 0.05m;
    }
}

internal static class BadInvoiceService
{
    public static decimal GetDiscount(Customer customer)
    {
        // Bad: same rule duplicated in another layer.
        return customer.IsPremium && customer.OrderTotal >= 500m ? 0.15m : 0.05m;
    }
}

internal sealed class DiscountPolicy
{
    public decimal Calculate(Customer customer)
    {
        // Good: one source of truth for the changing rule.
        return customer.IsPremium && customer.OrderTotal >= 500m ? 0.15m : 0.05m;
    }
}

internal static class GoodCheckoutController
{
    public static decimal GetDiscount(Customer customer, DiscountPolicy policy) => policy.Calculate(customer);
}

internal static class GoodInvoiceService
{
    public static decimal GetDiscount(Customer customer, DiscountPolicy policy) => policy.Calculate(customer);
}
```

## Common Follow-up Questions
- How is shotgun surgery different from duplicated code?
- Why is this smell often related to the Single Responsibility Principle?
- Which refactorings are most useful when the same rule is scattered across layers?
- How can tests help detect and prevent shotgun-surgery regressions?
- What is the difference between shotgun surgery and divergent change?

## Common Mistakes / Pitfalls
- Centralizing all unrelated logic into one helper class and creating a new God class.
- Fixing only one duplicated instance of a rule and leaving other copies behind.
- Assuming the smell is about file count only instead of looking at change coupling.
- Putting business policy into controllers or repositories because it is "easy for now."
- Ignoring representation duplication in exports, reports, and background jobs.

## References
- [Shotgun Surgery](https://refactoring.guru/smells/shotgun-surgery)
- [Large Class](https://refactoring.guru/smells/large-class)
- [Moving Features Between Objects](https://refactoring.guru/refactoring/techniques/moving-features-between-objects)
- [Common Web Application Architectures](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
