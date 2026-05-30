# Range and Index Operators

**Category:** C# / Language Features
**Difficulty:** Junior
**Tags:** `range`, `index`, `span`, `string`

## Question
> What do the C# index (`^`) and range (`..`) operators do?
>
> Which types support `^` and `..`, and how do arrays, strings, spans, and custom types participate?
>
> When should I use slices with ranges instead of manual `Substring` or index math?

## Short Answer
`^` counts from the end, and `..` describes a slice range. In .NET 8/9 they work naturally with arrays, strings, `Span<T>`, `ReadOnlySpan<T>`, and other types that expose the expected length and indexer or slice members, making slicing code shorter, safer, and easier to read than manual offset arithmetic.

## Detailed Explanation
### Core meaning of `^` and `..`
`^1` means “the last element,” `^2` means “second from the end,” and `start..end` means “from start up to, but not including, end.”

| Expression | Meaning |
| --- | --- |
| `items[^1]` | Last element |
| `items[^2]` | Second-to-last element |
| `items[1..4]` | Elements at indexes 1, 2, and 3 |
| `items[..3]` | From start through index 2 |
| `items[2..]` | From index 2 to the end |
| `items[..]` | Entire sequence or view |

This feature reduces off-by-one mistakes because the intent is more obvious than hand-written `Length - 1` arithmetic.

> Tip: ranges express a half-open interval: start is included, end is excluded. That is the key rule to remember in interviews.

### Supported types and behavior
The language pattern works with built-in types and with custom types that expose the right shape.

| Type | Supports `^` | Supports `..` | Notes |
| --- | --- | --- | --- |
| Array | Yes | Yes | Range creates a new array copy |
| `string` | Yes | Yes | Range creates a new string |
| `Span<T>` / `ReadOnlySpan<T>` | Yes | Yes | Slice is a view, not a copy |
| `List<T>` | No built-in range indexer | No built-in range indexer | Use methods like `GetRange` instead |
| Custom type | If it exposes `Length`/`Count` and indexer or `Slice` support | Yes, with the pattern | Good library-design technique |

Because spans return views, range operations on spans are especially efficient in hot paths.

### Custom support and trade-offs
A custom type can support these operators by providing the appropriate members, commonly `Length` or `Count`, an indexer taking `Index`, and optionally a slicing member for `Range`.

> Warning: do not assume all collections support `..`. `List<T>` is the classic gotcha. The syntax is language-level, but the target type still needs the right members.

## Code Example
```csharp
using System;

int[] numbers = [10, 20, 30, 40, 50];
Console.WriteLine(numbers[^1]); // 50
Console.WriteLine(string.Join(", ", numbers[1..4])); // 20, 30, 40

string word = "iterator";
Console.WriteLine(word[..4]);   // iter
Console.WriteLine(word[^3..]);  // tor

Span<int> span = numbers;
Span<int> middle = span[1..^1]; // View over 20, 30, 40 - no new array.
Console.WriteLine(middle.Length);

var buffer = new LetterBuffer("abcdef");
Console.WriteLine(buffer[^1]);
Console.WriteLine(buffer[1..4]);

readonly struct LetterBuffer
{
    private readonly string _value;

    public LetterBuffer(string value)
    {
        _value = value;
    }

    public int Length => _value.Length;

    public char this[Index index] => _value[index];

    public string this[Range range] => _value[range]; // Delegates to string slicing.
}
```

## Common Follow-up Questions
- Why is the end of a range excluded?
- What is the difference between slicing an array and slicing a `Span<T>`?
- Why does `List<T>` not support the range indexer syntax by default?
- How can a custom type opt into `Index` and `Range` support?
- When is `Substring` still acceptable compared to range syntax?

## Common Mistakes / Pitfalls
- Forgetting that the end index is excluded.
- Assuming `^1` means “one past the end” instead of “last element.”
- Expecting `List<T>` to support `items[1..3]` like arrays do.
- Missing the copy-vs-view difference between arrays/strings and spans.
- Writing unclear manual index math when `^` or `..` would express intent better.

## References
- [Microsoft Docs: Member access operators `.` `[]` `..` and `^`](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/member-access-operators)
- [Microsoft Docs: Ranges and indices](https://learn.microsoft.com/dotnet/csharp/language-reference/language-specification/ranges)
- [See: Custom Iterators](./custom-iterators.md)
- [See: Enumerator vs Enumerable](./enumerator-vs-enumerable.md)
