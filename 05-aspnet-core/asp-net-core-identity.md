# ASP.NET Core Identity

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🟡 Middle
**Tags:** `Identity`, `UserManager`, `SignInManager`, `RoleManager`, `PasswordHasher`, `custom-store`

## Question

> What are the core components of ASP.NET Core Identity? How do `UserManager<T>`, `SignInManager<T>`, and `RoleManager<T>` relate to each other?

## Short Answer

ASP.NET Core Identity is a membership system providing user registration, password hashing, login, roles, claims, and external provider login. `UserManager<TUser>` manages user CRUD and password/claim/role operations; `SignInManager<TUser>` handles sign-in flows (password, two-factor, external); `RoleManager<TRole>` manages roles. All three operate through `IUserStore<TUser>` and `IRoleStore<TRole>` abstractions, so you can swap the default EF Core stores for custom implementations (MongoDB, Redis, API-backed, etc.).

## Detailed Explanation

### Component responsibilities

| Component | Purpose | DI lifetime |
|---|---|---|
| `UserManager<TUser>` | User CRUD, password hash/verify, claims, roles, lockout | Scoped |
| `SignInManager<TUser>` | Password sign-in, 2FA, external login, cookie issuance | Scoped |
| `RoleManager<TRole>` | Role CRUD, role claims | Scoped |
| `IPasswordHasher<TUser>` | Hash and verify passwords (PBKDF2 by default) | Singleton |
| `IUserStore<TUser>` | Storage abstraction (EF Core, custom) | Scoped |

### Setup

```csharp
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddIdentity<ApplicationUser, IdentityRole>(opts =>
{
    // Password policy
    opts.Password.RequireDigit = true;
    opts.Password.RequiredLength = 12;
    opts.Password.RequireUppercase = true;
    opts.Password.RequireNonAlphanumeric = false;

    // Lockout
    opts.Lockout.MaxFailedAccessAttempts = 5;
    opts.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);

    // User
    opts.User.RequireUniqueEmail = true;
    opts.SignIn.RequireConfirmedEmail = true;
})
.AddEntityFrameworkStores<AppDbContext>()
.AddDefaultTokenProviders();
```

> **Note:** `AddIdentity<TUser, TRole>` registers cookie authentication by default. For APIs using JWT, use `AddIdentityCore<TUser>` instead — it does not add cookie auth.

### Common `UserManager<T>` operations

```csharp
// Create user
var result = await userManager.CreateAsync(new ApplicationUser { Email = email, UserName = email }, password);
if (!result.Succeeded) throw new ValidationException(result.Errors.Select(e => e.Description));

// Find user
var user = await userManager.FindByEmailAsync(email);

// Add role
await userManager.AddToRoleAsync(user, "Admin");

// Add claim
await userManager.AddClaimAsync(user, new Claim("department", "engineering"));

// Change password
var result = await userManager.ChangePasswordAsync(user, currentPassword, newPassword);

// Generate email confirmation token
var token = await userManager.GenerateEmailConfirmationTokenAsync(user);
await userManager.ConfirmEmailAsync(user, token);
```

### `SignInManager<T>` — sign-in flows

```csharp
// Password sign-in
var result = await signInManager.PasswordSignInAsync(email, password,
    isPersistent: rememberMe, lockoutOnFailure: true);

if (result.Succeeded) { /* proceed */ }
else if (result.IsLockedOut) { /* show lockout page */ }
else if (result.RequiresTwoFactor) { /* redirect to 2FA */ }
else { /* invalid credentials */ }

// Sign out
await signInManager.SignOutAsync();

// External login (Google, GitHub)
var info = await signInManager.GetExternalLoginInfoAsync();
var result = await signInManager.ExternalLoginSignInAsync(
    info.LoginProvider, info.ProviderKey, isPersistent: false);
```

### Custom `IdentityUser` properties

```csharp
public sealed class ApplicationUser : IdentityUser
{
    public string? DisplayName { get; set; }
    public string? Department { get; set; }
    public DateTimeOffset? LastLoginAt { get; set; }
}
```

Add to `AppDbContext`:

```csharp
protected override void OnModelCreating(ModelBuilder builder)
{
    base.OnModelCreating(builder);
    builder.Entity<ApplicationUser>().Property(u => u.DisplayName).HasMaxLength(100);
}
```

### Custom `IUserStore` (non-EF Core)

```csharp
public sealed class MongoUserStore : IUserStore<ApplicationUser>, IUserPasswordStore<ApplicationUser>
{
    // Implement all IUserStore members
    public Task<IdentityResult> CreateAsync(ApplicationUser user, CancellationToken ct) { ... }
    public Task<string?> GetPasswordHashAsync(ApplicationUser user, CancellationToken ct) { ... }
    // ... other members
}

// Registration (instead of AddEntityFrameworkStores)
builder.Services.AddIdentityCore<ApplicationUser>()
    .AddUserStore<MongoUserStore>()
    .AddDefaultTokenProviders();
```

## Code Example

```csharp
// Registration endpoint (minimal API)
app.MapPost("/auth/register", async (
    RegisterRequest req,
    UserManager<ApplicationUser> userManager) =>
{
    var user = new ApplicationUser { Email = req.Email, UserName = req.Email };
    var result = await userManager.CreateAsync(user, req.Password);

    if (!result.Succeeded)
        return TypedResults.ValidationProblem(
            result.Errors.ToDictionary(e => e.Code, e => new[] { e.Description }));

    return TypedResults.Created($"/users/{user.Id}", new { user.Id, user.Email });
});

// Login endpoint
app.MapPost("/auth/login", async (
    LoginRequest req,
    SignInManager<ApplicationUser> signInManager,
    ITokenService tokens) =>
{
    var result = await signInManager.PasswordSignInAsync(
        req.Email, req.Password, isPersistent: false, lockoutOnFailure: true);

    return result switch
    {
        { Succeeded: true } => TypedResults.Ok(new { Token = tokens.GenerateFor(signInManager.UserManager
                .FindByEmailAsync(req.Email).GetAwaiter().GetResult()!) }),
        { IsLockedOut: true } => TypedResults.Problem("Account locked out", statusCode: 429),
        _ => TypedResults.Problem("Invalid credentials", statusCode: 401)
    };
});
```

## Common Follow-up Questions

- What is the difference between `AddIdentity<T>` and `AddIdentityCore<T>`?
- How does `IPasswordHasher<TUser>` work, and can you replace it with Argon2?
- What is a security stamp and when is it regenerated?
- How do you implement two-factor authentication with TOTP?
- How do you migrate from ASP.NET Membership to ASP.NET Core Identity?

## Common Mistakes / Pitfalls

- **Using `AddIdentity<T>` for API-only projects** — it adds cookie auth middleware automatically; use `AddIdentityCore<T>` for APIs that issue JWT tokens instead.
- **Not awaiting `UserManager` methods properly** — `UserManager` methods are all async; calling them synchronously with `.Result` can cause deadlocks in some hosting contexts.
- **Storing passwords in custom claims** — never store sensitive data in claims; claims are stored in the cookie/token and may be logged.
- **Not setting `RequireConfirmedEmail = true` in production** — without email confirmation, anyone can register with any email address.
- **Calling `CreateAsync` without checking the result** — Identity returns `IdentityResult`; ignoring it means silent failures (e.g., password policy violation, duplicate user) go unhandled.

## References

- [Microsoft Learn — ASP.NET Core Identity](https://learn.microsoft.com/aspnet/core/security/authentication/identity?view=aspnetcore-8.0)
- [Microsoft Learn — Custom storage providers for Identity](https://learn.microsoft.com/aspnet/core/security/authentication/identity-custom-storage-providers?view=aspnetcore-8.0)
- [Microsoft Learn — Identity configuration](https://learn.microsoft.com/aspnet/core/security/authentication/identity-configuration?view=aspnetcore-8.0)
- [Microsoft — UserManager source](https://github.com/dotnet/aspnetcore/blob/main/src/Identity/Core/src/UserManager.cs)
