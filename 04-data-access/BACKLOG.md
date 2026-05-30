# 📋 Data Access — Question Backlog

Master list of planned questions for the `04-data-access` section.
Use this file as the single source of truth for what to add next.

## How to use with Claude Code

- **Add one:** _"add a data access question on `n-plus-one-problem` from BACKLOG.md"_
- **Add a group:** _"add all questions from the 'EF Core Performance' group in BACKLOG.md"_
- **Continue:** _"pick the next 5 unwritten questions from BACKLOG.md and create them"_
- **Status check:** _"compare BACKLOG.md against existing files in `04-data-access/` and tell me what's missing"_

When a question is created, mark it `[x]` and add a link to the file.

## Conventions

- **Filename:** kebab-case, exactly as listed below.
- **Difficulty:** 🟢 Junior • 🟡 Middle • 🔴 Senior
- **Template:** `_templates/question-template.md`
- **Commit:** `feat(data-access): add question on <topic>`

---

## Progress

**Total:** 30 / 94
**By difficulty:** 🟢 7/18 · 🟡 14/43 · 🔴 9/33

---

## §1 EF Core Fundamentals

- [x] 🟢 [`dbcontext-overview.md`](./dbcontext-overview.md) — DbContext lifecycle, DbSet<T>, registration in DI, scoped vs transient lifetime pitfalls
- [x] 🟢 [`ef-core-conventions.md`](./ef-core-conventions.md) — Primary key detection, FK naming conventions, data type mapping, shadow FK
- [x] 🟢 [`data-annotations-vs-fluent-api.md`](./data-annotations-vs-fluent-api.md) — [Key]/[Required]/[MaxLength] vs modelBuilder.Entity<>(), when to choose each
- [x] 🟡 [`ef-core-relationships.md`](./ef-core-relationships.md) — One-to-one, one-to-many, many-to-many config, cascade delete, navigation properties
- [x] 🟡 [`ef-core-configuration.md`](./ef-core-configuration.md) — IEntityTypeConfiguration<T>, assembly scanning, separating config from DbContext
- [x] 🟡 [`ef-core-migrations.md`](./ef-core-migrations.md) — Add-Migration, Update-Database, migration file anatomy, snapshot file, CI/CD integration
- [x] 🟡 [`ef-core-seeding.md`](./ef-core-seeding.md) — HasData seeding, custom migration seeding, environment-specific seed data strategies
- [x] 🟡 [`owned-entities.md`](./owned-entities.md) — Owned entity types, table splitting, ComplexType (.NET 8), value objects in EF Core
- [x] 🔴 [`ef-core-inheritance.md`](./ef-core-inheritance.md) — TPH vs TPT vs TPC strategies, discriminator column config, query and performance trade-offs
- [x] 🔴 [`shadow-properties.md`](./shadow-properties.md) — Shadow properties, EF.Property<T>(), audit timestamps, tenant ID without polluting domain model
- [x] 🔴 [`value-converters.md`](./value-converters.md) — IValueConverter, built-in converters, JSON columns (.NET 7+), enum-to-string, Money type
- [x] 🔴 [`global-query-filters.md`](./global-query-filters.md) — HasQueryFilter, soft delete pattern, multi-tenancy filter, IgnoreQueryFilters()

---

## §2 EF Core Querying

- [x] 🟢 [`iqueryable-vs-ienumerable.md`](./iqueryable-vs-ienumerable.md) — Deferred execution, client vs server evaluation, when the SQL query actually executes
- [x] 🟢 [`basic-linq-queries.md`](./basic-linq-queries.md) — Where/Select/OrderBy/GroupBy translation to SQL, common gotchas in LINQ-to-EF
- [x] 🟡 [`projections-and-select.md`](./projections-and-select.md) — Anonymous type vs DTO projections, columns fetched, AutoMapper ProjectTo<T>
- [x] 🟡 [`filtered-include.md`](./filtered-include.md) — Include().Where() (.NET 5+), ThenInclude, AsSplitQuery with includes, performance notes
- [x] 🟡 [`raw-sql-in-ef-core.md`](./raw-sql-in-ef-core.md) — FromSqlRaw, FromSqlInterpolated, SqlQuery<T> (.NET 7+), ExecuteSqlRaw, SQL injection safety
- [x] 🟡 [`compiled-queries.md`](./compiled-queries.md) — EF.CompileQuery / EF.CompileAsyncQuery, overhead of LINQ translation, when to use
- [x] 🟡 [`pagination-patterns.md`](./pagination-patterns.md) — OFFSET/FETCH vs keyset (cursor) pagination, IQueryable, performance at high page numbers
- [x] 🔴 [`client-side-evaluation.md`](./client-side-evaluation.md) — When EF Core falls back to client eval, how to detect via logging, avoiding memory blowups
- [x] 🔴 [`split-queries.md`](./split-queries.md) — AsSplitQuery, cartesian explosion with multi-level includes, trade-offs vs single query
- [x] 🔴 [`complex-query-patterns.md`](./complex-query-patterns.md) — CTEs and window functions via raw SQL, what EF Core LINQ can't translate, hybrid approach

---

## §3 EF Core Performance

- [x] 🟢 [`asnotracking.md`](./asnotracking.md) — AsNoTracking, AsNoTrackingWithIdentityResolution, read-only scenarios, measured speedup
- [x] 🟢 [`n-plus-one-problem.md`](./n-plus-one-problem.md) — What it is, how to detect with SQL logging / MiniProfiler, fixing with Include or projections
- [x] 🟡 [`eager-vs-lazy-vs-explicit-loading.md`](./eager-vs-lazy-vs-explicit-loading.md) — Include (eager), lazy nav proxies, entry.Reference().Load() — when each fits
- [x] 🟡 [`ef-core-logging-and-diagnostics.md`](./ef-core-logging-and-diagnostics.md) — SQL query logging, EnableSensitiveDataLogging, IDbCommandInterceptor for profiling
- [x] 🟡 [`batching-in-ef-core.md`](./batching-in-ef-core.md) — ExecuteUpdateAsync / ExecuteDeleteAsync (.NET 7+), bulk UPDATE/DELETE, SaveChanges batching
- [x] 🟡 [`dbcontext-pooling.md`](./dbcontext-pooling.md) — AddDbContextPool, pool size config, limitations (no per-request state), connection pool vs context pool
- [x] 🔴 [`change-tracker-performance.md`](./change-tracker-performance.md) — DetectChanges cost, AutoDetectChangesEnabled, high-throughput import patterns
- [x] 🔴 [`bulk-operations.md`](./bulk-operations.md) — EF Core Extensions, SqlBulkCopy, raw INSERT … SELECT, Z.EntityFramework trade-offs
- [ ] 🔴 `ef-core-vs-dapper-performance.md` — Benchmark breakdown, change tracking + materialization overhead, hybrid CQRS pattern
- [ ] 🔴 `connection-resilience.md` — EnableRetryOnFailure, IExecutionStrategy, transient fault handling, Azure SQL recommendations

---

## §4 EF Core Change Tracking

- [ ] 🟢 `change-tracking-overview.md` — How EF Core tracks entities, entity states: Added / Modified / Deleted / Unchanged / Detached
- [ ] 🟡 `entity-states.md` — EntityState transitions, Attach vs Add vs Update, disconnected entities, stub entity trick
- [ ] 🟡 `detecting-changes.md` — DetectChanges, automatic detection, ChangeTracker.AutoDetectChangesEnabled, cost at scale
- [ ] 🟡 `update-patterns.md` — Tracked update vs disconnected patch, full load vs selective property modification
- [ ] 🔴 `concurrency-tokens.md` — [ConcurrencyCheck], rowversion/[Timestamp], DbUpdateConcurrencyException, merge strategies
- [ ] 🔴 `savechanges-interceptors.md` — ISaveChangesInterceptor, audit trail implementation, soft delete on SaveChanges

---

## §5 Transactions & Concurrency

- [ ] 🟢 `transaction-basics.md` — ACID, implicit transaction on SaveChanges, manual BeginTransactionAsync, rollback on exception
- [ ] 🟡 `manual-transactions-ef-core.md` — IDbContextTransaction, shared connection between contexts, savepoints
- [ ] 🟡 `optimistic-concurrency.md` — Rowversion column, handling DbUpdateConcurrencyException, last-write-wins vs retry
- [ ] 🟡 `pessimistic-concurrency.md` — SELECT … FOR UPDATE, UPDLOCK/ROWLOCK hints in raw SQL, when pessimistic wins
- [ ] 🟡 `isolation-levels.md` — Read Uncommitted / Committed / Repeatable Read / Serializable / Snapshot — dirty/phantom/non-repeatable reads
- [ ] 🔴 `distributed-transactions.md` — Why 2PC is impractical in cloud, DTC limitations, saga as alternative, outbox pattern
- [ ] 🔴 `ambient-transactions.md` — TransactionScope, System.Transactions, MSDTC escalation, async + TransactionScope pitfalls
- [ ] 🔴 `deadlock-analysis.md` — What causes SQL deadlocks, deadlock graph reading, lock ordering, retry on deadlock in .NET

---

## §6 Dapper

- [ ] 🟢 `dapper-overview.md` — Micro-ORM philosophy, how Dapper extends IDbConnection, no change tracking, raw SQL control
- [ ] 🟢 `dapper-basic-queries.md` — Query<T>, QuerySingleOrDefault, Execute, anonymous type parameters, DynamicParameters
- [ ] 🟡 `dapper-multi-mapping.md` — QueryAsync with splitOn, mapping JOIN results to object graph, QueryMultiple for multi-result sets
- [ ] 🟡 `dapper-stored-procedures.md` — CommandType.StoredProcedure, input/output params, DynamicParameters, RETURN value
- [ ] 🟡 `dapper-type-handlers.md` — SqlMapper.TypeHandler<T>, mapping JSON columns, custom type conversions, Guid as binary
- [ ] 🟡 `dapper-vs-ef-core.md` — When Dapper wins (complex SQL, read perf), when EF Core wins (CRUD, migrations), project norms
- [ ] 🔴 `dapper-performance-tips.md` — Buffered vs unbuffered, QueryUnbuffered (.NET 7+), memory-efficient large result streaming
- [ ] 🔴 `dapper-ef-core-hybrid.md` — EF Core for writes + Dapper for reads in CQRS, shared connection, shared transaction

---

## §7 ADO.NET

- [ ] 🟢 `adonet-overview.md` — SqlConnection / SqlCommand / SqlDataReader, connection lifecycle, using/dispose, async pattern
- [ ] 🟢 `parameterized-queries.md` — SqlParameter, why string concatenation = SQL injection, parameterization best practices
- [ ] 🟡 `connection-pooling.md` — How .NET connection pool works, pool exhaustion symptoms, Max Pool Size, Azure SQL gotchas
- [ ] 🟡 `datareader-vs-dataset.md` — Forward-only streaming SqlDataReader vs disconnected DataSet, when DataSet is still used
- [ ] 🔴 `sqlbulkcopy.md` — SqlBulkCopy, batch size, table lock option, column mapping, performance vs row-by-row insert
- [ ] 🔴 `adonet-async-patterns.md` — OpenAsync / ExecuteReaderAsync / ReadAsync, avoiding sync-over-async ADO.NET anti-patterns

---

## §8 SQL & Query Optimization

- [ ] 🟢 `indexes-overview.md` — Clustered vs non-clustered, covering index, when indexes help vs hurt writes, index selectivity
- [ ] 🟢 `sql-join-types.md` — INNER / LEFT / RIGHT / FULL OUTER JOIN, CROSS JOIN, typical interview trap questions
- [ ] 🟡 `query-execution-plan.md` — Reading EXPLAIN / SHOW EXECUTION PLAN, index seek vs scan, key lookup, estimated vs actual rows
- [ ] 🟡 `ctes-and-window-functions.md` — WITH clause, ROW_NUMBER() / RANK() / DENSE_RANK(), LAG/LEAD, common interview patterns
- [ ] 🟡 `pagination-sql.md` — OFFSET/FETCH, ROW_NUMBER trick, keyset pagination with WHERE id > @last, scale comparison
- [ ] 🟡 `sql-vs-nosql-for-dotnet.md` — When relational is the wrong choice, document/graph/column-family alternatives, decision framework
- [ ] 🟡 `stored-procedures-vs-orm.md` — SP: security/plan cache/portability trade-offs vs ORM abstraction, .NET usage patterns
- [ ] 🔴 `index-design-patterns.md` — Composite index column ordering, include columns, filtered indexes, missing index DMVs
- [ ] 🔴 `query-hints-and-optimizer.md` — NOLOCK risks (dirty reads), READPAST, UPDLOCK, FORCESEEK — when hints help vs hurt
- [ ] 🔴 `database-partitioning.md` — Table partitioning by range/list, partition pruning, horizontal vs vertical partitioning
- [ ] 🔴 `full-text-search.md` — SQL Server FTS vs LIKE/ILIKE, CONTAINS/FREETEXT, when to prefer Elasticsearch, .NET integration
- [ ] 🔴 `query-performance-tuning-workflow.md` — Systematic approach: slow query log → execution plan → index → query rewrite → schema

---

## §9 Repository & Unit of Work Patterns

- [ ] 🟢 `repository-pattern-basics.md` — Why repository, domain-oriented interface, hiding persistence technology from domain
- [ ] 🟡 `unit-of-work-pattern.md` — Transaction boundary abstraction, IUnitOfWork, why DbContext already implements UoW
- [ ] 🟡 `generic-vs-specific-repository.md` — IRepository<T> pros/cons, specific repositories per aggregate, combining both
- [ ] 🟡 `repository-with-ef-core.md` — Whether to wrap DbContext, value of the abstraction, integration with CQRS read side
- [ ] 🔴 `repository-anti-patterns.md` — Leaking IQueryable, repository-over-repository, unnecessary abstraction, testability false promise
- [ ] 🔴 `specification-pattern-data-access.md` — ISpecification<T> with EF Core, composable specifications, Ardalis.Specification

---

## §10 Migrations & Schema Management

- [ ] 🟢 `ef-core-migrations-deep-dive.md` — Migration file anatomy, snapshot role, migration history table, idempotent scripts
- [ ] 🟡 `migrations-in-production.md` — Running at startup risks, migration bundles, idempotent SQL scripts, Blue/Green deployment
- [ ] 🟡 `zero-downtime-migrations.md` — Expand-contract (parallel change) pattern, additive-only changes, non-breaking schema evolution
- [ ] 🟡 `dbup-and-fluentmigrator.md` — SQL script-based migrations with DbUp, FluentMigrator DSL, comparison to EF Core migrations
- [ ] 🔴 `migration-rollback-strategies.md` — Why EF Core Down() is unreliable, manual rollback scripts, point-in-time restore strategy
- [ ] 🔴 `schema-first-vs-code-first.md` — Code-first (EF scaffold from code) vs database-first (reverse engineering), pros/cons
- [ ] 🔴 `multi-tenant-schema-strategies.md` — Per-tenant DB vs shared DB with tenant_id vs per-tenant schema, migration considerations
- [ ] 🔴 `database-versioning-tools-comparison.md` — EF Core vs DbUp vs Flyway vs Liquibase — state-based vs migration-based philosophy

---

## §11 Testing Data Access

- [ ] 🟢 `in-memory-provider.md` — EF Core InMemory provider, what it can't do (transactions, SQL, constraints), when it's acceptable
- [ ] 🟡 `sqlite-for-testing.md` — SQLite in-process for EF Core tests, closer to real SQL, limitations vs production SQL Server
- [ ] 🟡 `testcontainers-for-data-access.md` — Testcontainers .NET, real SQL Server/PostgreSQL in Docker, integration test setup
- [ ] 🟡 `repository-testing-patterns.md` — Testing repositories with a real provider vs mocking, what to test at which layer
- [ ] 🟡 `ef-core-unit-testing.md` — Why mocking DbContext is fragile, prefer InMemory/SQLite, what's worth unit testing vs integration
- [ ] 🔴 `integration-test-database-setup.md` — WebApplicationFactory + shared DB fixture, per-test isolation strategies, migration in fixture
- [ ] 🔴 `test-data-builders.md` — Builder/Object Mother pattern, Bogus for realistic fake data, shared vs per-test data fixtures
- [ ] 🔴 `respawn-for-test-isolation.md` — Respawn library to reset DB between tests, performance vs DROP/RECREATE, transaction rollback trick
