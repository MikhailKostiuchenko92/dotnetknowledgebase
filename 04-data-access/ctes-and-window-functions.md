# CTEs and Window Functions in SQL

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🟡 Middle
**Tags:** `SQL`, `CTE`, `window-functions`, `ROW_NUMBER`, `RANK`, `LAG`, `LEAD`, `OVER`, `PARTITION BY`

## Question

> What is a Common Table Expression (CTE) and when would you use one over a subquery? What are window functions, and how do `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `LAG()`, and `LEAD()` work? What are common interview patterns that require these constructs?

## Short Answer

A **CTE** (introduced with `WITH`) is a named temporary result set for the duration of one query — it improves readability, enables recursive queries, and can be referenced multiple times. It does **not** materialize to disk by default; SQL Server may inline it or create a spool. **Window functions** compute a value across a set of rows related to the current row without collapsing them into a single group. `ROW_NUMBER` assigns unique sequential numbers; `RANK` allows ties with gaps; `DENSE_RANK` allows ties without gaps; `LAG`/`LEAD` access values from previous/next rows in the ordered window.

## Detailed Explanation

### Common Table Expressions (CTEs)

```sql
-- Basic CTE — cleaner than a nested subquery
WITH RecentOrders AS (
    SELECT CustomerId, SUM(Total) AS TotalSpend
    FROM Orders
    WHERE CreatedAt >= DATEADD(month, -3, GETUTCDATE())
    GROUP BY CustomerId
)
SELECT c.Name, ro.TotalSpend
FROM Customers c
JOIN RecentOrders ro ON ro.CustomerId = c.Id
ORDER BY ro.TotalSpend DESC;
```

**vs subquery equivalent** — functionally identical but harder to read:
```sql
SELECT c.Name, ro.TotalSpend
FROM Customers c
JOIN (
    SELECT CustomerId, SUM(Total) AS TotalSpend
    FROM Orders
    WHERE CreatedAt >= DATEADD(month, -3, GETUTCDATE())
    GROUP BY CustomerId
) ro ON ro.CustomerId = c.Id
ORDER BY ro.TotalSpend DESC;
```

**Multiple CTEs — chain them**:
```sql
WITH 
ActiveCustomers AS (
    SELECT Id FROM Customers WHERE Status = 'Active'
),
CustomerOrders AS (
    SELECT c.Id, COUNT(o.Id) AS OrderCount
    FROM ActiveCustomers c
    LEFT JOIN Orders o ON o.CustomerId = c.Id
    GROUP BY c.Id
)
SELECT * FROM CustomerOrders WHERE OrderCount > 5;
```

**Recursive CTE — common for hierarchical data**:
```sql
WITH OrgChart AS (
    -- Anchor: top-level employees
    SELECT Id, Name, ManagerId, 0 AS Level
    FROM Employees
    WHERE ManagerId IS NULL

    UNION ALL

    -- Recursive: find reports for each level
    SELECT e.Id, e.Name, e.ManagerId, oc.Level + 1
    FROM Employees e
    INNER JOIN OrgChart oc ON oc.Id = e.ManagerId
)
SELECT * FROM OrgChart ORDER BY Level, Name
OPTION (MAXRECURSION 50);  -- safety limit; default is 100
```

### Window Functions

Window functions use `OVER(PARTITION BY ... ORDER BY ...)` to define the "window" of rows.

```
FUNCTION_NAME() OVER (
    [PARTITION BY partition_columns]   -- optional: reset per group
    [ORDER BY order_columns]           -- required for ranking/lead/lag
    [ROWS/RANGE BETWEEN ...]           -- optional: frame size
)
```

#### Ranking Functions

```sql
SELECT 
    OrderId,
    CustomerId,
    Total,
    -- Unique sequential number within each customer's orders by date
    ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY CreatedAt) AS RowNum,

    -- Rank with gaps: 1, 1, 3, 4 (two rows tie for 1st, next is 3rd)
    RANK()       OVER (PARTITION BY CustomerId ORDER BY Total DESC) AS Rank,

    -- Rank without gaps: 1, 1, 2, 3
    DENSE_RANK() OVER (PARTITION BY CustomerId ORDER BY Total DESC) AS DenseRank

FROM Orders;
```

**Classic interview pattern — "latest record per group"**:
```sql
-- Get the most recent order per customer
WITH Ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY CreatedAt DESC) AS rn
    FROM Orders
)
SELECT * FROM Ranked WHERE rn = 1;
```

#### LAG and LEAD — Row-to-Row Comparisons

```sql
SELECT 
    OrderDate,
    Total,
    -- Previous row's Total (NULL if no previous row)
    LAG(Total, 1, 0)  OVER (ORDER BY OrderDate) AS PrevTotal,

    -- Next row's Total (NULL if no next row)
    LEAD(Total, 1, 0) OVER (ORDER BY OrderDate) AS NextTotal,

    -- Month-over-month growth
    Total - LAG(Total, 1, 0) OVER (ORDER BY OrderDate) AS Growth
FROM MonthlyRevenue;
```

#### Aggregate Window Functions — Running Totals

```sql
SELECT 
    OrderDate,
    Total,
    -- Cumulative sum up to and including current row
    SUM(Total) OVER (ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal,

    -- 3-month moving average
    AVG(Total) OVER (ORDER BY OrderDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg3
FROM MonthlyRevenue;
```

## Code Example

```csharp
// EF Core 8 — execute window function query via raw SQL + SqlQuery<T>
// (EF Core doesn't translate window functions from LINQ)
var ranked = await db.Database
    .SqlQuery<CustomerOrderRank>($"""
        WITH Ranked AS (
            SELECT 
                CustomerId,
                OrderId,
                Total,
                CreatedAt,
                ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY CreatedAt DESC) AS RowNum
            FROM Orders
            WHERE Status = 'Completed'
        )
        SELECT CustomerId, OrderId, Total, CreatedAt
        FROM Ranked
        WHERE RowNum = 1
        """)
    .ToListAsync(ct);
```

## Common Follow-up Questions

- What is the difference between a CTE and a temporary table — does a CTE always avoid a table write?
- When does SQL Server materialize a CTE with a spool vs inline it?
- How does `NTILE(n)` differ from `ROW_NUMBER`?
- Can you use window functions in a `WHERE` clause? Why or why not?
- How would you calculate a year-over-year change using `LAG`?

## Common Mistakes / Pitfalls

- **Using window functions in `WHERE` clauses directly**: window functions are evaluated after `WHERE` — you must wrap in a subquery or CTE to filter on the result: `WHERE rn = 1` in a CTE is valid; `WHERE ROW_NUMBER() = 1` in the same query is not.
- **Forgetting `PARTITION BY`**: without `PARTITION BY`, the function runs over the entire result set. `ROW_NUMBER() OVER (ORDER BY Total)` numbers all rows globally, not per customer.
- **CTE vs temp table performance**: for large intermediate results referenced more than once in a complex plan, a temporary table may outperform a CTE because SQL Server won't re-scan the data.
- **MAXRECURSION on recursive CTEs**: the default recursion limit is 100. Deeply nested hierarchies (org charts, file trees) need `OPTION (MAXRECURSION N)` — and should have a cycle-detection guard.

## References

- [WITH common_table_expression — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)
- [Window functions — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/functions/ranking-functions-transact-sql)
- [OVER clause — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)
- [See: complex-query-patterns.md](./complex-query-patterns.md)
- [See: pagination-sql.md](./pagination-sql.md)
