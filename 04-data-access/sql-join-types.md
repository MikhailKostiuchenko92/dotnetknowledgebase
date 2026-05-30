# SQL JOIN Types

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🟢 Junior
**Tags:** `SQL`, `JOIN`, `INNER JOIN`, `LEFT JOIN`, `CROSS JOIN`, `NULL`, `query`

## Question

> What are the different SQL JOIN types? What is the difference between `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`, and `FULL OUTER JOIN`? What does a `CROSS JOIN` produce, and when is it useful?

## Short Answer

`INNER JOIN` returns only rows where the join condition is satisfied in **both** tables. `LEFT JOIN` returns all rows from the left table plus matching rows from the right (NULLs for non-matching right columns). `RIGHT JOIN` is the mirror of LEFT. `FULL OUTER JOIN` returns all rows from both tables, with NULLs wherever there is no match. `CROSS JOIN` produces the Cartesian product — every row in the left table paired with every row in the right, with no join condition. The most common interview trap: confusing NULL-handling in `LEFT JOIN` filter conditions (`WHERE right.col = x` accidentally converts a LEFT to INNER JOIN).

## Detailed Explanation

### Visual Reference

Consider two tables:

```
Customers (A)     Orders (B)
----------        ----------
Id  Name          Id  CustomerId  Total
1   Alice         10  1           100
2   Bob           20  1           200
3   Carol         30  NULL (orphan — should not happen but illustrates CROSS/FULL)
```

### INNER JOIN

Returns rows with a match on **both sides**. Non-matching rows are excluded.

```sql
SELECT c.Name, o.Total
FROM Customers c
INNER JOIN Orders o ON o.CustomerId = c.Id;
-- Result: Alice 100, Alice 200 (Bob and Carol excluded — no orders)
```

### LEFT JOIN (LEFT OUTER JOIN)

Returns **all rows from the left table** + matching right rows. Right columns are NULL when there is no match.

```sql
SELECT c.Name, o.Total
FROM Customers c
LEFT JOIN Orders o ON o.CustomerId = c.Id;
-- Result: Alice 100, Alice 200, Bob NULL, Carol NULL
```

### RIGHT JOIN (RIGHT OUTER JOIN)

All rows from the **right table**, with left-side NULLs for non-matches. Rarely used — most queries can be expressed as `LEFT JOIN` by swapping table order (improves readability).

### FULL OUTER JOIN

All rows from **both tables**. NULLs wherever there is no match on either side.

```sql
SELECT c.Name, o.Total
FROM Customers c
FULL OUTER JOIN Orders o ON o.CustomerId = c.Id;
-- Returns all customers and all orders, including orphan orders if they exist
```

### CROSS JOIN

Cartesian product — every combination. No `ON` clause.

```sql
SELECT p.Name, s.Name AS Size
FROM Products p
CROSS JOIN Sizes s;
-- If 5 products × 3 sizes = 15 rows
```

**When useful**: generating combinations (e.g., products × sizes × colors for a configurator), or constructing date dimension tables.

### Common Trap: LEFT JOIN + WHERE Kills the Outer Join

```sql
-- Intended: all customers, even those without completed orders
SELECT c.Name, o.Total
FROM Customers c
LEFT JOIN Orders o ON o.CustomerId = c.Id
WHERE o.Status = 'Completed';  -- ❌ This converts LEFT to INNER JOIN!
-- Customers without any order have o.Status = NULL → NULL = 'Completed' = FALSE → excluded
```

```sql
-- ✅ Filter belongs in the ON clause to preserve the outer join
SELECT c.Name, o.Total
FROM Customers c
LEFT JOIN Orders o ON o.CustomerId = c.Id AND o.Status = 'Completed';
-- Customers without completed orders are returned with o.Total = NULL
```

### JOIN Comparison Table

| Type | Left rows | Right rows | Non-matching left | Non-matching right |
|------|-----------|------------|-------------------|--------------------|
| INNER | Only matched | Only matched | Excluded | Excluded |
| LEFT | All | Matched only | Included (NULL right) | Excluded |
| RIGHT | Matched only | All | Excluded | Included (NULL left) |
| FULL OUTER | All | All | Included (NULL right) | Included (NULL left) |
| CROSS | All × All | — | N/A (no condition) | N/A |

### EF Core JOIN Behavior

EF Core generates `INNER JOIN` for navigation properties by default:

```csharp
// INNER JOIN — requires every order to have a customer
var result = db.Orders
    .Join(db.Customers, o => o.CustomerId, c => c.Id,
          (o, c) => new { c.Name, o.Total })
    .ToList();

// LEFT JOIN — via optional navigation properties (EF Core uses LEFT JOIN automatically
// when the navigation is optional/nullable)
var result = db.Customers
    .Select(c => new
    {
        c.Name,
        Orders = c.Orders.Where(o => o.Status == "Completed").ToList()
    })
    .ToList();
// Generates LEFT JOIN automatically for optional collections
```

## Code Example

```csharp
// EF Core raw SQL for complex JOINs not easily expressed in LINQ
var report = await db.Database
    .SqlQuery<CustomerOrderSummary>($"""
        SELECT 
            c.Name,
            COUNT(o.Id) AS OrderCount,
            SUM(o.Total) AS TotalSpend
        FROM Customers c
        LEFT JOIN Orders o ON o.CustomerId = c.Id AND o.Status = 'Completed'
        GROUP BY c.Id, c.Name
        ORDER BY TotalSpend DESC
        """)
    .ToListAsync(ct);
```

## Common Follow-up Questions

- What is the difference between a JOIN condition in `ON` vs `WHERE`?
- How does SQL Server choose between a Nested Loop Join, Hash Join, and Merge Join in the execution plan?
- How does `EXISTS` vs `JOIN` vs `IN` differ for subquery filtering?
- What happens with a `LEFT JOIN` on a nullable FK column?
- How do self-JOINs work, and when would you use one?

## Common Mistakes / Pitfalls

- **Putting outer-join filters in `WHERE` instead of `ON`**: the most common LEFT JOIN mistake — filters in `WHERE` on the right table implicitly exclude NULL rows, converting it to an INNER JOIN.
- **RIGHT JOIN confusion**: almost all `RIGHT JOIN` queries can be rewritten as `LEFT JOIN` with tables swapped, which is more readable. Mixing LEFT and RIGHT joins in one query is hard to reason about.
- **CROSS JOIN on large tables**: 1000 rows × 1000 rows = 1 000 000 rows. Always include a `WHERE` clause to limit CROSS JOIN results unless a full Cartesian product is intentional.
- **Assuming JOIN order matters for output**: in ANSI SQL, INNER JOINs are commutative — the optimizer chooses the physical order. But explicit `LEFT JOIN` order does matter (left table drives which rows appear with NULLs).

## References

- [FROM clause plus JOIN, APPLY, PIVOT — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql)
- [Joins — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins)
- [See: query-execution-plan.md](./query-execution-plan.md)
- [See: indexes-overview.md](./indexes-overview.md)
