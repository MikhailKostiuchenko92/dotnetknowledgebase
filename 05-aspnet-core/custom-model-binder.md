# Custom Model Binder

**Category:** ASP.NET Core / Routing
**Difficulty:** 🔴 Senior
**Tags:** `IModelBinder`, `IModelBinderProvider`, `custom-binding`, `model-binding`, `composite`

## Question

> How do you implement a custom model binder in ASP.NET Core using `IModelBinder` and `IModelBinderProvider`?

## Short Answer

A custom model binder implements `IModelBinder.BindModelAsync` to populate a `ModelBindingResult` on the `ModelBindingContext`. An `IModelBinderProvider` tells the framework when to use this binder (for which types or parameter attributes). You register the provider via `MvcOptions.ModelBinderProviders.Insert(0, ...)` or apply it per-parameter with `[ModelBinder(typeof(...))]`. Use custom binders when the built-in binding sources don't cover your scenario — e.g., binding from a custom header, combining multiple sources, or transforming raw input before model population.

## Detailed Explanation

### `IModelBinder` interface

```csharp
public interface IModelBinder
{
    Task BindModelAsync(ModelBindingContext bindingContext);
}
```

The `ModelBindingContext` provides:
- `ValueProvider` — the composite value provider (route, query, form, etc.)
- `ModelType` — the type being bound
- `ModelName` — the parameter/property name
- `Result` — set to `ModelBindingResult.Success(value)` or `ModelBindingResult.Failed()`

### `IModelBinderProvider`

```csharp
public interface IModelBinderProvider
{
    IModelBinder? GetBinder(ModelBinderProviderContext context);
}
```

Return `null` to skip this provider for the current type; return an `IModelBinder` instance to handle it.

### Registration options

1. **Global registration:**
```csharp
builder.Services.AddControllers(opts =>
    opts.ModelBinderProviders.Insert(0, new MyModelBinderProvider()));
```

2. **Per-parameter attribute:**
```csharp
[HttpGet]
public IActionResult Get([ModelBinder(typeof(CommaSeparatedArrayBinder))] int[] ids) { }
```

3. **Attribute-driven provider** — the provider checks for a custom attribute:
```csharp
public IModelBinder? GetBinder(ModelBinderProviderContext ctx)
{
    if (ctx.Metadata.ModelType == typeof(DateRange))
        return new DateRangeModelBinder();
    return null;
}
```

### Value providers

A model binder reads values from `IValueProvider` instances layered in `CompositeValueProvider`:

| Source | Provider type |
|---|---|
| Route data | `RouteValueProvider` |
| Query string | `QueryStringValueProvider` |
| Form data | `FormValueProvider` |
| JSON body | `BodyModelBinder` (separate) |

```csharp
var valueResult = bindingContext.ValueProvider.GetValue(bindingContext.ModelName);
if (valueResult == ValueProviderResult.None) return;
var rawValue = valueResult.FirstValue;
```

### When to use a custom binder

| Scenario | Solution |
|---|---|
| Bind from custom header | Custom `IModelBinder` + custom `IValueProvider` |
| Parse custom format (comma-separated IDs) | `IModelBinder` for array type |
| Combine route + query + header | Composite binder |
| Transform raw string (trim, decode, normalize) | `IModelBinder` |
| Deserialize from special content type | `IInputFormatter` (for body) |

## Code Example

```csharp
// CommaSeparatedArrayBinder.cs — bind "?ids=1,2,3" to int[]
public sealed class CommaSeparatedArrayBinder : IModelBinder
{
    public Task BindModelAsync(ModelBindingContext context)
    {
        var modelName = context.ModelName;
        var valueResult = context.ValueProvider.GetValue(modelName);

        if (valueResult == ValueProviderResult.None)
        {
            context.Result = ModelBindingResult.Success(Array.Empty<int>());
            return Task.CompletedTask;
        }

        var rawValue = valueResult.FirstValue;
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            context.Result = ModelBindingResult.Success(Array.Empty<int>());
            return Task.CompletedTask;
        }

        var parts = rawValue.Split(',', StringSplitOptions.RemoveEmptyEntries);
        var result = new List<int>(parts.Length);

        foreach (var part in parts)
        {
            if (!int.TryParse(part.Trim(), out var id))
            {
                context.ModelState.TryAddModelError(
                    modelName, $"'{part}' is not a valid integer.");
                context.Result = ModelBindingResult.Failed();
                return Task.CompletedTask;
            }
            result.Add(id);
        }

        context.Result = ModelBindingResult.Success(result.ToArray());
        return Task.CompletedTask;
    }
}
```

```csharp
// CommaSeparatedArrayBinderProvider.cs
public sealed class CommaSeparatedArrayBinderProvider : IModelBinderProvider
{
    public IModelBinder? GetBinder(ModelBinderProviderContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        // Only handle int[] for now — extend to IList<int> etc. as needed
        if (context.Metadata.ModelType == typeof(int[])
            && context.BindingInfo?.BindingSource == BindingSource.Query)
        {
            return new CommaSeparatedArrayBinder();
        }

        return null;
    }
}
```

```csharp
// Program.cs
builder.Services.AddControllers(opts =>
{
    opts.ModelBinderProviders.Insert(0, new CommaSeparatedArrayBinderProvider());
});
```

```csharp
// Controller usage
[ApiController, Route("api/products")]
public class ProductsController(IProductService service) : ControllerBase
{
    // GET /api/products/batch?ids=1,2,3,42
    [HttpGet("batch")]
    public async Task<IActionResult> GetByIds([FromQuery] int[] ids, CancellationToken ct)
        => Ok(await service.GetByIdsAsync(ids, ct));
}
```

### Advanced: binding from a custom header value provider

```csharp
public sealed class HeaderValueProvider(IHeaderDictionary headers) : IValueProvider
{
    public bool ContainsPrefix(string prefix) =>
        headers.ContainsKey(prefix) || headers.Keys.Any(k =>
            k.StartsWith(prefix + ".", StringComparison.OrdinalIgnoreCase));

    public ValueProviderResult GetValue(string key)
    {
        if (headers.TryGetValue(key, out var values))
            return new ValueProviderResult(values.ToArray(), CultureInfo.InvariantCulture);
        return ValueProviderResult.None;
    }
}

public sealed class HeaderValueProviderFactory : IValueProviderFactory
{
    public Task CreateValueProviderAsync(ValueProviderFactoryContext context)
    {
        context.ValueProviders.Add(new HeaderValueProvider(
            context.ActionContext.HttpContext.Request.Headers));
        return Task.CompletedTask;
    }
}

// Register
builder.Services.AddControllers(opts =>
    opts.ValueProviderFactories.Add(new HeaderValueProviderFactory()));
```

## Common Follow-up Questions

- When should you use a custom `IModelBinder` vs a custom `IValueProviderFactory`?
- How do you support async model binding (e.g., database lookup during binding)?
- How does the model binder interact with `ModelState` validation — can a custom binder add its own errors?
- How do you make a custom binder work with both `[FromQuery]` and `[FromRoute]` sources?
- What is the difference between `IInputFormatter` and `IModelBinder` for body binding?

## Common Mistakes / Pitfalls

- **Not inserting the provider at index 0** — built-in providers run before yours if you `Add` rather than `Insert(0, ...)`. The `ComplexObjectModelBinderProvider` will match complex types before your provider does.
- **Returning `ModelBindingResult.Failed()` without adding a `ModelState` error** — the action receives a null/default parameter but `ModelState.IsValid` may be true because no error was recorded.
- **Setting `context.Result` to `Success(null)` for required parameters** — if the parameter is marked `[Required]`, null passes through silently. Add a `ModelState` error for missing required values.
- **Performing synchronous I/O inside `BindModelAsync`** — this is an async pipeline; blocking inside it reduces throughput. Use `await` for any I/O operations.
- **Provider checking only `ModelType` without checking `BindingSource`** — your binder may match the same type from body parameters, causing conflicts with `BodyModelBinder`.

## References

- [Microsoft Learn — Custom model binders](https://learn.microsoft.com/aspnet/core/mvc/advanced/custom-model-binding?view=aspnetcore-8.0)
- [Microsoft Learn — Model binding in ASP.NET Core](https://learn.microsoft.com/aspnet/core/mvc/models/model-binding?view=aspnetcore-8.0)
- [Microsoft — IModelBinder source](https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Core/src/ModelBinding/IModelBinder.cs)
- [Andrew Lock — Custom model binding in ASP.NET Core](https://andrewlock.net/tag/model-binding/) (verify URL)
