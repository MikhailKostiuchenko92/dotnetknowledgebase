# Content Negotiation in ASP.NET Core

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟡 Middle
**Tags:** `content-negotiation`, `Accept`, `IOutputFormatter`, `XML`, `JSON`, `formatters`

## Question

> How does content negotiation work in ASP.NET Core MVC? How do you add XML support and create a custom output formatter?

## Short Answer

Content negotiation allows a client to specify its preferred response format via the `Accept` header (e.g., `Accept: application/xml`). ASP.NET Core MVC uses an `IOutputFormatter` chain to find a formatter matching both the requested media type and the response object's type. JSON is the only built-in formatter; XML requires `AddXmlSerializerFormatters()` or `AddXmlDataContractSerializerFormatters()`. Minimal APIs do not perform content negotiation by default — they always write JSON.

## Detailed Explanation

### How content negotiation works

1. Client sends `Accept: application/xml, application/json;q=0.9`.
2. MVC iterates `ObjectResult.Formatters` (or global formatters) in order.
3. Picks the first formatter that supports the media type AND the object type.
4. If no match: falls back to the first formatter (default JSON) if `ReturnHttpNotAcceptable = false` (default), or returns 406 if `true`.

```
Client: Accept: application/xml
  MVC checks formatters:
    1. SystemTextJsonOutputFormatter — supports application/json — ❌ no match
    2. XmlSerializerOutputFormatter  — supports application/xml  — ✅ match → use
```

### Formatter pipeline

Formatters are registered in `MvcOptions.OutputFormatters`. Order matters — the first match wins. Default (JSON-only):

```
[0] SystemTextJsonOutputFormatter  (application/json, text/json, application/*+json)
```

After `AddXmlSerializerFormatters()`:
```
[0] XmlSerializerOutputFormatter   (application/xml, text/xml)
[1] SystemTextJsonOutputFormatter  (application/json)
```

### Adding XML support

```csharp
builder.Services.AddControllers()
    .AddXmlSerializerFormatters();        // XmlSerializer (simple types)
    // OR
    .AddXmlDataContractSerializerFormatters(); // DataContractSerializer (complex graphs)
```

### Formatter selection without `Accept` header

If no `Accept` header is present, the first formatter is used (JSON by default).

### `[Produces]` and `[Consumes]` attributes

Override negotiation at the action or controller level:

```csharp
[Produces("application/json")]          // always produce JSON regardless of Accept
[Consumes("application/json")]          // only accept JSON request body
[HttpPost]
public IActionResult Create([FromBody] Product product) { ... }
```

### Format routing (`{format}` segment / `.json` suffix)

```csharp
// GET /api/products.json  OR  GET /api/products?format=json
builder.Services.AddControllers(opts =>
    opts.FormatterMappings.SetMediaTypeMappingForFormat("xml", "application/xml"));

[FormatFilter]              // enables {format} route segment
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    [HttpGet("{id}.{format?}")]  // /api/products/42.xml
    public IActionResult GetById(int id) => Ok(new Product { Id = id });
}
```

### Custom `IOutputFormatter`

```csharp
public sealed class CsvOutputFormatter : TextOutputFormatter
{
    public CsvOutputFormatter()
    {
        SupportedMediaTypes.Add(new MediaTypeHeaderValue("text/csv"));
        SupportedEncodings.Add(Encoding.UTF8);
        SupportedEncodings.Add(Encoding.Unicode);
    }

    protected override bool CanWriteType(Type? type)
        => type is not null && typeof(IEnumerable<object>).IsAssignableFrom(type);

    public override async Task WriteResponseBodyAsync(
        OutputFormatterWriteContext context,
        Encoding selectedEncoding)
    {
        var items = (IEnumerable<object>)context.Object!;
        var response = context.HttpContext.Response;

        await using var writer = new StreamWriter(response.Body, selectedEncoding);
        foreach (var item in items)
        {
            // Write CSV line using reflection or a CSV library
            await writer.WriteLineAsync(ToCsvLine(item));
        }
    }

    private static string ToCsvLine(object item) =>
        string.Join(",", item.GetType().GetProperties()
            .Select(p => $"\"{p.GetValue(item)?.ToString()?.Replace("\"", "\"\"")}\""));
}
```

```csharp
// Register custom formatter
builder.Services.AddControllers(opts =>
    opts.OutputFormatters.Insert(0, new CsvOutputFormatter())); // insert as first (highest priority)
```

## Code Example

```csharp
// Program.cs — content negotiation setup
builder.Services.AddControllers(opts =>
{
    // Return 406 if client requests unsupported format
    opts.ReturnHttpNotAcceptable = true;

    // Add CSV formatter
    opts.OutputFormatters.Add(new CsvOutputFormatter());
})
.AddXmlSerializerFormatters();

var app = builder.Build();
app.UseRouting();
app.MapControllers();
app.Run();
```

```csharp
// ProductsController.cs — content negotiation in action
[ApiController]
[Route("api/products")]
[Produces("application/json", "application/xml", "text/csv")] // advertise supported formats
public class ProductsController(IProductService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var products = await service.GetAllAsync(ct);
        return Ok(products);
        // Format selected based on Accept header:
        //   Accept: application/json → JSON
        //   Accept: application/xml  → XML
        //   Accept: text/csv         → CSV (our custom formatter)
    }

    [HttpGet("{id:int}")]
    [Produces("application/json")] // force JSON for single item (no CSV)
    public async Task<IActionResult> GetById(int id, CancellationToken ct)
    {
        var p = await service.GetByIdAsync(id, ct);
        return p is null ? NotFound() : Ok(p);
    }
}
```

### Client request examples

```http
GET /api/products HTTP/1.1
Accept: application/xml
# → Returns XML

GET /api/products HTTP/1.1
Accept: text/csv
# → Returns CSV

GET /api/products HTTP/1.1
Accept: application/pdf
# → Returns 406 Not Acceptable (with ReturnHttpNotAcceptable=true)
```

## Common Follow-up Questions

- What is the difference between `XmlSerializerOutputFormatter` and `XmlDataContractSerializerOutputFormatter`?
- How do you configure `System.Text.Json` options globally (e.g., camelCase, ignore nulls)?
- How do you make minimal APIs support content negotiation?
- What is `ObjectResult` and how does it differ from `JsonResult`?
- How do you support `gzip`/`br` compression alongside content negotiation?

## Common Mistakes / Pitfalls

- **Not setting `ReturnHttpNotAcceptable = true`** — without it, the server silently falls back to JSON for any unknown `Accept` header, which can mislead clients that expect structured rejection.
- **Using `JsonResult` instead of `Ok(object)`** — `JsonResult` always writes JSON and bypasses the formatter pipeline; content negotiation doesn't apply.
- **Registering XML formatter but not decorating types with `[XmlRoot]`** — `XmlSerializer` requires types to be XML-serializable. `XmlDataContractSerializer` is more flexible but slower.
- **Forgetting `[Produces]` on controllers that use custom formatters** — Swagger/OpenAPI doesn't know about the new media type; add `[Produces("text/csv")]` for documentation.
- **Custom formatter `CanWriteType` returning `true` for all types** — causes the formatter to be selected for all responses; implement type checking to avoid producing garbled output for non-collection types.

## References

- [Microsoft Learn — Content negotiation in ASP.NET Core Web API](https://learn.microsoft.com/aspnet/core/web-api/advanced/formatting?view=aspnetcore-8.0)
- [Microsoft Learn — Custom formatters in Web API](https://learn.microsoft.com/aspnet/core/web-api/advanced/custom-formatters?view=aspnetcore-8.0)
- [Microsoft Learn — AddXmlSerializerFormatters](https://learn.microsoft.com/aspnet/core/web-api/advanced/formatting?view=aspnetcore-8.0#add-xml-format-support)
- [Andrew Lock — Content negotiation in ASP.NET Core](https://andrewlock.net/tag/content-negotiation/) (verify URL)
