# Keyed Services in ASP.NET Core (.NET 8+)

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🟡 Middle
**Tags:** `keyed-services`, `FromKeyedServices`, `named-services`, `DI`, `.NET8`

## Question

> What are keyed services in .NET 8, and how do they differ from the factory pattern for resolving named implementations?

## Short Answer

Keyed services (introduced in .NET 8) allow registering multiple implementations of the same interface under a distinguishing key (any object, typically a string or enum), and resolving them by key using `[FromKeyedServices(key)]` attribute in constructors/parameters or `IServiceProvider.GetRequiredKeyedService<T>(key)`. They are the framework's native solution to the "named service" problem, replacing the common workaround of injecting a `Func<string, T>` factory delegate.

## Detailed Explanation

### The problem keyed services solve

Before .NET 8, registering two `IPaymentGateway` implementations (Stripe, PayPal) and choosing between them required workarounds:

- Factory delegate: `Func<string, IPaymentGateway>` registered as Singleton.
- Custom `IServiceProvider` extension method.
- Scrutor's `Decorate` + strategy pattern.

All of these work but add boilerplate. Keyed services make this a first-class framework feature.

### Registration

```csharp
// Register with a string key
builder.Services.AddKeyedSingleton<IPaymentGateway, StripeGateway>("stripe");
builder.Services.AddKeyedSingleton<IPaymentGateway, PayPalGateway>("paypal");

// Also works with Scoped and Transient
builder.Services.AddKeyedScoped<IRepository, SqlRepository>("sql");
builder.Services.AddKeyedScoped<IRepository, MongoRepository>("mongo");
```

Keys can be any object that implements `Equals`/`GetHashCode` well: `string`, `enum`, `int`, etc.

### Resolution — constructor/parameter injection

```csharp
public class CheckoutService(
    [FromKeyedServices("stripe")] IPaymentGateway stripe,
    [FromKeyedServices("paypal")] IPaymentGateway paypal)
{
    public Task ProcessAsync(PaymentMethod method, decimal amount) =>
        method == PaymentMethod.Stripe
            ? stripe.ChargeAsync(amount)
            : paypal.ChargeAsync(amount);
}
```

`[FromKeyedServices]` is also valid in minimal API parameters:
```csharp
app.MapPost("/pay/stripe", ([FromKeyedServices("stripe")] IPaymentGateway gw, PayRequest req)
    => gw.ChargeAsync(req.Amount));
```

### Resolution — `IServiceProvider` / `IKeyedServiceProvider`

```csharp
// Programmatic resolution
var gateway = provider.GetRequiredKeyedService<IPaymentGateway>("stripe");

// Or with the keyed interface
var keyedProvider = (IKeyedServiceProvider)provider;
var gateway = keyedProvider.GetRequiredKeyedService<IPaymentGateway>("paypal");
```

### Non-keyed registrations are still available

Non-keyed `AddSingleton<IPaymentGateway, StripeGateway>()` and keyed registrations coexist. `GetRequiredService<IPaymentGateway>()` (no key) resolves the last non-keyed registration as usual.

### Keyed vs factory pattern comparison

| Aspect | Keyed services (.NET 8) | Factory delegate (`Func<string, T>`) |
|---|---|---|
| Framework support | Native, built-in | Manual wiring |
| Constructor attribute | `[FromKeyedServices]` | N/A |
| DI scope correctness | ✅ Managed by container | Manual (you create scope) |
| Discoverable | ✅ Via `IServiceCollection` introspection | ❌ Opaque |
| Multiple return types | ❌ (same T) | ✅ (factory can return different types) |

### Enum keys (clean code)

```csharp
public enum StorageProvider { Local, AzureBlob, S3 }

services.AddKeyedSingleton<IFileStorage, LocalFileStorage>(StorageProvider.Local);
services.AddKeyedSingleton<IFileStorage, AzureBlobStorage>(StorageProvider.AzureBlob);
services.AddKeyedSingleton<IFileStorage, S3Storage>(StorageProvider.S3);
```

```csharp
public class FileManager(
    [FromKeyedServices(StorageProvider.AzureBlob)] IFileStorage storage) { }
```

## Code Example

```csharp
// IPaymentGateway.cs
public interface IPaymentGateway
{
    Task<PaymentResult> ChargeAsync(decimal amount, CancellationToken ct = default);
}

// StripeGateway.cs
public sealed class StripeGateway(IOptions<StripeOptions> opts) : IPaymentGateway
{
    public async Task<PaymentResult> ChargeAsync(decimal amount, CancellationToken ct)
    {
        // Stripe SDK call here
        return new PaymentResult(Success: true, TransactionId: Guid.NewGuid().ToString());
    }
}

// PayPalGateway.cs
public sealed class PayPalGateway(IOptions<PayPalOptions> opts) : IPaymentGateway
{
    public async Task<PaymentResult> ChargeAsync(decimal amount, CancellationToken ct)
    {
        return new PaymentResult(Success: true, TransactionId: Guid.NewGuid().ToString());
    }
}
```

```csharp
// Program.cs
builder.Services.AddKeyedSingleton<IPaymentGateway, StripeGateway>("stripe");
builder.Services.AddKeyedSingleton<IPaymentGateway, PayPalGateway>("paypal");

// Minimal API
app.MapPost("/pay/{provider}", async (
    string provider,
    PayRequest req,
    IKeyedServiceProvider services) =>
{
    var gateway = services.GetRequiredKeyedService<IPaymentGateway>(provider);
    var result = await gateway.ChargeAsync(req.Amount);
    return result.Success ? Results.Ok(result) : Results.StatusCode(502);
});
```

```csharp
// Controller with constructor injection
public class PaymentController(
    [FromKeyedServices("stripe")] IPaymentGateway stripeGateway,
    [FromKeyedServices("paypal")] IPaymentGateway paypalGateway) : ControllerBase
{
    [HttpPost("stripe")]
    public Task<IActionResult> PayWithStripe([FromBody] PayRequest req) => ...;
}
```

## Common Follow-up Questions

- Can you register a keyed service and a non-keyed service for the same interface?
- How do keyed services interact with `IEnumerable<T>` resolution — do they appear in the enumeration?
- How do you unit-test a class that uses `[FromKeyedServices]`?
- Can keyed services be Scoped — how does scope management differ from Singleton keyed services?
- What is the difference between keyed services and `IServiceProviderIsKeyedService`?

## Common Mistakes / Pitfalls

- **Resolving keyed services with plain `GetRequiredService<T>()`** — this ignores the key and returns the last non-keyed registration (or throws if none exists).
- **Using string keys with typos** — no compile-time check for key strings. Prefer `enum` or `static readonly` constants to avoid key mismatches.
- **Assuming keyed services appear in `IEnumerable<T>`** — `GetServices<IPaymentGateway>()` (without key) does NOT include keyed registrations.
- **Mixing keyed and non-keyed expectations** — if a non-keyed `AddSingleton<IPaymentGateway, StripeGateway>()` exists alongside keyed registrations, `GetRequiredService<IPaymentGateway>()` returns the non-keyed one, which may surprise you.
- **Injecting `IKeyedServiceProvider` into business logic** — this is the service locator anti-pattern. Prefer constructor injection with `[FromKeyedServices]`.

## References

- [Microsoft Learn — Keyed services in .NET 8](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection#keyed-services)
- [Andrew Lock — Keyed services in .NET 8](https://andrewlock.net/exploring-the-dotnet-8-preview-keyed-services-in-microsoft-extensions-dependencyinjection/) (verify URL)
- [Microsoft — AddKeyedSingleton source (GitHub)](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.DependencyInjection/src/ServiceCollectionServiceExtensions.cs)
- [Microsoft — IKeyedServiceProvider](https://learn.microsoft.com/dotnet/api/microsoft.extensions.dependencyinjection.ikeyedserviceprovider?view=dotnet-plat-ext-8.0)
