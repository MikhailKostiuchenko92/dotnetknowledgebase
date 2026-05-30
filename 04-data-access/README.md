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
- [dapper-type-handlers.md](./dapper-type-handlers.md) — SqlMapper.TypeHandler<T>, JSON columns, Guid binary, strongly-typed ID mapping
- [dapper-vs-ef-core.md](./dapper-vs-ef-core.md) — Decision framework, when Dapper wins, when EF Core wins, CQRS hybrid
- [dapper-performance-tips.md](./dapper-performance-tips.md) — Buffered vs unbuffered, QueryUnbuffered, CommandDefinition, plan cache
- [dapper-ef-core-hybrid.md](./dapper-ef-core-hybrid.md) — Shared connection factory, transaction sharing, CQRS read/write split architecture

### §7 ADO.NET
- [adonet-async-patterns.md](./adonet-async-patterns.md) — OpenAsync/ExecuteReaderAsync/ReadAsync, avoiding sync-over-async, CancellationToken
- [adonet-overview.md](./adonet-overview.md) — SqlConnection/SqlCommand/SqlDataReader, connection lifecycle, async patterns, resource management
- [connection-pooling.md](./connection-pooling.md) — ADO.NET pool mechanics, pool exhaustion, Max Pool Size, Azure SQL tuning
- [datareader-vs-dataset.md](./datareader-vs-dataset.md) — Streaming vs in-memory, when DataSet still has a place, performance comparison
- [parameterized-queries.md](./parameterized-queries.md) — SQL injection prevention, SqlParameter, EF Core/Dapper safe patterns
- [sqlbulkcopy.md](./sqlbulkcopy.md) — TDS bulk load protocol, batch size, TableLock, column mappings, transaction integration

### §8 SQL & Query Optimization
- [ctes-and-window-functions.md](./ctes-and-window-functions.md) — WITH clause, ROW_NUMBER/RANK/DENSE_RANK, LAG/LEAD, running totals
- [database-partitioning.md](./database-partitioning.md) — Range partitioning, partition elimination, partition switching, sharding vs partitioning
- [index-design-patterns.md](./index-design-patterns.md) — Composite index ordering, INCLUDE columns, filtered indexes, missing index DMVs
- [indexes-overview.md](./indexes-overview.md) — Clustered vs non-clustered, covering indexes, selectivity, when indexes hurt
- [pagination-sql.md](./pagination-sql.md) — OFFSET/FETCH vs keyset pagination, cursor encoding, EF Core implementation
- [query-execution-plan.md](./query-execution-plan.md) — Index seek vs scan, key lookup, estimated vs actual rows, statistics
- [query-hints-and-optimizer.md](./query-hints-and-optimizer.md) — NOLOCK dirty reads, UPDLOCK, READPAST queue pattern, FORCESEEK
- [sql-join-types.md](./sql-join-types.md) — INNER/LEFT/RIGHT/FULL OUTER/CROSS JOIN, LEFT JOIN + WHERE trap
- [sql-vs-nosql-for-dotnet.md](./sql-vs-nosql-for-dotnet.md) — NoSQL categories, when SQL wins, Redis/MongoDB/.NET integration
- [stored-procedures-vs-orm.md](./stored-procedures-vs-orm.md) — Plan caching, security isolation, SP vs LINQ trade-offs, when to choose each
- [full-text-search.md](./full-text-search.md) — SQL Server FTS, CONTAINS/FREETEXT, vs LIKE, Elasticsearch/.NET integration
- [query-performance-tuning-workflow.md](./query-performance-tuning-workflow.md) — Identify → baseline → plan analysis → index/rewrite → validate → monitor

### §9 Repository & Unit of Work Patterns
- [generic-vs-specific-repository.md](./generic-vs-specific-repository.md) — IRepository<T> pros/cons, hybrid pattern, avoiding IQueryable leakage
- [repository-anti-patterns.md](./repository-anti-patterns.md) — IQueryable leak, repo-over-repo, unnecessary abstraction, testability false promise
- [repository-pattern-basics.md](./repository-pattern-basics.md) — Domain-oriented interface, EF Core implementation, in-memory fake for unit tests
- [repository-with-ef-core.md](./repository-with-ef-core.md) — When to wrap DbContext, CQRS read side, clean architecture DI wiring
- [specification-pattern-data-access.md](./specification-pattern-data-access.md) — ISpecification<T>, EF Core evaluator, Ardalis.Specification, composable queries
- [unit-of-work-pattern.md](./unit-of-work-pattern.md) — IUnitOfWork, DbContext as UoW, coordinating repositories, explicit transactions

### §10 Migrations & Schema Management
- [ef-core-migrations-deep-dive.md](./ef-core-migrations-deep-dive.md) — Migration anatomy, ModelSnapshot, migration history table, idempotent scripts, bundles
- [migrations-in-production.md](./migrations-in-production.md) — Startup migration risks, migration bundles, idempotent scripts, K8s Job pattern
- [zero-downtime-migrations.md](./zero-downtime-migrations.md) — Expand-contract pattern, backwards-compatible migrations, online index operations
- [dbup-and-fluentmigrator.md](./dbup-and-fluentmigrator.md) — SQL script migrations with DbUp, FluentMigrator C# DSL, comparison to EF Core
- [migration-rollback-strategies.md](./migration-rollback-strategies.md) — Why Down() fails, compensating migrations, point-in-time restore
- [schema-first-vs-code-first.md](./schema-first-vs-code-first.md) — Code-first vs database-first scaffolding, partial classes, DBA-owned schemas
- [multi-tenant-schema-strategies.md](./multi-tenant-schema-strategies.md) — DB per tenant vs shared schema vs schema per tenant, EF Core global filters
- [database-versioning-tools-comparison.md](./database-versioning-tools-comparison.md) — EF Core vs DbUp vs Flyway vs Liquibase, state-based vs migration-based

### §11 Testing Data Access
- [in-memory-provider.md](./in-memory-provider.md) — EF Core InMemory provider, limitations (no SQL/transactions/constraints), when acceptable
- [ef-core-unit-testing.md](./ef-core-unit-testing.md) — Why mocking DbContext is fragile, what to unit test vs integration test
- [integration-test-database-setup.md](./integration-test-database-setup.md) — WebApplicationFactory + shared DB fixture, per-test isolation, migration in fixture
- [repository-testing-patterns.md](./repository-testing-patterns.md) — Fake repos for unit tests, real provider for integration tests, test pyramid
- [respawn-for-test-isolation.md](./respawn-for-test-isolation.md) — Respawn library to reset DB between tests, vs DROP/RECREATE, vs transaction rollback
- [sqlite-for-testing.md](./sqlite-for-testing.md) — SQLite in-process EF Core tests, SqliteConnection keep-alive, limitations vs SQL Server
- [test-data-builders.md](./test-data-builders.md) — Builder/Object Mother pattern, Bogus realistic fake data, persisted builders
- [testcontainers-for-data-access.md](./testcontainers-for-data-access.md) — Real SQL Server in Docker via Testcontainers, IClassFixture, test isolation strategies