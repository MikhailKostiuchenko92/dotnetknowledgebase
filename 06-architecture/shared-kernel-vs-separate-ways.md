# Shared Kernel vs Separate Ways

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🔴 Senior
**Tags:** `shared-kernel`, `separate-ways`, `DDD`, `context-mapping`, `bounded-context`, `integration-patterns`

## Question

> What are the DDD context mapping integration patterns — Shared Kernel, Customer-Supplier, Conformist, Anticorruption Layer, and Separate Ways? When do you choose each pattern for bounded context integration?

## Short Answer

DDD's context mapping patterns describe how bounded contexts relate and integrate. **Shared Kernel** — two teams share a common model (highest coupling, highest coordination cost). **Customer-Supplier** — one team (supplier) provides APIs that the other (customer) consumes; supplier has control. **Conformist** — customer accepts the supplier's model as-is with no translation. **Anticorruption Layer (ACL)** — customer translates the supplier's model into its own language. **Separate Ways** — teams decide not to integrate at all; each solves the problem independently. The right pattern depends on team ownership, model quality, and the cost of coordination.

## Detailed Explanation

### The Integration Decision Matrix

Before choosing a pattern, answer:
1. Who controls each side?
2. How much can I trust the upstream model?
3. What is the coordination cost?
4. Can I afford divergence?

### Pattern 1: Shared Kernel

Two bounded contexts share a subset of the domain model (classes, database schema). Both teams must agree on all changes to the shared code.

```
Team A ←── shared kernel ───→ Team B
           (shared types,
            shared DB schema)
```

**When to use**: teams have very high coordination (same department, same code review process), and the shared concepts are truly identical in both contexts (e.g., a shared `Money` value object).

**Trade-off**: any change to the shared kernel requires both teams to agree and coordinate deployment. High value for true shared concepts; high risk of coupling creep.

```csharp
// Shared kernel: shared NuGet package or shared project
// YourApp.SharedKernel/Money.cs
namespace YourApp.SharedKernel;

public record Money(decimal Amount, string Currency)
{
    public static Money Zero => new(0, "USD");
    public Money operator +(Money other) =>
        Currency == other.Currency
            ? this with { Amount = Amount + other.Amount }
            : throw new InvalidOperationException("Cannot add different currencies");
}
```

### Pattern 2: Customer-Supplier

The upstream team (Supplier) provides an API; the downstream team (Customer) uses it. The Supplier sets the terms.

```
Orders (Customer) ───calls API───→ Inventory (Supplier)
                     IInventoryService
```

**When to use**: one team owns a service and others consume it. The supplier team has incentives to serve its customers (prioritises consumer needs in roadmap).

**Trade-off**: the downstream team depends on the supplier's release schedule. A versioned API contract mitigates coupling.

### Pattern 3: Conformist

Customer accepts the upstream model as-is — no translation. The customer's model conforms to the supplier's model.

**When to use**: the upstream model is good enough, or the customer team doesn't have resources to build an ACL. Common when consuming well-designed external APIs (e.g., Stripe, GitHub).

**Trade-off**: customer is tightly coupled to upstream model changes. Changes in upstream naming or structure propagate directly.

```csharp
// Conformist: use Stripe's SDK types directly in your application
// (no translation — your code speaks Stripe's language)
public class PaymentService(IStripeClient stripe)
{
    public async Task<string> ChargeAsync(decimal amount, string currency, string paymentMethodId)
    {
        var options = new PaymentIntentCreateOptions
        {
            Amount = (long)(amount * 100),
            Currency = currency,
            PaymentMethod = paymentMethodId,
            Confirm = true
        };
        var intent = await stripe.V1.PaymentIntents.CreateAsync(options);
        return intent.Id;
    }
}
```

### Pattern 4: Anticorruption Layer (ACL)

Customer translates the upstream model into its own domain language. See `anticorruption-layer.md` for full detail.

**When to use**: the upstream model is poor quality, legacy, or has concepts that don't map cleanly to your domain. Protects your domain model from external pollution.

### Pattern 5: Published Language

An open, shared, well-documented language (format/schema) used by many consumers. Example: REST+JSON with an OpenAPI spec, CloudEvents format, Avro schema registry.

**When to use**: one team provides a service to many, and they want self-service discovery without point-to-point coordination.

### Pattern 6: Open Host Service

Team exposes a well-defined protocol (REST API, gRPC service) for any consumer to use. Related to Published Language — the Open Host Service uses a Published Language.

### Pattern 7: Separate Ways

The teams decide not to integrate at all — each solves the problem independently.

**When to use**: integration cost exceeds the benefit. Two contexts have similar problems but the integration complexity is too high. Each team duplicates the functionality independently and maintains it separately.

**Trade-off**: duplicate effort, diverging solutions — but zero coupling.

### Comparison Table

| Pattern | Coupling | Coordination cost | Use when |
|---------|----------|-------------------|----------|
| Shared Kernel | Highest | Very high (joint ownership) | Teams tightly coordinated, truly shared concepts |
| Customer-Supplier | Medium | Medium (API versioning) | Clear owner, upstream serves downstream |
| Conformist | Medium | Low (accept upstream) | Upstream model is good; no resources for translation |
| ACL | Low | Medium (build translator) | Upstream model is poor or legacy |
| Published Language | Low | Low (schema/spec) | One provider, many consumers |
| Separate Ways | None | None | Integration cost > benefit |

## Code Example

```csharp
// Context Map documented as C# (some teams use code to express context map intent)
// This is a common pattern for making the context map visible in code

// Orders bounded context — uses ACL for legacy ERP, Conformist for Stripe
public static class OrdersContextMap
{
    // ACL — legacy ERP has poor model; translate in
    public static IServiceCollection AddErpIntegration(
        this IServiceCollection services, IConfiguration config)
    {
        services.AddHttpClient<ILegacyErpClient, LegacyErpHttpClient>();
        services.AddScoped<IInventoryPort, ErpInventoryAcl>(); // ACL implementation
        return services;
    }

    // Conformist — Stripe's model is good; use it directly
    public static IServiceCollection AddPaymentIntegration(
        this IServiceCollection services, IConfiguration config)
    {
        services.Configure<StripeOptions>(config.GetSection("Stripe"));
        services.AddScoped<IStripeClient, StripeClient>();
        // No ACL — Stripe's SDK types used directly in application layer
        return services;
    }
}
```

## Common Follow-up Questions

- How do you document a context map — are there visual tools for this?
- When does a Shared Kernel become an unmaintainable "big ball of shared mud"?
- How does the Partnership pattern (two teams co-evolve their models together) differ from Shared Kernel?
- How do you migrate from Conformist to ACL when the upstream model degrades?
- How does context mapping relate to microservice boundary design?

## Common Mistakes / Pitfalls

- **Conformist without intent**: most teams accidentally become Conformist (they just never built an ACL). Explicit Conformist is fine; accidental Conformist with a bad upstream model is a maintainability trap.
- **Shared Kernel drift**: starting with a focused shared kernel and gradually adding more types to it until it's a dumping ground. Enforce a strict "this goes in the kernel" governance process.
- **ACL as a generic adapter factory**: ACLs built "just in case" for every integration add overhead without value. Build ACLs when the upstream model is actually poor or volatile.
- **Not documenting the context map**: DDD's context mapping only provides value if everyone on the team knows which pattern applies to which integration. A simple diagram in a README or an ADR is sufficient.

## References

- [Context Mapping patterns — DDD Reference (Eric Evans)](https://www.domainlanguage.com/ddd/reference/) (verify URL)
- [Context Mapping patterns overview — InfoQ](https://www.infoq.com/articles/ddd-contextmapping/) (verify URL)
- [See: anticorruption-layer.md](./anticorruption-layer.md)
- [See: bounded-context.md](./bounded-context.md)
- [See: context-mapping-patterns.md](./context-mapping-patterns.md)
