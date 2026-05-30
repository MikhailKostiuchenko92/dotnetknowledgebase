# REST Maturity Model

**Category:** Architecture / API Design
**Difficulty:** 🟢 Junior
**Tags:** `REST`, `Richardson-maturity-model`, `HATEOAS`, `HTTP-verbs`, `resources`, `pragmatic-REST`

## Question

> What is the Richardson Maturity Model? Describe levels 0–3, and explain why most production APIs stop at level 2 rather than implementing full HATEOAS (level 3).

## Short Answer

The **Richardson Maturity Model** describes four levels of REST API maturity. **Level 0**: single endpoint, HTTP used as transport only (XML-RPC, SOAP style). **Level 1**: multiple resources (URLs per entity). **Level 2**: HTTP verbs + proper status codes (most production REST APIs). **Level 3**: HATEOAS — responses include links describing available actions. Most APIs stop at level 2 because level 3 (HATEOAS) adds significant complexity to both server implementation and client code for limited practical benefit in most business applications.

## Detailed Explanation

### Level 0: Single Endpoint, HTTP as Tunnel

```
POST /api
Body: { "action": "getOrder", "orderId": 42 }

POST /api
Body: { "action": "placeOrder", "customerId": 7, "lines": [...] }
```

HTTP is used only as a transport. All actions are POST to one URL. Status codes are ignored — the response body contains error information.

### Level 1: Resources (Multiple URLs)

```
GET  /orders
GET  /orders/42
POST /orders (but might also use GET for writes)
GET  /customers
```

Different URLs for different resources, but HTTP verbs are not used semantically. Often all requests are POST (or GET), regardless of operation type.

### Level 2: HTTP Verbs + Status Codes

Most production REST APIs are at level 2:

```http
GET    /api/orders           → 200 OK, list of orders
GET    /api/orders/42        → 200 OK, single order; 404 if not found
POST   /api/orders           → 201 Created + Location: /api/orders/43
PUT    /api/orders/42        → 200 OK (replace) or 204 No Content
PATCH  /api/orders/42        → 200 OK (partial update)
DELETE /api/orders/42        → 204 No Content; 404 if not found

Error responses:
400 Bad Request    — client validation error
401 Unauthorized   — not authenticated
403 Forbidden      — authenticated but not authorized
404 Not Found      — resource doesn't exist
409 Conflict       — optimistic concurrency conflict
500 Internal Error — server error
```

```csharp
// ASP.NET Core Level 2 REST endpoint
[HttpPost]
[ProducesResponseType<int>(StatusCodes.Status201Created)]
[ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
public async Task<IActionResult> Post([FromBody] PlaceOrderCommand cmd, CancellationToken ct)
{
    var id = await _sender.Send(cmd, ct);
    return CreatedAtAction(nameof(Get), new { id }, id);
}
```

### Level 3: HATEOAS (Hypermedia As The Engine Of Application State)

Responses include links to available next actions:

```json
GET /api/orders/42

{
  "orderId": 42,
  "status": "Submitted",
  "total": 99.99,
  "_links": {
    "self":    { "href": "/api/orders/42", "method": "GET" },
    "confirm": { "href": "/api/orders/42/confirm", "method": "POST" },
    "cancel":  { "href": "/api/orders/42/cancel", "method": "POST" },
    "lines":   { "href": "/api/orders/42/lines", "method": "GET" }
  }
}
```

The client discovers available actions from the response — no hardcoded URLs or knowledge of what operations are valid in each state.

### Why Most APIs Stop at Level 2

| Consideration | Level 2 | Level 3 (HATEOAS) |
|---------------|---------|-------------------|
| **Client complexity** | Simple — URL templates known upfront | Complex — must parse and follow links |
| **Caching** | Works well with URL-based caching | Links change per state — cache complexity |
| **Documentation** | OpenAPI/Swagger handles it well | Hard to document dynamic links |
| **SDK generation** | Straightforward | Complex — links aren't typed |
| **Benefit** | None for most clients | True hypermedia client independence |

> **Pragmatic guideline**: Build a Level 2 API with good HTTP verb/status code usage, documented with OpenAPI. Use task-based URLs for actions (see [task-based-ui-and-cqrs.md](./task-based-ui-and-cqrs.md)) rather than HATEOAS links: `POST /orders/42/confirm` instead of following a link from the order response.

## Code Example

```csharp
// Level 2 REST in ASP.NET Core — idiomatic, pragmatic
[ApiController, Route("api/[controller]")]
public class OrdersController(ISender sender) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<OrderSummaryDto>> List([FromQuery] GetOrdersQuery q, CancellationToken ct)
        => sender.Send(q, ct);

    [HttpGet("{id:int}", Name = nameof(GetById))]
    public async Task<ActionResult<OrderDto>> GetById(int id, CancellationToken ct)
    {
        var order = await sender.Send(new GetOrderByIdQuery(id), ct);
        return order is null ? NotFound() : Ok(order);
    }

    [HttpPost]
    public async Task<IActionResult> Place([FromBody] PlaceOrderCommand cmd, CancellationToken ct)
    {
        var id = await sender.Send(cmd, ct);
        return CreatedAtAction(nameof(GetById), new { id }, id);  // ← 201 + Location header
    }

    [HttpPost("{id:int}/confirm")]  // ← task-based sub-resource (level 2 pragmatic, not HATEOAS)
    public async Task<IActionResult> Confirm(int id, CancellationToken ct)
    {
        await sender.Send(new ConfirmOrderCommand(id), ct);
        return NoContent();  // 204
    }
}
```

## Common Follow-up Questions

- What HTTP status code should you return for a business rule violation (e.g., "cannot cancel a shipped order")?
- When should you use `PUT` vs `PATCH` for updates?
- What is the difference between `204 No Content` and `200 OK` for a successful command?
- Is HATEOAS ever worth implementing — are there real-world examples?
- How do you document task-based endpoints in OpenAPI?

## Common Mistakes / Pitfalls

- **Returning 200 OK for a resource creation**: `POST /orders` creating a new order should return `201 Created` with a `Location` header — not `200 OK`.
- **Overusing 500 for business errors**: `"Cannot cancel a shipped order"` is a `400 Bad Request` or `422 Unprocessable Entity` — not a server error. Reserve 500 for unexpected failures.
- **GET requests with side effects**: `GET /api/orders/place` that places an order violates HTTP method semantics — GET must be safe and idempotent.
- **Returning the full entity on every operation**: `PUT /orders/42` that returns the full order DTO on success is over-fetching. Return `204 No Content` or the updated entity only if the client needs it.

## References

- [Richardson Maturity Model — Martin Fowler](https://martinfowler.com/articles/richardsonMaturityModel.html) (verify URL)
- [HATEOAS — RESTful Web APIs (Richardson & Amundsen)](https://www.oreilly.com/library/view/restful-web-apis/9781449359713/) (verify URL)
- [See: api-versioning-strategies.md](./api-versioning-strategies.md)
- [See: task-based-ui-and-cqrs.md](./task-based-ui-and-cqrs.md)
