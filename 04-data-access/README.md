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
- [owned-entities.md](./owned-entities.md) — OwnsOne/OwnsMany, table splitting, ComplexType (.NET 8), DDD value objects
- [shadow-properties.md](./shadow-properties.md) — Shadow properties for audit/tenancy, EF.Property<T>(), interceptor-based audit trail