# Why is Service Locator considered an anti-pattern?

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `service-locator`, `anti-pattern`, `DI`, `hidden-dependencies`

## Question
> Why is the Service Locator pattern usually considered an anti-pattern compared to dependency injection?

## Short Answer
Service Locator hides a class's real dependencies behind a global lookup, so the constructor no longer tells you what the class needs to run. That makes code harder to understand, easier to break at runtime, and more awkward to test. Constructor injection is usually preferred because dependencies are explicit, validated earlier, and easier to replace in tests.

## Detailed Explanation
### What Service Locator is
A Service Locator is an object, often static or globally reachable, that resolves dependencies on demand. Instead of receiving collaborators through the constructor, a class calls something like `Locator.Get<IEmailSender>()` when it needs one.

At first glance, this looks flexible. Callers do not need to pass dependencies around, and classes can resolve services "whenever they need them." But that convenience hides an important design cost: the dependency still exists, yet the type signature no longer shows it.

| Approach | How dependencies appear | Main effect |
| --- | --- | --- |
| Service Locator | Hidden behind runtime lookup | Easier to misuse, harder to reason about |
| Constructor injection | Visible in constructor signature | Explicit, testable, easier to validate |

### Why it is considered an anti-pattern
The main issue is **hidden dependencies**. If a class has an empty constructor but internally calls a locator for logging, email, caching, and configuration, nothing in the API tells the reader that those services are required. The code compiles, but it can still fail at runtime if the locator was not configured correctly.

This hurts maintainability. A developer can instantiate the class in a unit test or console app and only discover missing dependencies when a method is executed. In contrast, constructor injection fails earlier and more transparently.

> Warning: Service Locator often creates a false sense of decoupling. The class looks independent because it does not mention concrete services directly, but it is still tightly coupled to the locator mechanism and to runtime configuration.

### Testability impact
Testing becomes more awkward because the test must manipulate global or ambient state. Static locators are especially problematic: one test can leak registrations into another, causing order-dependent failures. That is a real-world source of flaky tests.

With constructor injection, each test builds the object graph it needs explicitly. Dependencies can be mocked or stubbed without changing global state.

### Service Locator versus DI
People sometimes confuse DI containers with Service Locator. A DI container is not the problem by itself. The key design question is **where resolution happens**.

- Good: the container resolves dependencies at the composition root and constructs the object graph.
- Risky: arbitrary business classes reach into the container or a global locator during execution.

That is why `IServiceProvider` inside business logic is often a smell. It means the class is resolving dependencies dynamically instead of declaring them.

### Are there exceptions?
There are narrow cases where controlled runtime resolution is reasonable: framework integration points, plug-in systems, factories that choose one implementation based on runtime data, or creating scoped services inside infrastructure code. Even then, keep the locator behavior near the composition root or inside a dedicated factory, not spread across domain logic.

### Practical interview answer
A strong answer says Service Locator is considered an anti-pattern because it hides dependencies, delays failure to runtime, and makes tests harder. Dependency injection is preferred because it keeps dependencies explicit and object creation centralized. If you mention one nuance, say that using a container at the composition root is normal; using it everywhere is the smell.

## Code Example
```csharp
namespace InterviewKnowledgeBase.Examples;

internal static class Program
{
    private static void Main()
    {
        ServiceLocator.Register<IEmailSender>(new ConsoleEmailSender());

        new BadWelcomeService().Send("ada@example.com");

        var goodService = new GoodWelcomeService(new ConsoleEmailSender());
        goodService.Send("grace@example.com");
    }
}

internal interface IEmailSender
{
    void Send(string email, string message);
}

internal sealed class ConsoleEmailSender : IEmailSender
{
    public void Send(string email, string message) => Console.WriteLine($"To: {email} -> {message}");
}

internal static class ServiceLocator
{
    private static readonly Dictionary<Type, object> Services = [];

    public static void Register<TService>(TService instance) where TService : notnull => Services[typeof(TService)] = instance;

    public static TService Get<TService>() where TService : notnull => (TService)Services[typeof(TService)];
}

internal sealed class BadWelcomeService
{
    public void Send(string email)
    {
        // Bad: the dependency is hidden and discovered only at runtime.
        var sender = ServiceLocator.Get<IEmailSender>();
        sender.Send(email, "Welcome!");
    }
}

internal sealed class GoodWelcomeService(IEmailSender sender)
{
    public void Send(string email)
    {
        // Good: the dependency is explicit in the constructor.
        sender.Send(email, "Welcome!");
    }
}
```

## Common Follow-up Questions
- How is Service Locator different from a DI container used at the composition root?
- Why do hidden dependencies increase runtime failure risk?
- What makes static global state especially harmful in tests?
- Are there legitimate cases for using `IServiceProvider` directly?
- Why is constructor injection usually the default recommendation in ASP.NET Core?

## Common Mistakes / Pitfalls
- Thinking Service Locator is fine because it "decouples from concrete classes" while ignoring hidden dependencies.
- Pulling `IServiceProvider` into domain or application services and resolving everything dynamically.
- Using a static locator in tests, which creates shared mutable state and flaky test runs.
- Replacing constructor injection with service location just to avoid long constructor signatures.
- Confusing factory patterns, which can be valid, with global runtime lookup from arbitrary classes.

## References
- [Service Locator is an Anti-Pattern](https://blog.ploeh.dk/2010/02/03/ServiceLocatorisanAnti-Pattern/)
- [Inversion of Control Containers and the Dependency Injection pattern](https://martinfowler.com/articles/injection.html)
- [Dependency injection in .NET](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection)
