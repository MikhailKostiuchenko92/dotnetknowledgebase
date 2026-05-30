# Memory<T>

**Category:** C# / Memory & Performance
**Difficulty:** Senior
**Tags:** `memory`, `span`, `async`, `readonlymemory`, `buffers`

## Question
> What is `Memory<T>`, and how is it different from `Span<T>`?
>
> Why is `Memory<T>` useful across async boundaries and for heap-stored buffers in modern .NET?
>
> When should you expose `Memory<T>` or `ReadOnlyMemory<T>` instead of arrays or spans?

## Short Answer
`Memory<T>` is a heap-friendly abstraction over contiguous memory that can be stored in fields, passed through async methods, and sliced without copying. It complements `Span<T>`: `Span<T>` is faster and more direct inside synchronous code, while `Memory<T>` exists for cases where the buffer must outlive the current stack frame. A good rule is to expose `Memory<T>` for asynchronous or retained access, then convert to `.Span` only inside short synchronous regions.

## Detailed Explanation
### Why `Memory<T>` exists
`Span<T>` is stack-only by design, which makes it safe and fast but unsuitable for fields, interfaces, and async boundaries. `Memory<T>` fills that gap. It still represents a slice over contiguous memory, but unlike `Span<T>`, it can live on the heap.

| Type | Stack-only | Can be a field | Can cross `await` | Writable |
| --- | --- | --- | --- | --- |
| `Span<T>` | Yes | No | No | Yes |
| `ReadOnlySpan<T>` | Yes | No | No | No |
| `Memory<T>` | No | Yes | Yes | Yes |
| `ReadOnlyMemory<T>` | No | Yes | Yes | No |

This is why many modern APIs accept `ReadOnlyMemory<byte>` or return `IMemoryOwner<byte>` in buffer-heavy code.

### `.Span` is for synchronous regions
`Memory<T>` itself is heap-friendly, but when you access `.Span`, you are back in stack-only territory. That means `.Span` is meant for a limited synchronous section of code.

A typical pattern is:
1. keep `Memory<T>` on the object or across the async boundary
2. enter a synchronous section
3. get `.Span`
4. finish the synchronous work before the next `await`

> Tip: a useful interview phrase is “`Memory<T>` is the transport type; `Span<T>` is the work type.”

### API design guidance
Use `Span<T>` or `ReadOnlySpan<T>` for synchronous, immediate-use APIs. Use `Memory<T>` or `ReadOnlyMemory<T>` when the callee may store the buffer, use it asynchronously, or expose it through an object.

| API shape | Better choice |
| --- | --- |
| Parse a UTF-8 payload immediately | `ReadOnlySpan<byte>` |
| Store a reusable buffer on a class | `Memory<byte>` |
| Return a readable buffer from a pool-backed owner | `Memory<T>` / `ReadOnlyMemory<T>` |
| Process data after `await` | `Memory<T>` |

`Memory<T>` works especially well with [arraypool-and-memorypool.md](./arraypool-and-memorypool.md). For stack-based hot paths, see [stackalloc.md](./stackalloc.md). For sync-only processing, see [span-of-t.md](./span-of-t.md).

> Warning: never capture a span obtained from `memory.Span` and then use that same span after an `await`. Reacquire the span after the async boundary.

## Code Example
```csharp
using System;
using System.Text;
using System.Threading.Tasks;

byte[] buffer = new byte[32];
var messageBuffer = new MessageBuffer(buffer);

await messageBuffer.WriteTextAsync("hello memory");
Console.WriteLine(messageBuffer.ReadText());

public sealed class MessageBuffer
{
    private readonly Memory<byte> _buffer; // Safe to store on the heap.

    public MessageBuffer(Memory<byte> buffer)
    {
        _buffer = buffer;
    }

    public async Task WriteTextAsync(string text)
    {
        await Task.Delay(10); // Simulate async work before touching the buffer.

        Span<byte> destination = _buffer.Span; // Use Span only in a sync region.
        destination.Clear();
        Encoding.UTF8.GetBytes(text, destination);
    }

    public string ReadText()
    {
        ReadOnlySpan<byte> source = _buffer.Span;
        int zeroIndex = source.IndexOf((byte)0);
        ReadOnlySpan<byte> used = zeroIndex >= 0 ? source[..zeroIndex] : source;

        return Encoding.UTF8.GetString(used);
    }
}
```

## Common Follow-up Questions
- Why can `Memory<T>` be stored in a field while `Span<T>` cannot?
- What is the lifetime rule around the `.Span` accessor?
- When should an API accept `ReadOnlyMemory<T>` instead of `byte[]`?
- How does `IMemoryOwner<T>` relate to `Memory<T>`?
- Why is `Memory<T>` often the right choice for async pipelines?

## Common Mistakes / Pitfalls
- Using `Memory<T>` everywhere, even when a simple synchronous `Span<T>` API is clearer.
- Holding onto `memory.Span` across `await` or other async boundaries.
- Assuming `Memory<T>` owns the underlying buffer; it still may just be a view.
- Returning pooled memory without clearly defining who owns disposal or return responsibility.
- Forgetting to use `ReadOnlyMemory<T>` when mutation should be prohibited.

## References
- [Microsoft Docs: Memory<T>](https://learn.microsoft.com/dotnet/api/system.memory-1)
- [Microsoft Docs: Memory<T> and Span<T> usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [Microsoft Docs: ReadOnlyMemory<T>](https://learn.microsoft.com/dotnet/api/system.readonlymemory-1)
- [See: Span<T>](./span-of-t.md)
- [See: ArrayPool and MemoryPool](./arraypool-and-memorypool.md)
