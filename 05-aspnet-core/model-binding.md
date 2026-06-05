# Custom Model Binding in ASP.NET Core

**Category:** ASP.NET Core / MVC
**Difficulty:** Middle / Senior
**Tags:** `model-binding`, `IModelBinder`, `IModelBinderProvider`, `asp.net core`, `mvc`

## Question
> What is a Model Binder in ASP.NET Core? Can it be overridden, and in what cases would you need to do that?

## Short Answer
Model Binding is the ASP.NET Core mechanism that automatically maps HTTP request data (route values, query string, body, headers, form fields) to action method parameters. The framework ships with a built-in pipeline of binders that covers the vast majority of scenarios. When the built-in binders fall short, you can extend or fully replace them by implementing `IModelBinder` and `IModelBinderProvider`.

## Detailed Explanation

### How the standard pipeline works

When a request arrives, `ModelBinderFactory` walks the registered list of `IModelBinderProvider` instances in order and picks the first one that can handle the target type. The order of providers is determined at registration time:

```
Request data
    └─► BindingSource (Route / Query / Body / Header / Form / Services)
            └─► IModelBinderProvider  (finds the right binder)
                    └─► IModelBinder.BindModelAsync(ModelBindingContext)
```

Built-in providers (simplified, in priority order):
- `BodyModelBinderProvider` — JSON / XML via `IInputFormatter`
- `RouteValueProvider`, `QueryStringValueProvider`
- `FormFileModelBinderProvider`
- `SimpleTypeModelBinderProvider` — primitives, `Guid`, `DateTime`, etc.
- `ComplexObjectModelBinderProvider` — recursive binding for complex objects

### When you need a Custom Model Binder

**1. Non-standard data format**

For example, a date arrives as `"2024_06_04"` instead of ISO 8601, or coordinates come as `"48.45,24.01"` in a single query parameter:

```csharp
// GET /api/route?coords=48.45,24.01
public IActionResult Get([ModelBinder(typeof(CoordsBinder))] GeoPoint point) { ... }
```

**2. Binding from a non-standard source**

For example, reading a value from a custom HTTP header (`X-Tenant-Id`) and binding it directly to an action parameter instead of manually calling `Request.Headers["X-Tenant-Id"]` in every method.

**3. Complex business logic during binding**

For example, accepting a `userId` from the route and immediately resolving the full `User` entity from the database — similar to `IEntityModelBinder` patterns in other frameworks.

**4. Splitting a single parameter into multiple fields**

Query string `?filter=active:true;role:admin` → bind into `UserFilter { IsActive, Role }`.

**5. Legacy API or third-party client**

A client sends data in a format ASP.NET Core cannot parse out of the box (e.g., XML with a non-standard namespace, a binary format, or a proprietary encoding).

---

### Implementation

#### Step 1: Implement `IModelBinder`

```csharp
using Microsoft.AspNetCore.Mvc.ModelBinding;

public class CommaSeparatedGeoPointBinder : IModelBinder
{
    public Task BindModelAsync(ModelBindingContext bindingContext)
    {
        ArgumentNullException.ThrowIfNull(bindingContext);

        var valueProviderResult = bindingContext.ValueProvider
            .GetValue(bindingContext.ModelName);

        if (valueProviderResult == ValueProviderResult.None)
        {
            // nothing found — let the pipeline continue
            return Task.CompletedTask;
        }

        bindingContext.ModelState.SetModelValue(
            bindingContext.ModelName, valueProviderResult);

        var value = valueProviderResult.FirstValue;

        if (string.IsNullOrEmpty(value))
        {
            return Task.CompletedTask;
        }

        var parts = value.Split(',');

        if (parts.Length != 2
            || !double.TryParse(parts[0], out var lat)
            || !double.TryParse(parts[1], out var lon))
        {
            bindingContext.ModelState.TryAddModelError(
                bindingContext.ModelName,
                $"Cannot parse '{value}' as GeoPoint. Expected format: 'lat,lon'.");
            return Task.CompletedTask;
        }

        bindingContext.Result = ModelBindingResult.Success(new GeoPoint(lat, lon));
        return Task.CompletedTask;
    }
}
```

#### Step 2: Implement `IModelBinderProvider`

```csharp
public class GeoPointModelBinderProvider : IModelBinderProvider
{
    public IModelBinder? GetBinder(ModelBinderProviderContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        if (context.Metadata.ModelType == typeof(GeoPoint))
        {
            return new BinderTypeModelBinder(typeof(CommaSeparatedGeoPointBinder));
        }

        return null; // not our type — return null so the pipeline moves on
    }
}
```

#### Step 3: Register in `Program.cs`

```csharp
builder.Services.AddControllers(options =>
{
    // Insert(0, ...) gives the provider the highest priority
    options.ModelBinderProviders.Insert(0, new GeoPointModelBinderProvider());
});
```

> **Important:** Use `Insert(0, ...)` to put your provider first in the queue. Using `Add(...)` places it last, and it may never be reached for complex types already handled by `ComplexObjectModelBinderProvider`.

---

### Alternatives to writing a custom binder

| Scenario | Solution |
|---|---|
| Non-standard date format | `[ModelBinder]` + `TypeConverter` |
| Custom HTTP header | `[FromHeader(Name = "X-Tenant-Id")]` |
| Custom string parsing | `IParsable<T>` (.NET 7+) |
| Transformation at bind time | `[BindProperty]` + custom getter on DTO |

### `IParsable<T>` — the modern approach (.NET 7+)

```csharp
public record GeoPoint(double Lat, double Lon) : IParsable<GeoPoint>
{
    public static GeoPoint Parse(string s, IFormatProvider? provider)
    {
        var parts = s.Split(',');
        return new GeoPoint(double.Parse(parts[0]), double.Parse(parts[1]));
    }

    public static bool TryParse(string? s, IFormatProvider? provider, out GeoPoint result)
    {
        result = default!;
        if (s is null) return false;
        var parts = s.Split(',');
        if (parts.Length != 2) return false;
        if (!double.TryParse(parts[0], out var lat)
            || !double.TryParse(parts[1], out var lon)) return false;
        result = new GeoPoint(lat, lon);
        return true;
    }
}
```

`SimpleTypeModelBinderProvider` automatically picks up `IParsable<T>` starting from .NET 7 — no custom binder needed at all.

---

### Attribute-based approach (targeted override without a provider)

```csharp
[HttpGet]
public IActionResult Search(
    [ModelBinder(typeof(CommaSeparatedGeoPointBinder))] GeoPoint location)
{
    // ...
}
```

Or applied directly to the DTO class:

```csharp
[ModelBinder(BinderType = typeof(CommaSeparatedGeoPointBinder))]
public record GeoPoint(double Lat, double Lon);
```

---

## Common Follow-up Questions
- What is the difference between `IModelBinder` and `IInputFormatter`? (`IInputFormatter` deserializes the entire request body; `IModelBinder` handles individual action parameters.)
- How does Model Binding relate to validation (`ModelState`)? Validation runs after binding completes, but a binder can itself add errors via `ModelState.TryAddModelError`.
- How do `[FromBody]`, `[FromQuery]`, and `[FromRoute]` affect the binder pipeline? They set the `BindingSource`, which filters out irrelevant value providers and speeds up resolution.
- Can I use DI inside a custom binder? Yes — register it as a service and use `BinderTypeModelBinder`; ASP.NET Core will resolve it through the DI container automatically.

## Common Mistakes / Pitfalls
- Returning `Task.CompletedTask` without setting `bindingContext.Result` — binding is treated as "not attempted" and the model will be `null`.
- Registering the provider with `Add(...)` instead of `Insert(0, ...)` — it will never be reached for complex types.
- Trying to read `Request.Body` directly inside a binder when `[FromBody]` is already in use — the body stream may have already been consumed.
- Not handling `ValueProviderResult.None` — leads to a `NullReferenceException`.

## References
- [Microsoft Docs: Custom Model Binding](https://learn.microsoft.com/en-us/aspnet/core/mvc/advanced/custom-model-binding)
- [Microsoft Docs: Model Binding in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/mvc/models/model-binding)
