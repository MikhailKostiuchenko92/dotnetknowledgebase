# How Do `[TestInitialize]` and `[ClassInitialize]` Differ in MSTest?

**Category:** Testing / MSTest
**Difficulty:** 🟡 Middle
**Tags:** `mstest`, `[TestInitialize]`, `[ClassInitialize]`, `test-lifecycle`, `setup`

## Question
> How do `[TestInitialize]` and `[ClassInitialize]` differ in MSTest?

## Short Answer
`[TestInitialize]` runs before **each individual test** and is an instance method. `[ClassInitialize]` runs **once before all tests** in the class and must be a `static` method accepting a `TestContext` parameter. The difference mirrors NUnit's `[SetUp]` vs. `[OneTimeSetUp]`.

## Detailed Explanation

### Execution Model Comparison

```
[ClassInitialize]
  ├── [TestInitialize] → Test1 → [TestCleanup]
  ├── [TestInitialize] → Test2 → [TestCleanup]
  └── [TestInitialize] → Test3 → [TestCleanup]
[ClassCleanup]
```

### `[TestInitialize]`
- **Instance method** — runs on the same object instance as the test.
- Runs before **every** test method in the class.
- Used to reset mutable fields, recreate mocks, or re-initialize the SUT.
- Supports `async Task` (MSTest v2.2+).

```csharp
[TestInitialize]
public void SetUp()
{
    _mock = new Mock<IService>();
    _sut = new Controller(_mock.Object);
}
```

### `[ClassInitialize]`
- **Static method** with a `TestContext ctx` parameter (required signature).
- Runs **once** before the first test in the class.
- Used for expensive one-time setup: database schema creation, server startup.
- Supports `async Task` (MSTest v2.2+).

```csharp
[ClassInitialize]
public static async Task ClassSetUp(TestContext ctx)
{
    _db = await CreateTestDatabaseAsync();
}
```

### `[TestCleanup]` and `[ClassCleanup]`
Mirror the initialize attributes:
- `[TestCleanup]` — after each test (instance method).
- `[ClassCleanup]` — after all tests (static method, no `TestContext` required).

### Key Differences

| Attribute | Scope | Method type | Async | Parameter |
|---|---|---|---|---|
| `[TestInitialize]` | Per test | Instance | Supported | None |
| `[TestCleanup]` | Per test | Instance | Supported | None |
| `[ClassInitialize]` | Per class | Static | Supported | `TestContext` required |
| `[ClassCleanup]` | Per class | Static | Supported | None |
| `[AssemblyInitialize]` | Per assembly | Static | Supported | `TestContext` required |

### Instance Reuse in MSTest
Like NUnit, MSTest creates **one instance** of the test class per class (not per test method). All test methods share the same instance. This means:
- Instance fields retain values between tests.
- `[TestInitialize]` must explicitly reset fields that should be fresh per test.

> 💡 xUnit's model (new instance per test) avoids this entire class of bug.

### Inheritance
If a base class has `[TestInitialize]`, it runs **before** the derived class's `[TestInitialize]`. Reverse order for cleanup.

## Code Example
```csharp
namespace Api.Tests;

[TestClass]
public class UserServiceTests
{
    // Shared expensive resource — created once
    private static AppDbContext _sharedDb = null!;

    // Per-test resource — fresh each time
    private UserService _sut = null!;
    private Mock<IEmailSender> _emailSender = null!;

    // Runs ONCE — set up shared read-only database
    [ClassInitialize]
    public static async Task ClassSetUp(TestContext ctx)
    {
        ctx.WriteLine("Creating test database...");
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite("DataSource=:memory:")
            .Options;
        _sharedDb = new AppDbContext(options);
        await _sharedDb.Database.EnsureCreatedAsync();
        // Seed read-only reference data
        _sharedDb.Roles.Add(new Role { Name = "Admin" });
        await _sharedDb.SaveChangesAsync();
    }

    // Runs BEFORE EACH TEST — fresh mocks and SUT
    [TestInitialize]
    public void SetUp()
    {
        _emailSender = new Mock<IEmailSender>();
        _sut = new UserService(_sharedDb, _emailSender.Object);
    }

    [TestMethod]
    public async Task CreateUser_WithAdminRole_PersistsUser()
    {
        await _sut.CreateAsync(new CreateUserRequest { Name = "Alice", Role = "Admin" });
        Assert.AreEqual(1, _sharedDb.Users.Count());
    }

    [TestMethod]
    public async Task CreateUser_SendsWelcomeEmail()
    {
        await _sut.CreateAsync(new CreateUserRequest { Name = "Bob", Role = "Admin" });
        _emailSender.Verify(s => s.SendWelcomeAsync(It.IsAny<string>()), Times.Once);
    }

    // Runs AFTER EACH TEST — remove test-specific data
    [TestCleanup]
    public void TearDown()
    {
        // Remove any users created by this test
        _sharedDb.Users.RemoveRange(_sharedDb.Users.ToList());
        _sharedDb.SaveChanges();
    }

    // Runs ONCE — release shared resource
    [ClassCleanup]
    public static async Task ClassTearDown()
    {
        await _sharedDb.DisposeAsync();
    }
}
```

## Common Follow-up Questions
- What is the xUnit equivalent of `[ClassInitialize]`?
- How does MSTest's instance reuse compare to xUnit's per-instance model?
- Can `[ClassInitialize]` be inherited from a base class?
- What happens if `[ClassInitialize]` throws?
- How do you write async `[TestInitialize]`?
- What is `[AssemblyInitialize]` and when would you use it?

## Common Mistakes / Pitfalls
- **`[ClassInitialize]` on an instance method** — must be `static`; non-static causes a `TestClassException` at runtime.
- **Missing `TestContext` parameter on `[ClassInitialize]`** — the parameter is required (even if unused); omitting it causes a discovery error.
- **Not reinitialising fields in `[TestInitialize]`** — since MSTest reuses the instance, state from test N leaks into test N+1.
- **Mutating `[ClassInitialize]` data in tests** — shared data must be treated as read-only, or reset in `[TestCleanup]`.
- **`async void` initialize methods** — silently swallows exceptions; always use `async Task` (MSTest v2.2+).

## References
- [Microsoft Learn — TestInitialize attribute](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.testtools.unittesting.testinitializeattribute)
- [Microsoft Learn — ClassInitialize attribute](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.testtools.unittesting.classinitializeattribute)
- [Microsoft Learn — Unit testing with MSTest](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-mstest)
- [MSTest GitHub — TestFramework](https://github.com/microsoft/testfx)
