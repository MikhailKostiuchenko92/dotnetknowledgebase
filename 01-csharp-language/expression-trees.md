# Expression Trees

**Category:** C# / Delegates, Events, Lambdas
**Difficulty:** Senior
**Tags:** `expression-tree`, `Expression<Func<T>>`, `LINQ`, `EF-Core`, `dynamic-query`

## Question

> What is an expression tree in C#? How does `Expression<Func<T>>` differ from `Func<T>`, and how does Entity Framework Core use expression trees to translate LINQ queries to SQL?

Also asked as:
- "What happens at runtime when you pass a lambda as `Expression<Func<T>>` versus `Func<T>`?"
- "How would you build an expression tree dynamically to compose a query at runtime?"

## Short Answer

An expression tree is a data structure that represents code as inspectable objects rather than executable IL. When a lambda is assigned to `Expression<Func<T>>`, the compiler emits calls to `System.Linq.Expressions` factory methods that construct a tree of `Expression` nodes — no IL is emitted for the lambda body. Entity Framework Core walks this tree and translates each node into SQL. Assigning the same lambda to `Func<T>` produces compiled IL that executes directly but cannot be inspected or translated.

## Detailed Explanation

### Expression Tree vs Compiled Delegate

```csharp
Func<int, bool>            compiled    = x => x > 5;  // emits CIL, runs in-process
Expression<Func<int, bool>> tree       = x => x > 5;  // emits Expression.Lambda(...)
```

| | `Func<T>` | `Expression<Func<T>>` |
|---|---|---|
| Stored as | Compiled native code | Object graph (AST) |
| Can execute in-process | ✅ `.Invoke(...)` | ✅ `.Compile().Invoke(...)` |
| Can be inspected/walked | ❌ opaque | ✅ traverse `.Body`, `.Parameters` |
| Can be translated (SQL, JS, etc.) | ❌ | ✅ |
| Runtime allocation | Delegate object | Tree of `Expression` nodes (heap) |
| Supports closures / captured vars | ✅ | ✅ (as `ConstantExpression`) |
| Supports `async`/`await` | ✅ | ❌ cannot express `await` as a tree |

### Anatomy of an Expression Tree

For `x => x > 5` the compiler builds:

```
LambdaExpression
  Parameters: [ ParameterExpression("x", typeof(int)) ]
  Body: BinaryExpression (GreaterThan)
    Left:  ParameterExpression("x")
    Right: ConstantExpression(5, typeof(int))
```

Every node is a subclass of `System.Linq.Expressions.Expression`. Key node types:

| Node | Meaning |
|---|---|
| `ParameterExpression` | A named parameter |
| `ConstantExpression` | A literal value |
| `BinaryExpression` | `+`, `>`, `&&`, etc. |
| `MemberExpression` | Property/field access: `x.Name` |
| `MethodCallExpression` | `string.Contains(...)` |
| `LambdaExpression` | The whole lambda |
| `NewExpression` | `new T(args)` |
| `ConditionalExpression` | `? :` ternary |

### How EF Core Uses Expression Trees

When you write:

```csharp
dbContext.Products
    .Where(p => p.Price > 100 && p.Category == "Books")
    .Select(p => new { p.Name, p.Price })
```

EF Core receives an `IQueryable<T>` whose internal state is a chain of `Expression` nodes. The EF Core query pipeline:

1. Calls `ExpressionVisitor` subclasses to normalize, validate, and expand the tree.
2. Translates each `MemberExpression` to a column reference, each `BinaryExpression` to a SQL operator, `MethodCallExpression` nodes to SQL functions (`LIKE`, `LOWER`, etc.).
3. Emits parameterized SQL like `SELECT Name, Price FROM Products WHERE Price > @p1 AND Category = @p2`.

If EF Core encounters an expression it cannot translate (e.g., a custom method call, `DateTime.Now` comparison via a non-supported path), it either throws at query build time or falls back to client evaluation — a silent performance hazard in older EF versions. EF Core 3+ throws by default when server translation fails.

### Building Expression Trees Programmatically

Use the `Expression` static factory methods:

```csharp
// Build: x => x.Name.StartsWith(prefix)
ParameterExpression param   = Expression.Parameter(typeof(Product), "x");
MemberExpression nameProp   = Expression.Property(param, nameof(Product.Name));
ConstantExpression prefixConst = Expression.Constant("Book", typeof(string));
MethodInfo startsWithMethod = typeof(string).GetMethod(nameof(string.StartsWith), [typeof(string)])!;
MethodCallExpression call   = Expression.Call(nameProp, startsWithMethod, prefixConst);

Expression<Func<Product, bool>> predicate =
    Expression.Lambda<Func<Product, bool>>(call, param);

// Now usable in EF Core:
var books = dbContext.Products.Where(predicate).ToList();
```

This technique powers dynamic query builders, specification patterns, and ORM helper libraries like LinqKit.

### Compiling an Expression Tree at Runtime

```csharp
Expression<Func<int, int>> expr = x => x * x;
Func<int, int> squareFn = expr.Compile();   // JIT-compiles the tree to native code
Console.WriteLine(squareFn(6));             // 36
```

> **Warning:** `Compile()` is expensive (~microseconds). Cache the compiled delegate; never call `Compile()` inside a hot loop.

### ExpressionVisitor — Walking and Modifying Trees

Subclass `ExpressionVisitor` to inspect or rewrite trees:

```csharp
public class ColumnPrefixVisitor : ExpressionVisitor
{
    protected override Expression VisitMember(MemberExpression node)
    {
        Console.WriteLine($"Accessing: {node.Member.Name}");
        return base.VisitMember(node);
    }
}
```

EF Core's entire query translation pipeline is built on `ExpressionVisitor` subclasses.

## Code Example

```csharp
using System;
using System.Linq.Expressions;

record Product(string Name, decimal Price, string Category);

// --- Inspecting a compiler-generated tree ---
Expression<Func<Product, bool>> filter = p => p.Price > 100m && p.Category == "Books";

Console.WriteLine(filter);
// p => ((p.Price > 100) AndAlso (p.Category == "Books"))

// Walk the tree manually
var binary = (BinaryExpression)filter.Body;         // AndAlso
Console.WriteLine(binary.NodeType);                  // AndAlso
Console.WriteLine(((BinaryExpression)binary.Left).NodeType);  // GreaterThan

// --- Compile and execute ---
Func<Product, bool> compiled = filter.Compile();
var p1 = new Product("C# in Depth", 150m, "Books");
var p2 = new Product("Notebook", 5m, "Office");
Console.WriteLine(compiled(p1));   // True
Console.WriteLine(compiled(p2));   // False

// --- Build a tree dynamically (runtime predicate) ---
static Expression<Func<Product, bool>> PriceBetween(decimal min, decimal max)
{
    ParameterExpression param = Expression.Parameter(typeof(Product), "p");
    MemberExpression priceProp = Expression.Property(param, nameof(Product.Price));

    BinaryExpression gteMin = Expression.GreaterThanOrEqual(
        priceProp, Expression.Constant(min));
    BinaryExpression lteMax = Expression.LessThanOrEqual(
        priceProp, Expression.Constant(max));

    BinaryExpression both = Expression.AndAlso(gteMin, lteMax);
    return Expression.Lambda<Func<Product, bool>>(both, param);
}

var range = PriceBetween(50m, 200m);
Console.WriteLine(range);
// p => ((p.Price >= 50) AndAlso (p.Price <= 200))

var products = new[] { p1, p2 }.AsQueryable().Where(range).ToArray();
Console.WriteLine(products.Length);   // 1 (p1)

// --- ExpressionVisitor: log property accesses ---
public class PropertyLogger : ExpressionVisitor
{
    protected override Expression VisitMember(MemberExpression node)
    {
        Console.WriteLine($"  Property accessed: {node.Member.Name}");
        return base.VisitMember(node);
    }
}

new PropertyLogger().Visit(filter);
// Property accessed: Price
// Property accessed: Category
```

## Common Follow-up Questions

- How does LinqKit's `PredicateBuilder` use expression tree combination to build dynamic OR/AND chains?
- What happens when EF Core cannot translate a custom method call — how do you detect and fix client evaluation?
- Why can't `async` lambdas be converted to expression trees?
- How does `IQueryable<T>` differ from `IEnumerable<T>` in terms of when the expression is evaluated?
- How would you write an expression tree that represents a `JOIN` across two entity types?

## Common Mistakes / Pitfalls

- **Calling `.Compile()` repeatedly inside a loop.** `Compile()` involves JIT compilation; it is orders of magnitude slower than calling the resulting delegate. Always cache the compiled `Func<>`.
- **Using unsupported methods in EF Core LINQ expressions.** Custom instance methods, `ToString()`, and many BCL methods are not translatable. EF Core 3+ throws `InvalidOperationException` — check translation with `ToQueryString()` before going to production.
- **Confusing `IQueryable.Where(Expression<Func<T,bool>>)` with `IEnumerable.Where(Func<T,bool>)`.** Calling `.AsEnumerable()` before `.Where()` silently loads the entire table into memory then filters client-side.
- **Building trees with `Expression.Call` using the wrong `MethodInfo`** (wrong overload, wrong declaring type). Runtime `InvalidOperationException` at query execution time, not compile time.
- **Assuming expression trees support all C# features.** `out`/`ref` parameters, `dynamic`, `await`, and `yield` cannot be expressed in expression trees.

## References

- [Expression Trees — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/advanced-topics/expression-trees/)
- [System.Linq.Expressions Namespace — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.linq.expressions)
- [How EF Core translates queries — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.linq.expressions)
- [Expression Trees Explained — Jon Skeet (C# in Depth, Chapter 9)](https://csharpindepth.com/) (verify URL)
- [See: ienumerable-vs-iqueryable.md](./ienumerable-vs-iqueryable.md)
- [See: delegates-explained.md](./delegates-explained.md)
