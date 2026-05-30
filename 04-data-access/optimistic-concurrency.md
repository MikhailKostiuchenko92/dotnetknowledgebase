# Optimistic Concurrency in EF Core

**Category:** Data Access / Transactions
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `optimistic-concurrency`, `rowversion`, `DbUpdateConcurrencyException`, `last-write-wins`, `retry`

## Question

> How do you implement optimistic concurrency control in EF Core? What happens when two users update the same record simultaneously, and what strategies exist for resolving the conflict?

## Short Answer

Optimistic concurrency in EF Core is implemented via concurrency tokens — typically a `rowversion`/`[Timestamp]` column. EF Core adds the token's original value to every UPDATE/DELETE WHERE clause. If zero rows are affected (another process changed the row), EF Core throws `DbUpdateConcurrencyException`. Resolution strategies are: **database-wins** (reload and discard client changes), **client-wins** (overwrite with client values after refreshing the token), and **merge** (apply non-conflicting changes, raise an error for conflicting fields). The right choice depends on business rules — financial data typically uses database-wins or merge; optimistic "last edit wins" for non-critical content uses client-wins.

## Detailed Explanation

### Setup: rowversion Column

```csharp
public class Article
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string Author { get; set; } = "";

    [Timestamp]
    public byte[] RowVersion { get; set; } = [];  // SQL Server auto-increments on every write
}
```

Fluent API equivalent:
```csharp
modelBuilder.Entity<Article>()
    .Property(a => a.RowVersion)
    .IsRowVersion();
```

### What EF Core Generates

```sql
-- Normal UPDATE without conflict
UPDATE Articles SET Title = @title, Body = @body
WHERE Id = @id AND RowVersion = @originalRowVersion

-- If 0 rows affected → DbUpdateConcurrencyException
```

### Handling the Exception

```csharp
try
{
    await db.SaveChangesAsync(ct);
}
catch (DbUpdateConcurrencyException ex)
{
    var entry = ex.Entries.Single();
    var dbValues = await entry.GetDatabaseValuesAsync(ct);

    if (dbValues is null)
    {
        // Row was deleted — can't resolve automatically
        throw new ConflictException("The record was deleted by another user.");
    }

    // Choose strategy:
    ApplyDatabaseWinsStrategy(entry, dbValues);
    // or: ApplyClientWinsStrategy(entry, dbValues);
    // or: ApplyMergeStrategy(entry, dbValues);

    await db.SaveChangesAsync(ct);  // retry with updated state
}

// Strategy 1: Database wins — discard client changes
static void ApplyDatabaseWinsStrategy(EntityEntry entry, PropertyValues dbValues)
{
    entry.OriginalValues.SetValues(dbValues);  // update original (rowversion) to current DB
    entry.CurrentValues.SetValues(dbValues);   // discard client changes entirely
    // Entity is now Unchanged with DB values
}

// Strategy 2: Client wins — our changes overwrite the DB
static void ApplyClientWinsStrategy(EntityEntry entry, PropertyValues dbValues)
{
    entry.OriginalValues.SetValues(dbValues);  // update rowversion to current DB value
    // CurrentValues (our changes) stay unchanged → will be persisted on retry
}

// Strategy 3: Merge — keep non-conflicting fields from both
static void ApplyMergeStrategy(EntityEntry entry, PropertyValues dbValues)
{
    var proposed = entry.CurrentValues.Clone();
    var original = entry.OriginalValues.Clone();

    entry.OriginalValues.SetValues(dbValues);  // advance the rowversion
    entry.CurrentValues.SetValues(dbValues);   // start from DB state

    foreach (var prop in entry.Properties)
    {
        var proposedVal = proposed[prop.Metadata.Name];
        var originalVal = original[prop.Metadata.Name];
        var dbVal = dbValues[prop.Metadata.Name];

        // If client changed it AND DB also changed it → real conflict
        if (!Equals(proposedVal, originalVal) && !Equals(dbVal, originalVal))
            throw new ConflictException($"Concurrent modification conflict on '{prop.Metadata.Name}'");

        // If only client changed it → apply client change
        if (!Equals(proposedVal, originalVal))
            entry.CurrentValues[prop.Metadata.Name] = proposedVal;
        // Otherwise → keep DB value (already set above)
    }
}
```

### Disconnected Scenario (Web API)

The client must send back the original `RowVersion` in the request:

```csharp
// GET: return RowVersion as Base64
public record ArticleDto(int Id, string Title, string Body, string RowVersion);

var article = await db.Articles.FindAsync(id, ct);
return new ArticleDto(article.Id, article.Title, article.Body,
    Convert.ToBase64String(article.RowVersion));

// PUT: client sends RowVersion back
[HttpPut("{id}")]
public async Task<IActionResult> UpdateAsync(int id, UpdateArticleRequest req, CancellationToken ct)
{
    var article = await db.Articles.FindAsync([id], ct)
        ?? throw new NotFoundException(id);

    // Restore original rowversion so WHERE clause matches
    db.Entry(article).Property(a => a.RowVersion).OriginalValue =
        Convert.FromBase64String(req.RowVersion);

    article.Title = req.Title;
    article.Body = req.Body;

    try
    {
        await db.SaveChangesAsync(ct);
        return NoContent();
    }
    catch (DbUpdateConcurrencyException)
    {
        return Conflict(new ProblemDetails
        {
            Title = "Concurrency conflict",
            Detail = "The article was modified by another user. Please reload and retry."
        });
    }
}
```

## Code Example

```csharp
// Retry loop with last-write-wins for non-critical content
public async Task UpdateArticleAsync(int id, string newTitle, string newBody, CancellationToken ct)
{
    const int maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++)
    {
        var article = await db.Articles.FindAsync([id], ct)
            ?? throw new NotFoundException(id);

        article.Title = newTitle;
        article.Body = newBody;

        try
        {
            await db.SaveChangesAsync(ct);
            return;
        }
        catch (DbUpdateConcurrencyException) when (attempt < maxRetries - 1)
        {
            // Re-query fresh data and retry
            db.Entry(article).State = EntityState.Detached;
            // Loop continues with fresh load
        }
    }

    throw new ConflictException("Failed to update article after multiple retries.");
}
```

## Common Follow-up Questions

- How does `DbUpdateConcurrencyException.Entries` help you identify which specific entity conflicted?
- Can you configure optimistic concurrency on a property other than a rowversion (e.g., an integer version counter)?
- What happens if the transaction rolls back after `GetDatabaseValuesAsync` — can you still use those values?
- How does optimistic concurrency interact with EF Core's `ExecuteUpdateAsync`?
- Is the merge strategy practical to implement generically for all entities?

## Common Mistakes / Pitfalls

- **Not calling `entry.OriginalValues.SetValues(dbValues)` before retrying**: Without updating the original rowversion, the retry `SaveChanges` will fail immediately with the same exception — infinite failure loop.
- **Silently ignoring `DbUpdateConcurrencyException`**: Some developers catch the exception and succeed without resolving it — the changes are lost silently. Always apply a resolution strategy and retry, or surface the conflict to the user.
- **Using client-wins for financial or inventory data**: Overwriting DB values with client values can produce incorrect totals or negative inventory in concurrent scenarios. Use database-wins or merge for critical data.
- **Forgetting that `GetDatabaseValuesAsync` issues a SELECT**: This is an additional database round-trip. In a high-conflict scenario, the conflict resolution path can be expensive.
- **Not exposing RowVersion in the API response**: If the client doesn't receive the `RowVersion`, they can't send it back — all PUT requests will always fail the concurrency check in disconnected scenarios.

## References

- [Optimistic concurrency — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/concurrency)
- [Resolving concurrency conflicts — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/concurrency#resolving-concurrency-conflicts)
- [See: concurrency-tokens.md](./concurrency-tokens.md)
- [See: transaction-basics.md](./transaction-basics.md)
