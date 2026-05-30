# Design a Distributed Job Scheduler

**Category:** System Design / Classic Problems
**Difficulty:** Senior
**Tags:** `job-scheduler`, `cron`, `distributed-locking`, `leader-election`, `reliability`

## Question

> Design a distributed job scheduler that executes scheduled tasks (cron-style) across a fleet of worker nodes. It must guarantee that each job runs exactly once per trigger time, support DAG-based dependencies between jobs, handle worker failures, and scale to 100,000 scheduled jobs.

- How do you prevent the same job from running on multiple workers simultaneously?
- How do you handle a worker crash mid-execution?
- How do you model and enforce DAG dependencies?

## Short Answer

A distributed scheduler uses a **leader election** (via Raft/ZooKeeper or a DB advisory lock) to designate a single scheduler instance that fires jobs at their trigger times. Jobs are claimed by workers using **optimistic locking** (compare-and-swap on a `claimed_by` column) so only one worker executes each trigger. Heartbeat rows with TTL detect crashed workers; the scheduler re-queues timed-out jobs. DAG dependencies are enforced by the scheduler: a job is only enqueued when all its parent jobs report `COMPLETED` in the current run's context.

## Detailed Explanation

### Functional Requirements

| Feature | Detail |
|---------|--------|
| Scheduling | Cron expressions, one-time triggers, interval-based |
| Execution | At-least-once with exactly-once dedup via idempotency |
| DAG dependencies | Job B starts only after Job A succeeds |
| Retry | Configurable max retries with exponential backoff |
| Failure handling | Re-queue after worker crash (heartbeat timeout) |
| Observability | Run history, logs per execution, alerting |

### Architecture Overview

```
┌──────────────────┐
│  Scheduler (1)   │  Leader-elected; fires jobs → writes to job_runs table
└────────┬─────────┘
         │ (INSERT job_run row, status=READY)
         ▼
┌──────────────────────────────────────────────────────┐
│         job_runs table (PostgreSQL or DynamoDB)       │
│  job_id | run_id | trigger_time | status | claimed_by │
└──────────────────────────────────────────────────────┘
         ▲ (SELECT … FOR UPDATE SKIP LOCKED / CAS)
         │
┌────────┴─────────────────────────────────────────────┐
│  Worker Pool (N workers, stateless, auto-scaled)      │
│  Each worker polls / listens for READY rows           │
└──────────────────────────────────────────────────────┘
```

### Leader Election

Only one scheduler instance fires jobs at their trigger time; without election, all N scheduler replicas would insert duplicate `job_run` rows.

**PostgreSQL advisory lock approach** (simple, no extra infra):
```sql
SELECT pg_try_advisory_lock(42);  -- returns true only on one instance
```
The winning instance becomes leader and holds the lock. On crash, the lock is released automatically by PostgreSQL when the connection closes.

**ZooKeeper/etcd approach**: each scheduler registers an ephemeral node; smallest-sequence node wins. If the leader crashes, ZooKeeper notifies the next candidate.

### Job Claiming — Prevent Double Execution

Workers use `SELECT … FOR UPDATE SKIP LOCKED` (PostgreSQL) to atomically claim a job_run:

```sql
UPDATE job_runs
SET status = 'RUNNING', claimed_by = 'worker-7', started_at = NOW()
WHERE run_id = (
    SELECT run_id FROM job_runs
    WHERE status = 'READY'
    ORDER BY trigger_time
    LIMIT 1
    FOR UPDATE SKIP LOCKED
)
RETURNING *;
```

`SKIP LOCKED` ensures two concurrent workers never see the same row — one gets the lock, the other skips to the next available row. No distributed lock service needed.

### Heartbeat & Crash Recovery

A running worker updates a `last_heartbeat` timestamp every 15 s. A watcher process (can be the leader scheduler) scans for stalled jobs:

```sql
-- Find jobs that haven't heartbeated in 2× heartbeat interval
SELECT run_id FROM job_runs
WHERE status = 'RUNNING'
  AND last_heartbeat < NOW() - INTERVAL '30 seconds';
```

Stalled jobs are reset to `READY` (with incremented `attempt_count`). If `attempt_count >= max_retries`, status is set to `FAILED`.

### DAG Dependency Enforcement

A job's dependencies are stored as edges in a `job_dependencies` table:

```
job_dependencies: (parent_job_id, child_job_id)
```

When a job completes (status=`COMPLETED`), the scheduler queries:

```sql
-- Is child Job B ready to run? Check all its parents have COMPLETED in this dag_run
SELECT COUNT(*) FROM job_dependencies jd
JOIN job_runs jr ON jr.job_id = jd.parent_job_id AND jr.dag_run_id = :runId
WHERE jd.child_job_id = :childJobId
  AND jr.status != 'COMPLETED';
-- Count = 0 → all parents done → enqueue child
```

The scheduler converts a DAG into a topological order at compile time and validates for cycles using Kahn's algorithm (reject DAGs with cycles at registration time).

### Retry with Exponential Backoff

```
attempt:  1      2      3      4
delay:    30s    2 min  8 min  32 min
formula:  base × 2^(attempt-1) + jitter(0..base/2)
```

Jitter prevents retry storms (all failed jobs retrying at the same second).

### Cron Expression Parsing

Next trigger time is computed by parsing the cron expression (`* * * * *`) using a library (e.g., Cronos for .NET) at job registration. The scheduler pre-computes the next 5 trigger times and stores them; on each trigger, it computes the next one.

### Exactly-Once Semantics

The scheduler guarantees **at-most-once per trigger slot** (CAS claim). Workers must make their work **idempotent** to handle the edge case where a worker crashes after partial completion and the job is re-queued:

- Use the `run_id` as an idempotency key for downstream operations.
- Wrap side effects in outbox transactions where possible.

### Scale

| Metric | Value |
|--------|-------|
| Jobs | 100,000 |
| Max trigger rate | ~5,000 jobs/min (burst) |
| Workers | 50–200 (auto-scaled by queue depth) |
| DB | PostgreSQL (write-heavy on `job_runs` during peaks) |
| Table partitioning | `job_runs` partitioned by month; archive old partitions |

> **Warning:** A global `SELECT … ORDER BY trigger_time` scan on `job_runs` will full-table-scan as the table grows. Add a partial index: `CREATE INDEX idx_ready ON job_runs (trigger_time) WHERE status = 'READY'`.

## Code Example

```csharp
using Microsoft.EntityFrameworkCore;
using NCrontab;   // Cronos or NCrontab for parsing

namespace JobScheduler;

// Worker: claims and executes a job run
public sealed class JobWorker(SchedulerDbContext db, IJobRegistry registry)
{
    public async Task RunLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var run = await ClaimNextJobAsync(ct);
            if (run is null)
            {
                await Task.Delay(TimeSpan.FromSeconds(5), ct);
                continue;
            }

            _ = ExecuteAsync(run, ct); // fire-and-forget per job
        }
    }

    private async Task<JobRun?> ClaimNextJobAsync(CancellationToken ct)
    {
        // SELECT ... FOR UPDATE SKIP LOCKED — atomic claim, no double execution
        return await db.Database.SqlQueryRaw<JobRun>("""
            UPDATE job_runs
            SET status = 'RUNNING', claimed_by = {0}, started_at = NOW()
            WHERE run_id = (
                SELECT run_id FROM job_runs
                WHERE status = 'READY' AND trigger_time <= NOW()
                ORDER BY trigger_time
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            )
            RETURNING *
            """, Environment.MachineName)
            .FirstOrDefaultAsync(ct);
    }

    private async Task ExecuteAsync(JobRun run, CancellationToken ct)
    {
        var heartbeatCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        _ = HeartbeatLoopAsync(run.RunId, heartbeatCts.Token);

        try
        {
            var handler = registry.GetHandler(run.JobType);
            await handler.ExecuteAsync(run, ct);
            await SetStatusAsync(run.RunId, JobStatus.Completed, ct);
        }
        catch (Exception ex)
        {
            var nextAttempt = run.AttemptCount < run.MaxRetries
                ? JobStatus.Ready    // will be re-queued by recovery job
                : JobStatus.Failed;
            await SetStatusAsync(run.RunId, nextAttempt, ct);
        }
        finally
        {
            heartbeatCts.Cancel();
        }
    }

    private async Task HeartbeatLoopAsync(Guid runId, CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await db.JobRuns
                .Where(r => r.RunId == runId)
                .ExecuteUpdateAsync(s =>
                    s.SetProperty(r => r.LastHeartbeat, DateTimeOffset.UtcNow), ct);
            await Task.Delay(TimeSpan.FromSeconds(15), ct);
        }
    }

    private Task SetStatusAsync(Guid runId, JobStatus status, CancellationToken ct) =>
        db.JobRuns.Where(r => r.RunId == runId)
            .ExecuteUpdateAsync(s => s.SetProperty(r => r.Status, status), ct);
}
```

## Common Follow-up Questions

- How would you implement a priority queue so high-priority jobs run before low-priority ones during a backlog?
- What is "backfill" in a scheduler context, and how would you implement catch-up for missed runs during a downtime window?
- How do you prevent a single long-running job from starving the worker pool?
- How would you add support for pausing and resuming a job schedule without data loss?
- How do you make the scheduler multi-tenant (different teams owning different job namespaces) with quota enforcement?

## Common Mistakes / Pitfalls

- **Using `SELECT … FOR UPDATE` without `SKIP LOCKED`**: all workers block on the same row until the lock is released, serialising execution.
- **No heartbeat / timeout mechanism**: a crashed worker leaves jobs in `RUNNING` forever; always have a reaper process.
- **Firing all 100K jobs at midnight**: cron jobs scheduled at `0 0 * * *` all fire simultaneously → thundering herd on workers and downstream systems. Randomise trigger offsets (jitter start times) at registration.
- **Not validating DAGs for cycles**: a cycle causes infinite waiting; reject cyclic DAGs at registration time with Kahn's algorithm.
- **Storing full job output in the job_runs table**: large log blobs cause table bloat; store logs in object storage (S3) and reference by URL.
- **Leader election without fencing tokens**: a slow leader that regains network connectivity after a split-brain can re-fire jobs already claimed by the new leader; use fencing tokens (monotonic epoch numbers) to reject stale leader writes.

## References

- [Apache Airflow Architecture](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html)
- [SELECT FOR UPDATE SKIP LOCKED — PostgreSQL docs](https://www.postgresql.org/docs/current/sql-select.html)
- [Cronos — .NET cron parsing library](https://github.com/HangfireIO/Cronos)
- [Hangfire — Background Jobs for .NET](https://www.hangfire.io/overview.html)
- [See: distributed-transactions.md](./distributed-transactions.md)
- [See: outbox-pattern.md](./outbox-pattern.md)
