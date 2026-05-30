# Ретроспектива: .NET собеседование — 30.05.2026

## Общий итог

| Оценка | Кол-во вопросов |
|--------|----------------|
| ✅ Хорошо | 5 |
| ⚠️ Частично | 4 |
| ❌ Пробел | 3 |

---

## Разбор по вопросам

### Q1 — Dependency Injection

**Оценка:** ✅ Хорошо

**Мой ответ:** Архитектурный принцип, пробрасывание зависимостей через конструктор, IoC-контейнер управляет временем жизни. Три скопа: Singleton, Transient, Scoped.

**Что упустил:**
- Scoped объяснил нечётко — нужно говорить явно: **один экземпляр на один HTTP-запрос**, создаётся при начале, уничтожается в конце
- Не упомянул "captive dependency": если инжектить Transient в Singleton — Transient фактически становится Singleton. ASP.NET Core в Development это детектирует и бросает исключение

**Правильная формулировка Scoped:**
```
Scoped — один экземпляр в рамках одного scope. 
В ASP.NET Core scope = HTTP-запрос.
Удобен для DbContext: один контекст на запрос гарантирует консистентность change tracker.
```

---

### Q2 — Тестируемость DI: моки, абстрактные классы, статики

**Оценка:** ⚠️ Частично

**Мой ответ:** Интерфейсы можно мокать. Абстрактные классы — нельзя создать инстанс, поэтому не мокаем. Статики — проблема, wrapper/reflection.

**Что было неправильно:**
- Абстрактные классы **можно мокать** через Moq, если методы `abstract` или `virtual`:
```csharp
var mock = new Mock<MyAbstractClass>();
mock.Setup(x => x.DoWork()).Returns(42);
```
- Нельзя мокать: `sealed` классы и невиртуальные методы

**Правильная стратегия для статиков — Wrapper/Adapter паттерн:**
```csharp
// Статик — нельзя мокать
DateTime.UtcNow

// Решение: обернуть в интерфейс
public interface IDateTimeProvider {
    DateTime Now { get; }
}

public class DateTimeProvider : IDateTimeProvider {
    public DateTime Now => DateTime.UtcNow;
}

// В тестах: mock.Setup(x => x.Now).Returns(new DateTime(2026, 1, 1))
```

---

### Q3 — Strategy Pattern: обработка событий Create/Update/Delete

**Оценка:** ⚠️ Частично

**Мой ответ:** Назвал Strategy Pattern, но не смог описать реализацию конкретно.

**Правильная реализация:**
```csharp
public interface IEventStrategy {
    string EventType { get; }
    Task HandleAsync(UserEvent evt);
}

public class CreateEventStrategy : IEventStrategy {
    public string EventType => "create";
    public async Task HandleAsync(UserEvent evt) { /* INSERT */ }
}

public class UpdateEventStrategy : IEventStrategy {
    public string EventType => "update";
    public async Task HandleAsync(UserEvent evt) { /* UPDATE */ }
}

public class DeleteEventStrategy : IEventStrategy {
    public string EventType => "delete";
    public async Task HandleAsync(UserEvent evt) { /* DELETE */ }
}

// Резолвер через DI — регистрируем все как IEventStrategy
public class EventProcessor {
    private readonly Dictionary<string, IEventStrategy> _strategies;

    public EventProcessor(IEnumerable<IEventStrategy> strategies) {
        _strategies = strategies.ToDictionary(s => s.EventType);
    }

    public async Task ProcessAsync(UserEvent evt) {
        if (!_strategies.TryGetValue(evt.Type, out var strategy))
            throw new InvalidOperationException($"Unknown event type: {evt.Type}");
        await strategy.HandleAsync(evt);
    }
}
```

Ключевая идея: DI сам передаёт все реализации `IEnumerable<IEventStrategy>` — никакого `if/else`.

---

### Q4 — Entity Framework vs Dapper / raw SQL

**Оценка:** ✅ Хорошо

**Мой ответ:** EF удобен для LINQ, Dapper даёт контроль над SQL. N+1 проблема, change tracking. Выбор зависит от экспертизы команды.

**Структурированное сравнение для памяти:**

| | EF Core | Dapper |
|---|---|---|
| Скорость разработки | Высокая | Ниже |
| Производительность | Средняя | Высокая |
| Контроль над SQL | Ограниченный | Полный |
| Migrations | Встроены | FluentMigrator и т.д. |
| Когда использовать | CRUD, стандартные операции | Сложные отчёты, bulk операции |

**Важные нюансы EF которые стоит упоминать:**
- `AsNoTracking()` для read-only запросов — снижает overhead
- `Include()` / `ThenInclude()` против lazy loading — N+1 ловушка
- `SaveChanges()` оборачивает всё в транзакцию по умолчанию

---

### Q5 — Change Tracking: когда трекает, ToList(), как отключить для одной сущности

**Оценка:** ⚠️ Частично

**Мой ответ:** AsNoTracking знаю. После ToList() думаю трекинг продолжается. Для одной сущности — не знаю.

**Правильные ответы:**

```csharp
// ToList() материализует запрос, но сущности ОСТАЮТСЯ в трекере
var users = context.Users.Where(u => u.IsActive).ToList();
users[0].Name = "New Name"; // это будет трекаться!

// AsNoTracking — весь запрос
var users = context.Users.AsNoTracking().ToList();

// Отключить трекинг для одной сущности
context.Entry(user).State = EntityState.Detached;

// Глобально для контекста
context.ChangeTracker.QueryTrackingBehavior = QueryTrackingBehavior.NoTracking;
```

**Запомнить:** `Entry(entity).State = EntityState.Detached` — отсоединить конкретную сущность.

---

### Q6 — Extension Methods: реализация, плюсы и минусы

**Оценка:** ✅ Хорошо

**Мой ответ:** Static class, static method, первый параметр через `this`. Open/Closed Principle. Минус — неочевидность для команды.

**Синтаксис для повторения:**
```csharp
public static class QueryableExtensions {
    public static IQueryable<T> ActiveOnly<T>(
        this IQueryable<T> query) where T : ISoftDeletable {
        return query.Where(x => !x.IsDeleted);
    }
}

// Использование:
var users = context.Users.ActiveOnly().ToList();
```

**Потенциальные минусы (на будущее):**
- Неочевидность для новых разработчиков
- Конфликт имён если две библиотеки определяют одинаковый extension
- Сложнее отлаживать — не видно откуда метод

---

### Q7 — Дизайн API бронирования билетов

**Оценка:** ✅ Хорошо

**Мой ответ:** GET для списка мест, POST /order, временная блокировка мест, трёхслойная архитектура, валидация входных данных.

**Что стоило добавить:**
- **Idempotency key** в заголовке (`Idempotency-Key: uuid`) — защита от повторных запросов при retry
- Явно назвать HTTP-коды: `200`, `400` (валидация), `409 Conflict` (место уже занято), `422 Unprocessable Entity`
- Для временной блокировки — назвать механизм: Redis с TTL или поле `reserved_until` в БД

```
POST /api/bookings
Headers: Idempotency-Key: <uuid>
Body: {
  "seatIds": [42, 43],
  "customer": {
    "email": "user@example.com",
    "firstName": "Ivan"
  }
}

Response 201: { "bookingId": "...", "expiresAt": "..." }
Response 409: { "error": "Seat 42 is no longer available" }
```

---

### Q8 — Concurrent запросы на одно место: транзакции и race condition

**Оценка:** ❌ Пробел

**Мой ответ:** Транзакция решит проблему. Уровни изоляции, dirty read.

**Почему транзакция сама по себе НЕ решает проблему:**

Два пользователя одновременно:
1. Оба читают место — видят `available = true`
2. Оба проходят проверку
3. Оба делают INSERT — двойное бронирование!

Транзакция гарантирует atomicity, но не предотвращает race condition на чтение.

**Правильные решения:**

```sql
-- Вариант 1: UNIQUE constraint (база данных сама не даст дубль)
ALTER TABLE bookings ADD CONSTRAINT uq_seat_session UNIQUE (seat_id, session_id);
-- Второй INSERT просто упадёт с ConstraintException — обрабатываем как 409

-- Вариант 2: Pessimistic lock — SELECT FOR UPDATE
BEGIN;
SELECT * FROM seats WHERE id = 42 FOR UPDATE; -- блокирует строку
-- Теперь второй запрос ждёт
UPDATE seats SET status = 'booked' WHERE id = 42;
COMMIT;

-- Вариант 3: Optimistic concurrency — RowVersion / ConcurrencyToken в EF
// В модели:
[ConcurrencyCheck]
public byte[] RowVersion { get; set; }
// EF добавит WHERE RowVersion = @original в UPDATE
// Если другой запрос изменил запись — бросит DbUpdateConcurrencyException
```

**Запомнить:** UNIQUE constraint — самое простое и надёжное решение для этого кейса.

---

### Q9 — Масштабирование, нагрузочное тестирование, autoscaling

**Оценка:** ✅ Хорошо

**Мой ответ:** Нагрузочное тестирование чтобы найти пороговые значения. Load balancer + autoscaling. Реальный кейс с thread pool exhaustion.

**Инструменты которые стоит знать:**
- **k6**, **JMeter**, **NBomber** (для .NET) — нагрузочное тестирование
- **Azure Load Testing** / **AWS Load Testing**
- **Application Insights** / **Grafana** — мониторинг

**Thread pool exhaustion** — хорошо что упомянул из практики. Причина чаще всего: синхронные вызовы в async коде (`.Result`, `.Wait()`) или deadlock. Решение: `async/await` везде, не блокировать потоки.

---

### Q10 — Background job для удаления данных из 3rd-party по TTL

**Оценка:** ⚠️ Частично

**Мой ответ:** Хранить expiration_time в on-prem БД, background service раз в сутки. Soft delete, Outbox pattern.

**Что упустил — конкретные инструменты:**

```csharp
// Вариант 1: IHostedService (встроен в ASP.NET Core)
public class DataCleanupService : BackgroundService {
    protected override async Task ExecuteAsync(CancellationToken ct) {
        while (!ct.IsCancellationRequested) {
            await DoCleanupAsync();
            await Task.Delay(TimeSpan.FromHours(24), ct);
        }
    }
}

// Вариант 2: Hangfire — удобнее, есть UI, retry из коробки
RecurringJob.AddOrUpdate<DataCleanupJob>(
    "data-cleanup",
    job => job.ExecuteAsync(),
    Cron.Daily(hour: 2)); // каждую ночь в 2:00

// Вариант 3: Quartz.NET — для сложных расписаний (cron-выражения)
```

**Outbox pattern** — молодец что назвал. Суть: писать событие удаления и само удаление в одной транзакции в outbox таблицу, отдельный worker читает и отправляет.

---

### Q11 — Retry policy, Circuit Breaker (Polly)

**Оценка:** ✅ Хорошо

**Мой ответ:** Polly, exponential backoff, Circuit Breaker, Kafka для гарантии доставки.

**Код для повторения:**
```csharp
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .OrResult<HttpResponseMessage>(r => (int)r.StatusCode >= 500)
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)));

var circuitBreaker = Policy
    .Handle<HttpRequestException>()
    .CircuitBreakerAsync(
        exceptionsAllowedBeforeBreaking: 5,
        durationOfBreak: TimeSpan.FromSeconds(30));

var policy = Policy.WrapAsync(retryPolicy, circuitBreaker);
```

---

### Q12 — 3rd-party сервис упал навсегда (deprecated SDK)

**Оценка:** ❌ Пробел

**Мой ответ:** Растерялся. Kafka поможет восстановить состояние.

**Правильный ответ:**

Kafka не поможет если сервис упал навсегда — там некуда доставлять.

Реальные решения:
1. **Мониторинг зависимостей**: health check на 3rd-party endpoints, алерт если недоступен > N минут
2. **Dependency tracking**: renovate/dependabot следит за версиями SDK, PR при выходе новой версии
3. **DLQ (Dead Letter Queue)**: сообщения которые не удалось доставить — в отдельную очередь, ручная обработка
4. **Процесс**: подписка на changelog/release notes 3rd-party сервиса, тестирование на новых версиях SDK заранее

```csharp
// Пример health check
public class ThirdPartyHealthCheck : IHealthCheck {
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken ct) {
        try {
            await _thirdPartyClient.PingAsync(ct);
            return HealthCheckResult.Healthy();
        } catch {
            return HealthCheckResult.Unhealthy("3rd party service unavailable");
        }
    }
}
```

---

## Ключевые темы для повторения

- [ ] `EntityState.Detached` и управление трекингом отдельных сущностей
- [ ] UNIQUE constraint + optimistic concurrency (RowVersion) в EF Core
- [ ] Strategy Pattern — написать реализацию с IEnumerable в DI без `if/else`
- [ ] Moq: что можно и нельзя мокать (abstract, virtual, sealed)
- [ ] Инструменты background jobs: IHostedService, Hangfire, Quartz.NET
- [ ] Polly: написать retry + circuit breaker из памяти
- [ ] Health checks в ASP.NET Core

## Общие наблюдения

**Сильные стороны:**
- Реальный production опыт (thread exhaustion, deadlock, Azure) — работает очень хорошо
- Знание паттернов (Strategy, Outbox, Circuit Breaker) на уровне концепций
- EF Core нюансы (N+1, change tracking) — выше среднего

**Зона роста:**
- Конкретика реализации паттернов — называешь паттерн, но код "по памяти не вспомню"
- Concurrency в БД — важная тема для senior-уровня
- Инструментарий: конкретные библиотеки и их API