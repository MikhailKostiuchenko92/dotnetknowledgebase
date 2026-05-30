# Parameterized Queries and SQL Injection Prevention

**Category:** Data Access / ADO.NET
**Difficulty:** 🟢 Junior
**Tags:** `ADO.NET`, `SQL-injection`, `SqlParameter`, `parameterization`, `security`, `Dapper`, `EF-Core`

## Question

> What is SQL injection and how do parameterized queries prevent it? Demonstrate safe and unsafe patterns in ADO.NET, Dapper, and EF Core.

## Short Answer

SQL injection occurs when user-supplied input is concatenated directly into SQL strings, allowing attackers to manipulate the query structure. Parameterized queries prevent this by sending the SQL text and parameter values as separate protocol packets — the database never interprets parameter values as SQL syntax. In ADO.NET, use `SqlParameter` objects. In Dapper, pass parameters via anonymous objects or `DynamicParameters`. In EF Core, LINQ queries are always parameterized; raw SQL must use `FromSqlInterpolated` (not `FromSqlRaw` with string interpolation) or named parameters.

## Detailed Explanation

### How SQL Injection Works

```csharp
// ❌ UNSAFE — never do this
string username = "admin' OR '1'='1";
string sql = $"SELECT * FROM Users WHERE Username = '{username}'";
// Resulting SQL:
// SELECT * FROM Users WHERE Username = 'admin' OR '1'='1'
// ← Returns ALL users because '1'='1' is always true

// Even worse:
string input = "'; DROP TABLE Users; --";
// SELECT * FROM Users WHERE Username = ''; DROP TABLE Users; --'
// ← Drops the Users table!
```

### ADO.NET — SqlParameter

```csharp
// ✅ Safe: parameter value is never interpreted as SQL
await using var cmd = conn.CreateCommand();
cmd.CommandText = "SELECT * FROM Users WHERE Username = @Username AND PasswordHash = @Hash";
cmd.Parameters.Add(new SqlParameter("@Username", SqlDbType.NVarChar, 100) { Value = username });
cmd.Parameters.Add(new SqlParameter("@Hash", SqlDbType.NVarChar, 256) { Value = passwordHash });

// The malicious input becomes a literal string value:
// SELECT * FROM Users WHERE Username = N'admin'' OR ''1''=''1'
// ← Finds no match for the literal username (the attack is inert)
```

**Never use `AddWithValue` for untrusted input without specifying type/size** (it infers from the value and creates plan cache pollution):

```csharp
// Acceptable but non-ideal for production:
cmd.Parameters.AddWithValue("@Username", username);

// Preferred: explicit type prevents plan cache pollution
cmd.Parameters.Add(new SqlParameter("@Username", SqlDbType.NVarChar, 100) { Value = username });
```

### Dapper — Anonymous Objects (Always Parameterized)

Dapper's anonymous-object parameters are **always** sent as SQL parameters:

```csharp
// ✅ Safe
var user = await conn.QuerySingleOrDefaultAsync<User>(
    "SELECT * FROM Users WHERE Username = @Username",
    new { Username = username });  // ← @Username is a SqlParameter, not string concatenation

// ❌ UNSAFE — don't concatenate even in Dapper
var user = await conn.QuerySingleOrDefaultAsync<User>(
    $"SELECT * FROM Users WHERE Username = '{username}'");  // ← SQL injection
```

### EF Core — LINQ (Always Safe)

EF Core LINQ queries always generate parameterized SQL:

```csharp
// ✅ Safe — EF Core generates: WHERE Username = @__username_0
var user = await db.Users
    .FirstOrDefaultAsync(u => u.Username == username, ct);
```

### EF Core — Raw SQL (Careful!)

```csharp
// ✅ Safe: FromSqlInterpolated uses FormattableString — values become parameters
var users = db.Users.FromSqlInterpolated(
    $"SELECT * FROM Users WHERE Username = {username}");
// EF Core generates: SELECT * FROM Users WHERE Username = @p0 — @p0 = username

// ❌ UNSAFE: FromSqlRaw with string interpolation — bypasses parameterization
var users = db.Users.FromSqlRaw(
    $"SELECT * FROM Users WHERE Username = '{username}'");  // SQL injection!

// ✅ Safe: FromSqlRaw with explicit parameters
var users = db.Users.FromSqlRaw(
    "SELECT * FROM Users WHERE Username = {0}", username);  // index-based param
```

### Dynamic ORDER BY — The Edge Case

You cannot parameterize column names or sort directions — they're part of SQL syntax, not values:

```csharp
// ❌ UNSAFE — allowing arbitrary sort column from user input
string sortCol = Request.Query["sort"];  // user provides "Name; DROP TABLE Users--"
cmd.CommandText = $"SELECT * FROM Products ORDER BY {sortCol}";

// ✅ Safe — whitelist allowed columns
var allowedSortColumns = new HashSet<string> { "Name", "Price", "CreatedAt" };
if (!allowedSortColumns.Contains(sortCol))
    sortCol = "Name";  // fallback to safe default
cmd.CommandText = $"SELECT * FROM Products ORDER BY {sortCol}";  // now safe
```

## Code Example

```csharp
// Full safe login query in ADO.NET
public async Task<UserDto?> AuthenticateAsync(
    string username, string password, CancellationToken ct)
{
    // Hash the password in application code — never pass plaintext to DB
    var hash = _hasher.HashPassword(password);

    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    await using var cmd = conn.CreateCommand();
    cmd.CommandText = """
        SELECT Id, Username, Email, Role
        FROM Users
        WHERE Username = @Username
          AND PasswordHash = @Hash
          AND IsActive = 1
        """;
    cmd.Parameters.Add(new SqlParameter("@Username", SqlDbType.NVarChar, 100) { Value = username });
    cmd.Parameters.Add(new SqlParameter("@Hash", SqlDbType.NVarChar, 256) { Value = hash });

    await using var reader = await cmd.ExecuteReaderAsync(ct);
    if (!await reader.ReadAsync(ct)) return null;

    return new UserDto(
        reader.GetInt32(reader.GetOrdinal("Id")),
        reader.GetString(reader.GetOrdinal("Username")),
        reader.GetString(reader.GetOrdinal("Email")),
        reader.GetString(reader.GetOrdinal("Role")));
}
```

## Common Follow-up Questions

- Can parameterized queries prevent second-order SQL injection?
- How does EF Core protect against SQL injection in `FromSqlRaw` with index-based parameters (`{0}`, `{1}`)?
- What is a stored procedure's protection against SQL injection — and are dynamic SQL stored procedures still vulnerable?
- How do you safely build dynamic ORDER BY or dynamic column selection in ADO.NET or Dapper?
- What is blind SQL injection and how do parameterized queries prevent it?

## Common Mistakes / Pitfalls

- **String interpolation in `FromSqlRaw`**: `FromSqlRaw($"WHERE Name = '{name}'")`  — interpolation happens in C# before EF Core sees the string. The result is a raw SQL string with the value embedded. Use `FromSqlInterpolated` instead.
- **Trusting validated input**: Even if you validate that `username` contains only alphanumerics, always use parameters — validation can have edge cases; parameterization has none.
- **Dynamic column names without a whitelist**: Column and table names can't be parameterized. Always whitelist acceptable values from a known-safe set.
- **Stored procedures with internal `EXEC(@sql)`**: A stored procedure that builds dynamic SQL internally from its parameters is still vulnerable to SQL injection via that internal `EXEC`. Parameterizing the SP call doesn't help — you must fix the SP too.
- **Concatenating IN lists**: `WHERE Id IN ('` + string.Join("','", ids) + `')` is injection-vulnerable and fragile. Use a table-valued parameter, Dapper's automatic `IN` expansion, or `STRING_SPLIT`.

## References

- [SQL injection — OWASP](https://owasp.org/www-community/attacks/SQL_Injection)
- [SqlParameter — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlparameter)
- [EF Core raw SQL security — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/sql-queries#security)
- [See: adonet-overview.md](./adonet-overview.md)
- [See: raw-sql-in-ef-core.md](./raw-sql-in-ef-core.md)
