# Hypermedia and HATEOAS

**Category:** Architecture / API Design
**Difficulty:** 🔴 Senior
**Tags:** `HATEOAS`, `hypermedia`, `REST-level-3`, `HAL`, `Siren`, `self-descriptive`, `link-relations`

## Question

> What is HATEOAS, and why is it considered the highest level of REST maturity? What are HAL and Siren formats, what problems does true HATEOAS solve, and why is it rarely worth implementing in practice?

## Short Answer

HATEOAS (Hypermedia as the Engine of Application State) means API responses include links describing available state transitions — clients discover actions from responses rather than having them hardcoded. It's REST level 3 (Richardson Maturity Model). HAL and Siren are standard hypermedia formats. The theoretical benefit: clients decouple from server URL structures and state machines. The practical reality: most clients (mobile apps, SPAs) are tightly coupled to the API anyway; HATEOAS adds server complexity and response overhead without meaningful benefit for the 95% of APIs where the client is co-developed with the server. Reserve it for true client-independent APIs (e.g., payment provider SDKs, public developer platforms).

## Detailed Explanation

### HATEOAS in Theory

```json
// Without HATEOAS: client hardcodes knowledge of valid actions per state
// Client code: if (order.status == "Submitted") { showConfirmButton(); }
//              if (order.status == "Submitted") { cancelUrl = "/orders/" + id + "/cancel"; }

// With HATEOAS: server describes available transitions in the response
// Client code: render each _link that has a rel it knows about — no state machine logic needed

GET /api/orders/42

{
  "orderId": 42,
  "status":  "Submitted",
  "total":   99.99,
  "_links": {
    "self":    { "href": "/api/orders/42", "method": "GET" },
    "confirm": { "href": "/api/orders/42/confirm", "method": "POST" },
    "cancel":  { "href": "/api/orders/42/cancel",  "method": "POST" }
  }
  // ← "confirm" and "cancel" appear only when status allows them
  // When status is "Shipped", response would only include "self" and "track"
}
```

### HAL Format (Hypertext Application Language)

```json
// application/hal+json
{
  "_links": {
    "self":       { "href": "/orders/42" },
    "customer":   { "href": "/customers/7" },
    "lines":      { "href": "/orders/42/lines" },
    "confirm":    { "href": "/orders/42/confirm" },
    "curies": [
      {
        "name": "myapi",
        "href": "https://docs.myapi.com/rels/{rel}",
        "templated": true
      }
    ]
  },
  "_embedded": {
    "lines": [
      {
        "_links": { "self": { "href": "/orders/42/lines/1" } },
        "productId": 5, "quantity": 2, "price": 49.99
      }
    ]
  },
  "orderId": 42,
  "status":  "Submitted",
  "total":   99.99
}
```

```csharp
// HAL in ASP.NET Core with Halcyon.AspNet or custom implementation
// NuGet: Halcyon.AspNet (verify if still maintained)

public record HalOrderResponse(int OrderId, decimal Total, string Status) : HALResponse(null)
{
    public HalOrderResponse WithLinks(Order order) : this(OrderId, Total, Status)
    {
        AddLinks(new Link("self", $"/api/orders/{order.Id}"));
        if (order.CanConfirm()) AddLinks(new Link("confirm", $"/api/orders/{order.Id}/confirm"));
        if (order.CanCancel())  AddLinks(new Link("cancel", $"/api/orders/{order.Id}/cancel"));
        return this;
    }
}
```

### Siren Format

Siren extends HAL with typed actions (method, fields, type):

```json
// application/vnd.siren+json
{
  "class": ["order"],
  "properties": { "orderId": 42, "status": "Submitted", "total": 99.99 },
  "links": [
    { "rel": ["self"], "href": "/orders/42" }
  ],
  "actions": [
    {
      "name": "confirm-order",
      "title": "Confirm Order",
      "method": "POST",
      "href": "/orders/42/confirm",
      "type": "application/json",
      "fields": []
    },
    {
      "name": "cancel-order",
      "title": "Cancel Order",
      "method": "POST",
      "href": "/orders/42/cancel",
      "type": "application/json",
      "fields": [
        { "name": "reason", "type": "text", "required": true }
      ]
    }
  ]
}
```

### Why HATEOAS Rarely Pays Off

```
The promise: clients are fully server-driven — change URLs or state machines
              server-side without updating clients

The reality for most APIs:
  1. Client developers still read API documentation to understand business semantics
     ("what does 'confirm' do?") — links don't convey meaning
  2. Mobile apps and SPAs are released alongside API changes — they ARE tightly coupled
  3. Response payload grows 2–3x to carry link objects
  4. Server code complexity: state machine must determine which links to include per response
  5. Generated clients (from OpenAPI) lose their type-safety with dynamic links
  6. Caching: different responses for same resource based on state → harder to cache

When HATEOAS IS worth it:
  - Publicly distributed SDKs where clients cannot be updated in sync with server
  - Payment flows where URL stability is a contractual guarantee (e.g., Stripe links)
  - Hypermedia-driven generic UI builders
  - APIs where client teams have no coordination with server teams

Pragmatic alternative (level 2.5):
  - Use task-based sub-resource URLs: POST /orders/42/confirm
  - Document state machine in OpenAPI spec with examples
  - Skip the _links overhead
```

### Practical HATEOAS in ASP.NET Core

```csharp
// Custom lightweight link builder — not a full HAL library
public class OrderResponse(Order order, IUrlHelper urlHelper)
{
    public int Id      => order.Id;
    public string Status => order.Status.ToString();
    public decimal Total => order.Total;

    public IEnumerable<ApiLink> Links
    {
        get
        {
            yield return new ApiLink("self", urlHelper.ActionLink("GetById", "Orders", new { id = order.Id })!, "GET");

            if (order.CanConfirm())
                yield return new ApiLink("confirm", urlHelper.ActionLink("Confirm", "Orders", new { id = order.Id })!, "POST");
            if (order.CanCancel())
                yield return new ApiLink("cancel", urlHelper.ActionLink("Cancel", "Orders", new { id = order.Id })!, "POST");
        }
    }
}

public record ApiLink(string Rel, string Href, string Method);
```

## Code Example

```csharp
// Feature-flagged HATEOAS — enable per consumer type
app.MapGet("/api/orders/{id:int}", async (int id, ISender sender,
    [FromHeader(Name = "Accept")] string? accept, CancellationToken ct) =>
{
    var order = await sender.Send(new GetOrderByIdQuery(id), ct);
    if (order is null) return Results.NotFound();

    // Return HAL if client requested it; plain JSON otherwise
    if (accept?.Contains("application/hal+json") == true)
        return Results.Ok(new HalOrderResponse(order));

    return Results.Ok(order);
});
```

## Common Follow-up Questions

- Is there a mature HAL library for ASP.NET Core that's actively maintained?
- How does Stripe's API use HATEOAS-like patterns in practice?
- How do you document HATEOAS links in an OpenAPI specification?
- What are link relations (`rel` values), and where are they standardized (IANA)?
- How does JSON-LD (used in Schema.org) relate to HATEOAS?

## Common Mistakes / Pitfalls

- **Implementing HATEOAS for internal services**: teams that own both consumer and provider gain nothing from HATEOAS — they're already coordinating changes. HATEOAS overhead is pure waste in this context.
- **Incomplete link generation**: only including some links (always including `self`, forgetting action links) creates a partial HATEOAS implementation that's worse than none — clients still need hardcoded logic for the missing parts.
- **Conflating HATEOAS with REST**: REST level 2 (HTTP verbs + status codes) is excellent API design. Stopping at level 2 is not a failure — HATEOAS is an optional advanced pattern for specific use cases.
- **Hardcoding HATEOAS URLs in tests**: `_links.confirm.href == "/orders/42/confirm"` — this breaks when URL routing changes. Test the link relation names (`rel`), not the URLs.

## References

- [Richardson Maturity Model — Martin Fowler](https://martinfowler.com/articles/richardsonMaturityModel.html) (verify URL)
- [HAL Specification](https://stateless.co/hal_specification.html) (verify URL)
- [Siren Specification](https://github.com/kevinswiber/siren)
- [IANA Link Relations](https://www.iana.org/assignments/link-relations/link-relations.xhtml)
- [See: rest-maturity-model.md](./rest-maturity-model.md)
