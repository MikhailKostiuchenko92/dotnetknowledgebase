# Replace Words

**Source:** LeetCode #648
**Difficulty:** 🟡 Medium
**Topics:** Trie, String, HashMap

## Problem Statement

Given a dictionary of root strings and a sentence, replace every word in the sentence with its shortest root from the dictionary. If no root matches, keep the original word.

## Examples

```
Input: dictionary = ["cat","bat","rat"], sentence = "the cattle was rattled by the battery"
Output: "the cat was rat by the bat"
```

## Constraints

- `1 <= dictionary.Length <= 1000`; `1 <= words.Length <= 1000`; `1 <= word.Length <= 100`.

---

## Approach: Trie — O(n + m) time, O(n) space ✓

*n = total characters in dictionary, m = characters in sentence.*

Insert all roots into a Trie. For each word in the sentence, traverse the Trie until either a root end is found (→ replace) or no match (→ keep).

```csharp
public static string ReplaceWords(IList<string> dictionary, string sentence)
{
    // Build Trie
    var root = new TrieNode();
    foreach (var word in dictionary)
    {
        var node = root;
        foreach (char c in word)
        {
            int idx = c - 'a';
            node.Children[idx] ??= new TrieNode();
            node = node.Children[idx]!;
        }
        node.IsEnd = true;
        node.Word  = word;
    }

    // Replace each word
    var words  = sentence.Split(' ');
    var result = new System.Text.StringBuilder();

    for (int i = 0; i < words.Length; i++)
    {
        if (i > 0) result.Append(' ');
        var node = root;
        string? replacement = null;
        foreach (char c in words[i])
        {
            int idx = c - 'a';
            if (node.Children[idx] is null) break;
            node = node.Children[idx]!;
            if (node.IsEnd) { replacement = node.Word; break; }
        }
        result.Append(replacement ?? words[i]);
    }
    return result.ToString();
}

private class TrieNode
{
    public TrieNode?[] Children = new TrieNode[26];
    public bool IsEnd;
    public string? Word;
}
```

---

## Complexity Summary

| Approach | Time     | Space |
|----------|----------|-------|
| Trie     | O(n + m) | O(n)  |

---

## Interview Tips

- The Trie automatically finds the **shortest** matching root (first `IsEnd` hit during traversal).
- **Alternative:** Sort roots by length, then HashSet prefix matching — O(n log n + m × maxLen).
