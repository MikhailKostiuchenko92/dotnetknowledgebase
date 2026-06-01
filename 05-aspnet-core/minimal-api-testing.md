# Testing Minimal APIs in ASP.NET Core

**Category:** ASP.NET Core / Testing
**Difficulty:** 🟡 Middle
**Tags:** `minimal-api`, `integration-testing`, `WebApplicationFactory`, `TypedResults`, `endpoint-testing`

## Question

> How do you write integration and unit tests for Minimal API endpoints in ASP.NET Core? What are the differences compared to testing controller-based APIs?

## Short Answer

Minimal API endpoints are tested with `WebApplicationFactory` the same way as controller-based APIs — send HTTP requests via `HttpClient` and assert on response status/body. The key differences are: there's no `IActionResult` abstraction to unit-test in isolation (endpoints are lambdas), `TypedResults` improves OpenAPI schema but doesn't change testability, and route group organization replaces controller class hierarchy for test organization.

## Detailed Explanation

### Integration tests (main approach)

```csharp
// Standard WebApplicationFactory test works identically for Minimal APIs
public sealed class TodoApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public TodoApiTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task GetTodos_ReturnsOkWithList()
    {
        var response = await _client.GetAsync("/todos");

        response.EnsureSuccessStatusCode();
        var todos = await response.Content.ReadFromJsonAsync<List<TodoDto>>();
        Assert.NotNull(todos);
    }

    [Fact]
    public async Task CreateTodo_ReturnsCreated()
    {
        var newTodo = new CreateTodoRequest("Write tests", false);
        var response = await _client.PostAsJsonAsync("/todos", newTodo);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(response.Headers.Location);
    }
}
```

### Testing validation (400 responses)

```csharp
[Fact]
public async Task CreateTodo_WithBlankTitle_Returns400()
{
    var response = await _client.PostAsJsonAsync("/todos", new { Title = "" });

    Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
    Assert.True(problem!.Errors.ContainsKey("Title"));
}
```

### Unit testing endpoint handlers (extract to methods)

Minimal API endpoints are lambdas/delegates — not directly unit-testable unless you extract the logic:

```csharp
// ❌ Lambda — hard to unit test
app.MapPost("/todos", async ([FromBody] CreateTodoRequest req, AppDbContext db) =>
{
    var todo = new Todo { Title = req.Title };
    db.Todos.Add(todo);
    await db.SaveChangesAsync();
    return TypedResults.Created($"/todos/{todo.Id}", todo);
});

// ✅ Extracted handler method — unit testable
app.MapPost("/todos", TodoHandlers.Create);

public static class TodoHandlers
{
    public static async Task<Created<Todo>> Create(
        [FromBody] CreateTodoRequest req,
        AppDbContext db,
        CancellationToken ct)
    {
        var todo = new Todo { Title = req.Title };
        db.Todos.Add(todo);
        await db.SaveChangesAsync(ct);
        return TypedResults.Created($"/todos/{todo.Id}", todo);
    }
}

// Unit test
[Fact]
public async Task Create_ReturnsCreatedWithTodo()
{
    using var db = CreateInMemoryDb();
    var req = new CreateTodoRequest("Test");

    var result = await TodoHandlers.Create(req, db, CancellationToken.None);

    Assert.Equal("/todos/1", result.Location);
    Assert.Equal("Test", result.Value!.Title);
}
```

### Testing route groups and filters

```csharp
// app setup
var todos = app.MapGroup("/todos").RequireAuthorization();
todos.MapGet("/{id}", TodoHandlers.GetById);
todos.MapPost("/", TodoHandlers.Create);

// Test: auth is enforced on the group
[Fact]
public async Task GetTodo_Unauthenticated_Returns401()
{
    var anonClient = _factory.CreateClient(new WebApplicationFactoryClientOptions
    {
        AllowAutoRedirect = false
    });

    var response = await anonClient.GetAsync("/todos/1");

    Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
}
```

### Asserting `TypedResults` in unit tests

```csharp
// TypedResults return typed objects — easy to assert
var result = await TodoHandlers.GetById(1, db, CancellationToken.None);

// result is Ok<TodoDto> or NotFound — switch on type
if (result.Result is Ok<TodoDto> ok)
    Assert.Equal("Test todo", ok.Value!.Title);
else
    Assert.Fail("Expected Ok result");
```

## Code Example

```csharp
// Parameterized integration test for CRUD endpoints
[Theory]
[InlineData("/todos", HttpMethod.Get, null, HttpStatusCode.OK)]
// Add more endpoint/method/body/status combinations
public async Task Endpoints_ReturnExpectedStatusCodes(
    string url, string method, object? body, HttpStatusCode expected)
{
    var request = new HttpRequestMessage(new HttpMethod(method), url);
    if (body is not null)
        request.Content = JsonContent.Create(body);

    var response = await _client.SendAsync(request);

    Assert.Equal(expected, response.StatusCode);
}

// Snapshot / golden file testing for response shape
[Fact]
public async Task GetTodo_ResponseMatchesExpectedShape()
{
    var response = await _client.GetAsync("/todos/1");
    var json = await response.Content.ReadAsStringAsync();

    // Verify required fields are present
    using var doc = JsonDocument.Parse(json);
    Assert.True(doc.RootElement.TryGetProperty("id", out _));
    Assert.True(doc.RootElement.TryGetProperty("title", out _));
    Assert.True(doc.RootElement.TryGetProperty("isComplete", out _));
}
```

## Common Follow-up Questions

- How do you test endpoint filters on Minimal APIs?
- How do `TypedResults` improve OpenAPI generation compared to `Results<T1, T2>`?
- How do you test a Minimal API with `IFormFile` (file upload)?
- What is the difference between `MapGet(...).WithMetadata(...)` and attribute-based metadata on controllers?
- How do you organize integration tests for a large Minimal API with 50+ endpoints?

## Common Mistakes / Pitfalls

- **Trying to unit-test inline lambdas** — lambdas in `MapGet/MapPost` are not directly testable; extract them to static methods or handler classes.
- **Not testing route group authorization** — route group `RequireAuthorization()` is applied at registration time; tests that skip auth may miss group-level policies.
- **Using `Results.Ok()` instead of `TypedResults.Ok()` when return type matters** — `Results.Ok()` returns `IResult` (type-erased), making the unit test assertion harder.
- **Not asserting `Location` header on `201 Created` responses** — `TypedResults.Created(uri, value)` should produce a valid `Location` header; omitting the assertion misses this contract.

## References

- [Microsoft Learn — Minimal APIs testing](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/test-min-api?view=aspnetcore-8.0)
- [Microsoft Learn — TypedResults](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/responses?view=aspnetcore-8.0#typedresults-vs-results)
- [Andrew Lock — Testing Minimal APIs](https://andrewlock.net/exploring-dotnet-6-preview-4-exploring-the-new-minimal-apis/) (verify URL)
