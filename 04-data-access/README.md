# Data Access

> EF Core, Dapper, ADO.NET, SQL, transactions, performance.

## Questions

_Questions are organized by sub-topic. See [BACKLOG.md](./BACKLOG.md) for the full planned list._

## Index

### §1 EF Core Fundamentals
- [data-annotations-vs-fluent-api.md](./data-annotations-vs-fluent-api.md) — [Key]/[Required]/[MaxLength] vs Fluent API; clean entities via IEntityTypeConfiguration
- [dbcontext-overview.md](./dbcontext-overview.md) — DbContext lifecycle, DbSet<T>, scoped DI registration, unit-of-work pattern
- [ef-core-configuration.md](./ef-core-configuration.md) — IEntityTypeConfiguration<T>, ApplyConfigurationsFromAssembly, ConfigureConventions
- [ef-core-conventions.md](./ef-core-conventions.md) — PK/FK detection, type mapping, nullability with NRTs, when conventions break
- [ef-core-inheritance.md](./ef-core-inheritance.md) — TPH vs TPT vs TPC strategies, discriminator, PK generation in TPC
- [ef-core-migrations.md](./ef-core-migrations.md) — Migration anatomy, snapshot, migration bundles, CI/CD-safe deployment
- [ef-core-relationships.md](./ef-core-relationships.md) — One-to-many, one-to-one, many-to-many, cascade delete configuration
- [ef-core-seeding.md](./ef-core-seeding.md) — HasData vs migration SQL vs app-level seeders, limitations and when to use each
- [global-query-filters.md](./global-query-filters.md) — HasQueryFilter, soft delete, multi-tenancy, IgnoreQueryFilters()
- [owned-entities.md](./owned-entities.md) — OwnsOne/OwnsMany, table splitting, ComplexType (.NET 8), DDD value objects
- [shadow-properties.md](./shadow-properties.md) — Shadow properties for audit/tenancy, EF.Property<T>(), interceptor-based audit trail
- [value-converters.md](./value-converters.md) — IValueConverter, JSON columns (.NET 7+), enum-to-string, ValueComparer

### §2 EF Core Querying
- [basic-linq-queries.md](./basic-linq-queries.md) — Where/Select/OrderBy/GroupBy SQL translation, string methods, EF.Functions, gotchas
- [client-side-evaluation.md](./client-side-evaluation.md) — When EF Core falls back to C#, detection via logging, EF Core 3+ throwing behaviour
- [compiled-queries.md](./compiled-queries.md) — EF.CompileQuery/CompileAsyncQuery, translation overhead, restrictions
- [filtered-include.md](./filtered-include.md) — Include().Where()/.Take(), ThenInclude, AsSplitQuery, cartesian explosion
- [iqueryable-vs-ienumerable.md](./iqueryable-vs-ienumerable.md) — Deferred execution, expression tree vs delegate, when SQL executes
- [pagination-patterns.md](./pagination-patterns.md) — Offset Skip/Take vs keyset (cursor) pagination, composite cursor pattern
- [projections-and-select.md](./projections-and-select.md) — DTO projections, AutoMapper ProjectTo<T>, navigation JOINs without Include
- [raw-sql-in-ef-core.md](./raw-sql-in-ef-core.md) — FromSqlRaw/Interpolated, SqlQuery<T> (.NET 7+), ExecuteSqlRaw, SQL injection safety
- [split-queries.md](./split-queries.md) — AsSplitQuery, cartesian explosion, consistency trade-offs, global default
- [complex-query-patterns.md](./complex-query-patterns.md) — CTEs, window functions, CROSS APPLY (EF Core 8+), hybrid raw SQL + LINQ

### §3 EF Core Performance
- [asnotracking.md](./asnotracking.md) — AsNoTracking vs AsNoTrackingWithIdentityResolution, read-only queries, identity map
- [batching-in-ef-core.md](./batching-in-ef-core.md) — SaveChanges batching, ExecuteUpdate/Delete (.NET 7+), bulk UPDATE/DELETE
- [bulk-operations.md](./bulk-operations.md) — SqlBulkCopy, EFCore.BulkExtensions, TVP+stored proc, decision framework
- [change-tracker-performance.md](./change-tracker-performance.md) — DetectChanges cost, AutoDetectChangesEnabled, high-throughput import patterns
- [dbcontext-pooling.md](./dbcontext-pooling.md) — AddDbContextPool, pool size, limitations, IDbContextFactory
- [eager-vs-lazy-vs-explicit-loading.md](./eager-vs-lazy-vs-explicit-loading.md) — Include (eager), lazy proxies, explicit LoadAsync — when each fits
- [ef-core-logging-and-diagnostics.md](./ef-core-logging-and-diagnostics.md) — SQL logging, TagWith, IDbCommandInterceptor, MiniProfiler integration
- [n-plus-one-problem.md](./n-plus-one-problem.md) — What N+1 is, detection via SQL logging, fixing with Include or projections
- [ef-core-vs-dapper-performance.md](./ef-core-vs-dapper-performance.md) — Performance comparison, overhead sources, when Dapper wins, hybrid CQRS
- [connection-resilience.md](./connection-resilience.md) — EnableRetryOnFailure, IExecutionStrategy, transient faults, Azure SQL

### §4 EF Core Change Tracking
- [change-tracking-overview.md](./change-tracking-overview.md) — Entity states, identity map, snapshot detection, SaveChanges lifecycle
- [concurrency-tokens.md](./concurrency-tokens.md) — [ConcurrencyCheck], [Timestamp]/rowversion, DbUpdateConcurrencyException, merge strategies
- [detecting-changes.md](./detecting-changes.md) — DetectChanges, AutoDetectChangesEnabled, O(n) cost, manual detection
- [entity-states.md](./entity-states.md) — EntityState transitions, Add/Attach/Update, disconnected entities, stub entity trick
- [savechanges-interceptors.md](./savechanges-interceptors.md) — ISaveChangesInterceptor, audit trail, soft delete, domain event dispatch
- [update-patterns.md](./update-patterns.md) — Tracked update, db.Update, selective attach, SetValues, PATCH endpoints

### §5 Transactions & Concurrency
- [manual-transactions-ef-core.md](./manual-transactions-ef-core.md) — IDbContextTransaction, shared connection/transaction, Dapper interop, savepoints
- [transaction-basics.md](./transaction-basics.md) — ACID properties, implicit SaveChanges transaction, BeginTransactionAsync, rollback
- [ambient-transactions.md](./ambient-transactions.md) — TransactionScope, async flow option, MSDTC escalation pitfalls
- [deadlock-analysis.md](./deadlock-analysis.md) — Deadlock causes, deadlock graph, lock ordering, .NET retry on 1205
- [distributed-transactions.md](./distributed-transactions.md) — Why 2PC fails in cloud, Saga pattern, Outbox pattern
- [isolation-levels.md](./isolation-levels.md) — ANSI levels, dirty/phantom/non-repeatable reads, Snapshot, RCSI
- [optimistic-concurrency.md](./optimistic-concurrency.md) — rowversion, DbUpdateConcurrencyException, merge strategies
- [pessimistic-concurrency.md](./pessimistic-concurrency.md) — UPDLOCK/ROWLOCK hints, lock ordering, deadlock risk

### §6 Dapper
- [dapper-basic-queries.md](./dapper-basic-queries.md) — Query<T>, Execute, ExecuteScalar, DynamicParameters, async usage
- [dapper-multi-mapping.md](./dapper-multi-mapping.md) — splitOn, one-to-many dedup, QueryMultiple for multiple result sets
- [dapper-overview.md](./dapper-overview.md) — Micro-ORM philosophy, IDbConnection extension, vs EF Core comparison
- [dapper-stored-procedures.md](./dapper-stored-procedures.md) — CommandType.StoredProcedure, output params, RETURN value, multi-result sets