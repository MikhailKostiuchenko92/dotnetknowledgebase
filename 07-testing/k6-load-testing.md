# What Is k6 and When Would You Choose It Over NBomber?

**Category:** Testing / Performance & Load Testing
**Difficulty:** 🔴 Senior
**Tags:** `k6`, `NBomber`, `load-testing`, `performance`, `Grafana`, `JavaScript`

## Question
> What is k6 and when would you choose it over NBomber for .NET services?

## Short Answer
**k6** is an open-source, Grafana-maintained load testing tool that scripts tests in JavaScript/TypeScript. Choose k6 when you need: cross-team accessibility (scripts readable by non-.NET engineers), Grafana Cloud/dashboard integration, advanced traffic shaping out of the box, or reuse of an existing k6 test suite. Use NBomber when you want C# scripts, deep .NET SDK integration, or are testing non-HTTP protocols (.NET-specific channels, gRPC, databases).

## Detailed Explanation

### Comparison Table

| Aspect | k6 | NBomber |
|---|---|---|
| Script language | JavaScript / TypeScript | C# |
| Protocol support | HTTP, WebSocket, gRPC, TCP | HTTP, WebSocket, gRPC, DB, MQ, custom |
| CI integration | CLI, GitHub Actions, Docker | .NET test runner, CLI |
| Grafana Cloud | Native integration | Manual export |
| Team accessibility | Any engineer (JS) | .NET engineers |
| Custom checks | JS assertions | C# code / LINQ |
| Open / closed model | Open (VUs, RPS) | Both via `Simulation` |

### Choosing k6
- Your team includes QA engineers who know JS but not C#
- You want Grafana Cloud dashboards (k6 Cloud)
- Your load tests will outlive the current .NET stack
- You already have k6 scripts for other services

### Choosing NBomber
- All test code is C# — one language, one toolchain
- You're testing .NET-specific protocols (named pipes, `HttpClient` with custom `DelegatingHandler`)
- You want to reuse production `IServiceCollection` setup in load tests
- You need to correlate load test results with BenchmarkDotNet findings

### k6 Script Example
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 20 },   // ramp up
    { duration: '30s', target: 50 },   // sustained load
    { duration: '10s', target: 0  },   // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],   // 95th percentile < 200ms
    http_req_failed:   ['rate<0.01'],   // < 1% error rate
  },
};

export default function () {
  const res = http.get('http://localhost:5001/api/products');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
```

```shell
k6 run load-test.js
```

### Running k6 in CI (GitHub Actions)
```yaml
- uses: grafana/setup-k6-action@v1
- name: Run k6 load test
  run: k6 run --vus 50 --duration 30s load-test.js
```

### k6 Thresholds (Pass/Fail)
k6 can fail the CI build when thresholds are breached:
```javascript
thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.005'],
}
```

## Code Example
```javascript
// POST scenario with JSON body
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 20,
  duration: '30s',
  thresholds: { http_req_duration: ['p(95)<300'] },
};

export default function () {
  const payload = JSON.stringify({
    productId: Math.floor(Math.random() * 100) + 1,
    quantity: 1,
  });
  const params = { headers: { 'Content-Type': 'application/json' } };
  const res = http.post('http://localhost:5001/api/cart', payload, params);

  check(res, {
    'status 201': (r) => r.status === 201,
    'has orderId': (r) => JSON.parse(r.body).orderId !== undefined,
  });
}
```

## Common Follow-up Questions
- How do you integrate k6 with Grafana Cloud dashboards?
- What is the difference between virtual users (VUs) and requests per second in k6?
- How do you handle authentication tokens in k6 load tests?
- What is the k6 browser module and how does it compare to Playwright?
- How do you parametrize k6 scenarios with external data files?

## Common Mistakes / Pitfalls
- **Running load tests with production authentication tokens** — use dedicated test users/tokens.
- **Setting `vus` too high** — start small (10–20 VUs) and observe CPU/DB before scaling up.
- **Ignoring error rate** — passing latency thresholds while errors are 5% is a failing test.
- **Not setting `sleep()`** — without think-time, k6 hammers the endpoint as fast as possible (unrealistic for user-simulating scenarios).

## References
- [k6 official documentation](https://k6.io/docs/)
- [k6 GitHub](https://github.com/grafana/k6)
- [Grafana k6 Cloud](https://grafana.com/products/cloud/k6/)
- [See also: nbomber-overview.md](nbomber-overview.md)
