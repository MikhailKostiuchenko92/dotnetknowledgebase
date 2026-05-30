# 2026-05 — Fullstack .NET / Angular (Middle/Senior)

**Date:** 2026-05-30
**Role:** Fullstack .NET Developer (Middle/Senior)
**Stack заявлен:** .NET, ASP.NET Core, SQL Server, Angular
**Формат:** Технічне інтерв'ю ~90 хвилин, відео-дзвінок
**Результат:** TBD

---

## Питання, мої відповіді та кращі відповіді

---

### 1. Розкажи про останній проєкт

**Моя відповідь:**
Payroll-система, enterprise, fintech-домен. Великий розподілений моноліт (Web Forms) на WCF-сервісах, поступовий перехід до мікросервісів. Додав Redis для кешування дерева пермішнів (замість запиту до БД на кожен реквест). Використовував Dapper, Oracle + MS SQL, Azure DevOps CI/CD, BFF-підхід для нових фронтів.

**Оцінка:** ✅ Добре. Конкретні деталі, технічна ініціатива з метриками та proof of concept.

**Що можна покращити:**
Завжди готувати структурований "elevator pitch" проєкту: домен → команда → мій внесок → технічний стек → виклики → результати. Займає ~2 хвилини.

---

### 2. Індекси в базі даних — що це, як працюють, мінуси

**Моє питання:** B-tree індекс, збалансоване дерево, пришвидшує пошук. Мінуси: займає пам'ять, пригнічує INSERT (треба перебудувати дерево). Практичний кейс: навісив індекс на `client_id`, переписав stored procedure, проаналізував execution plan.

**Неточність:** Сказав "перебудовуємо дерево при кожній вставці".

**Правильна відповідь:**
При `INSERT`/`UPDATE`/`DELETE` B-tree індекс **оновлюється**, а не перебудовується повністю. Вставляється новий ключ у відповідний leaf-вузол. Якщо сторінка переповнена — відбувається **page split**, яка коштує дорожче, але це не кожна вставка. Також індекси уповільнюють не лише INSERT, а й UPDATE і DELETE на індексованих колонках.

**Що варто знати (класичний follow-up):**
- **Clustered index** — визначає фізичний порядок рядків у таблиці. Один на таблицю. У MS SQL за замовчуванням — PRIMARY KEY.
- **Non-clustered index** — окрема структура з покажчиком на рядок (RID або clustered key). Може бути багато.
- **Covering index** — non-clustered індекс, який містить всі колонки запиту (`INCLUDE`), дозволяє уникнути key lookup.
- **Filtered index** — індекс з WHERE-умовою, компактніший для часткових вибірок.

**Посилання:** [SQL Server Index Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/clustered-and-nonclustered-indexes-described)

---

### 3. Transaction Isolation Levels

**Моя відповідь:** Знайомо. Read Committed за замовчуванням в MS SQL і Oracle. Позбавляє від dirty reads. При UPDATE краще брати один лок.

**Неточності:** Плутанина при follow-up про "оновлювати по одному рядку чи всі в одній транзакції".

**Правильна відповідь:**

| Рівень | Dirty Read | Non-Repeatable Read | Phantom Read |
|---|---|---|---|
| Read Uncommitted | ✅ можливий | ✅ можливий | ✅ можливий |
| **Read Committed (default)** | ❌ ні | ✅ можливий | ✅ можливий |
| Repeatable Read | ❌ ні | ❌ ні | ✅ можливий |
| Serializable | ❌ ні | ❌ ні | ❌ ні |
| Snapshot (MVCC) | ❌ ні | ❌ ні | ❌ ні |

**Одна транзакція на 2000 рядків vs. построчно:**
- **Одна транзакція** — атомарність, але тримає локи довше → більше конкуренції, більший ризик дедлоків.
- **Построчно** — менша конкуренція, але більше round-trips і overhead на commit. Без атомарності.
- **Компроміс** — батчінг: UPDATE по 100-500 рядків в окремих транзакціях. Збалансовує конкуренцію і атомарність.

**Посилання:** [Transaction Isolation Levels — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)

---

### 4. Повільний SQL-запит — як діагностувати

**Моя відповідь:** Execution plan, відсутність індексів, isolation levels, незакриті з'єднання (connection pool), I/O операції з диском.

**Оцінка:** ✅ Правильний підхід і порядок дій.

**Що варто додати:**
```sql
-- Увімкнути статистику I/O перед запитом
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Потім дивитися на logical reads — ключова метрика
```

Також:
- **Parameter sniffing** у stored procedures — план будується для першого набору параметрів і може бути неоптимальний для інших. Вирішення: `OPTION (RECOMPILE)` або `OPTIMIZE FOR UNKNOWN`.
- **`UPDATE STATISTICS`** — застаріла статистика веде до неоптимальних планів.
- **Missing index hints** в execution plan — SQL Server сам підказує.

---

### 5. Dependency Injection — що це, лайфтайми

**Моя відповідь:** DI вбудований в .NET Core, інжектуємо інтерфейси, Transient — новий інстанс на кожен виклик. Сказав що "базується на Autofac".

**❌ Помилка:** DI в ASP.NET Core — це **власний вбудований контейнер** (`Microsoft.Extensions.DependencyInjection`). Autofac — стороння бібліотека, яку можна підключити замість нього.

**Правильна відповідь:**

| Lifetime | Коли створюється | Коли знищується |
|---|---|---|
| **Transient** | На кожен `GetService<T>()` | Після використання |
| **Scoped** | Один на HTTP-запит / на scope | Наприкінці запиту |
| **Singleton** | Один раз при першому зверненні | При зупинці додатку |

**Класичний pitfall — Captive Dependency:**
Якщо Singleton інжектує Scoped-сервіс, то Scoped буде жити як Singleton — порушення логіки і потенційний баг.
```csharp
// ❌ BAD: Scoped "захоплений" Singleton
services.AddSingleton<MySingletonService>(); // інжектує IScopedService
services.AddScoped<IScopedService, ScopedService>();
// MySingletonService буде тримати перший IScopedService назавжди
```
ASP.NET Core за замовчуванням кидає `InvalidOperationException` при такому налаштуванні (scope validation).

**Посилання:** [DI Lifetimes — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection#service-lifetimes)

---

### 6. async/await — як працює під капотом

**Моя відповідь:** Компілятор генерує state machine, кожен await — окремий стан. `async void` — code smell. `ConfigureAwait(false)` в .NET Core не обов'язковий, бо немає SynchronizationContext.

**Неточність:** `ConfigureAwait(false)` все ще рекомендований в бібліотечному коді.

**Правильна відповідь:**
В ASP.NET Core справді немає `SynchronizationContext`, тому дедлоків через `.Result`/`.Wait()` немає за замовчуванням. Але `ConfigureAwait(false)` в **бібліотечному коді** рекомендований з двох причин:
1. Бібліотека може використовуватися у WPF/WinForms, де контекст є.
2. Невеликий performance-виграш: continuation не захоплює і не відновлює контекст.

**Коротко про state machine:**
```csharp
// Цей код...
async Task<int> GetDataAsync()
{
    var result = await FetchAsync();
    return result + 1;
}

// ...компілятор розгортає приблизно в:
// struct GetDataAsyncStateMachine : IAsyncStateMachine
// {
//     int _state; // -1=start, 0=after await, -2=done
//     TaskAwaiter _awaiter;
//     void MoveNext() { ... }
// }
```

**`async void` — чому небезпечний:**
Виключення з `async void` не можна перехопити. Вони вилітають в `SynchronizationContext.UnhandledException` і можуть покласти процес. Дозволяється лише для event handlers.

**Посилання:** [Stephen Cleary — ConfigureAwait FAQ](https://devblogs.microsoft.com/dotnet/configureawait-faq/)

---

### 7. lock і Monitor

**Моя відповідь:** `lock` розгортається в `Monitor.Enter`/`Monitor.Exit`, обмежує доступ до критичної секції.

**Оцінка:** ✅ Точно і коротко.

**Що варто додати:**
- `lock` не можна використовувати в `async` методах (не можна await всередині lock-блоку).
- Для async-safe локінгу використовувати `SemaphoreSlim(1, 1)` з `await WaitAsync()`.
- Lockувати слід на **приватний readonly object**, не на `this` і не на публічні об'єкти.

```csharp
// ❌ Небезпечно
lock (this) { ... }

// ✅ Правильно
private readonly object _lock = new();
lock (_lock) { ... }

// ✅ Async-safe
private readonly SemaphoreSlim _semaphore = new(1, 1);
await _semaphore.WaitAsync();
try { ... }
finally { _semaphore.Release(); }
```

---

### 8. GAC і версіонування сборок

**Моя відповідь:** Читав теоретично, практичного досвіду немає.

**Оцінка:** ✅ Чесна відповідь. GAC — це механізм .NET Framework, в .NET Core його немає.

**Для розуміння:**
GAC (Global Assembly Cache) — системне сховище для shared assemblies в .NET Framework. Дозволяв кільком версіям однієї бібліотеки існувати на машині одночасно (side-by-side versioning). В .NET Core замінений NuGet + локальними папками (`packages/`).

---

### 9. ❌ Ієрархія: Assembly, Process, AppDomain, Module

**Моя відповідь:** Назвав всі чотири, але переплутав порядок (сказав Module "зверху").

**Правильна ієрархія (від більшого до меншого):**
```
Process
  └── AppDomain (в .NET Core — завжди один)
        └── Assembly (.dll / .exe — містить маніфест і IL-код)
              └── Module (фізичний файл; зазвичай Assembly = один Module)
```

- **Process** — запущений екземпляр програми, має свій адресний простір.
- **AppDomain** — ізольоване середовище всередині процесу. В .NET Core спрощений: завжди один `AppDomain.CurrentDomain`.
- **Assembly** — мінімальна одиниця деплойменту. Містить маніфест (список модулів і залежностей), типи, IL-код і ресурси.
- **Module** — відповідає фізичному `.dll`-файлу. Одна Assembly може містити кілька модулів (рідко використовується).

---

### 10. Як написати власний ORM

**Моя відповідь:** Expression trees для трансляції LINQ, атрибути / fluent API для маппінгу, механізм міграцій, маппінг .NET-типів на SQL-типи.

**Оцінка:** ✅ Правильні компоненти. Пропустив change tracker.

**Повний список компонентів мінімального ORM:**
1. **Маппінг** — зіставлення класів з таблицями, властивостей з колонками (атрибути або fluent API через рефлексію).
2. **Query translator** — трансляція LINQ expression tree в SQL (`IQueryable<T>` → SQL string).
3. **Change tracker** — відстежування змін entity між читанням і збереженням (dirty checking).
4. **Unit of Work** — накопичення змін і атомарний `SaveChanges()`.
5. **Identity Map** — кеш завантажених entity, щоб не робити подвійні запити для одного ключа.
6. **Migration engine** — порівняння поточної схеми БД з моделлю, генерація DDL.
7. **Type mapping** — `int` → `INT`, `string` → `NVARCHAR`, `DateTime` → `DATETIME2`, тощо.

---

### 11. EF Core — видалення колонки: що робити

**Моя відповідь:** Бекап → міграція → `[NotMapped]` атрибут.

**Оцінка:** ⚠️ Частково правильно, але порядок і підхід можна покращити.

**Правильний підхід для zero-downtime:**
```
Крок 1: [NotMapped] на властивість → деплой (код більше не читає колонку)
Крок 2: Переконатися що нічого не залежить від колонки → моніторинг
Крок 3: Створити міграцію з DROP COLUMN → зробити бекап → накатити
```

Якщо downtime допустимий: одразу видалити властивість + міграція + бекап.

**`[NotMapped]` vs `modelBuilder.Ignore()`:**
```csharp
// Атрибут
[NotMapped]
public string OldColumn { get; set; }

// Fluent API (пріоритет над атрибутом)
modelBuilder.Entity<MyEntity>().Ignore(e => e.OldColumn);
```

---

### 12. Design Patterns — категорії

**Моя відповідь:** Структурні, порождаючі. Не назвав третю категорію.

**❌ Пропущено:** Behavioral (поведінкові).

**Три категорії GoF:**
| Категорія | Призначення | Приклади |
|---|---|---|
| **Creational** (порождаючі) | Створення об'єктів | Factory Method, Abstract Factory, Builder, Singleton, Prototype |
| **Structural** (структурні) | Побудова структур з об'єктів | Adapter, Decorator, Facade, Proxy, Composite, Bridge, Flyweight |
| **Behavioral** (поведінкові) | Взаємодія між об'єктами | Strategy, Observer, Command, Mediator, Template Method, Iterator, Chain of Responsibility |

На практиці найчастіше: **Strategy, Factory, Decorator, Observer, Mediator** (MediatR в .NET).

---

### 13. "Всі паттерни — це стратегія?" — провокаційне питання

**Моя відповідь:** Погодився і намагався обґрунтувати.

**❌ Це була пастка.** Треба було не погоджуватися.

**Правильна відповідь:**
Ні. Strategy — це конкретний GoF-патерн з чіткою структурою: контекст делегує алгоритм об'єкту-стратегії, що дозволяє міняти алгоритм під час виконання. Казати "всі паттерни — це стратегія" означає змішувати рівні абстракції. Патерни — конкретні перевірені рецепти для повторюваних проблем, а не "стратегії" в загальному сенсі.

---

### 14. SOLID — LSP і ISP

**LSP (Liskov Substitution Principle):**

**Моя відповідь:** Об'єкти дочірнього класу повинні замінювати базовий без зміни поведінки. Додав про "конфлікт з поліморфізмом".

**Уточнення:** LSP не конфліктує з поліморфізмом — він є його правильним використанням. Порушення LSP — це неправильний поліморфізм. Класичний приклад порушення:
```csharp
// ❌ Порушення LSP
class Rectangle { public virtual int Width { get; set; } public virtual int Height { get; set; } }
class Square : Rectangle
{
    public override int Width { set { base.Width = base.Height = value; } } // ламає контракт Rectangle!
}

void TestRectangle(Rectangle r)
{
    r.Width = 4; r.Height = 5;
    Console.WriteLine(r.Width * r.Height); // Rectangle: 20, Square: 25 — порушення
}
```

**ISP (Interface Segregation Principle):**

**Моя відповідь:** Не зміг чітко пояснити, відхилився в питання "коли виправданий жирний інтерфейс".

**Правильна відповідь:**
Клієнт не повинен залежати від методів, які він не використовує. Великі інтерфейси розбивати на вузькі.

```csharp
// ❌ Порушення: робот змушений реалізовувати Eat()
interface IWorker { void Work(); void Eat(); }
class Robot : IWorker { public void Work() { } public void Eat() => throw new NotImplementedException(); }

// ✅ ISP: розбиваємо
interface IWorkable { void Work(); }
interface IFeedable { void Eat(); }
class Robot : IWorkable { public void Work() { } }
class Human : IWorkable, IFeedable { public void Work() { } public void Eat() { } }
```

---

## Загальний аналіз

### Сильні сторони
- Конкретний практичний досвід (Redis, execution plan, memory profiling)
- Правильний підхід до діагностики проблем (execution plan → індекси → isolation levels)
- async/await state machine розуміє добре
- Чесно відповідав "не знаю" замість фантазій

### Слабкі місця
| Тема | Проблема | Що вивчити |
|---|---|---|
| DI Container | Сказав "Autofac під капотом .NET Core" | `Microsoft.Extensions.DependencyInjection`, captive dependency |
| Assembly ієрархія | Переплутав порядок | Process → AppDomain → Assembly → Module |
| Transaction Isolation | Плутанина при follow-up | Таблиця аномалій, MVCC / Snapshot isolation |
| GoF категорії | Не назвав Behavioral | Вивчити всі 23 патерни по категоріях |
| ISP | Не зміг чітко пояснити | Перечитати з прикладами |
| ConfigureAwait | Неточне твердження | Stephen Cleary FAQ |

### Провокаційне питання
Інтерв'юер перевіряв критичне мислення питанням "всі паттерни — це стратегія?". Треба було не погоджуватися і аргументувати позицію.

---

## Питання до роботодавця (не встиг задати через час)

- Яка команда, розміри, структура?
- Який рівень tech debt на проєкті?
- Як відбувається code review?
- Чи є практика 1-on-1 з тімлідом?
- Яка частка legacy (WCF / Web Forms) vs нових мікросервісів?

---

## Теми для додавання в репо

- [ ] `04-data-access/transaction-isolation-levels.md` — таблиця аномалій, MVCC
- [ ] `04-data-access/indexes-clustered-vs-nonclustered.md` — поглиблений розбір
- [ ] `05-aspnet-core/dependency-injection.md` — лайфтайми, captive dependency
- [ ] `02-dotnet-runtime/assembly-appdomain-module.md` — ієрархія CLR
- [ ] `01-csharp-language/configure-await-false.md` — коли потрібен, коли ні
- [ ] `03-oop-and-design/solid-lsp-isp-examples.md` — практичні приклади
- [ ] `03-oop-and-design/gof-patterns-overview.md` — всі 23, по категоріях