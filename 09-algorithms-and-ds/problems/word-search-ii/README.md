# Word Search II

**Source:** LeetCode #212
**Difficulty:** 🔴 Hard
**Topics:** Trie, Matrix, DFS Backtracking

## Problem Statement

Given an `m × n` board of characters and a list of strings `words`, return all words on the board. Each word must be constructed from letters of sequentially adjacent cells (horizontally or vertically). The same cell may not be used more than once per word.

## Examples

```
Input:
board = [["o","a","a","n"],["e","t","a","e"],["i","h","k","r"],["i","f","l","v"]]
words = ["oath","pea","eat","rain"]
Output: ["eat","oath"]
```

## Constraints

- `1 <= m, n <= 12`; board contains lowercase letters; `1 <= words.Length <= 3 × 10⁴`; `1 <= words[i].Length <= 10`.

---

## Approach: Trie + DFS Backtracking — O(m·n·4·3^(L-1)) time ✓

Build a Trie from all words. DFS from every board cell, navigating the Trie simultaneously. When a word-end marker is reached, add to results and **prune** the Trie node to avoid duplicates.

```csharp
public class TrieNode
{
    public TrieNode?[] Children = new TrieNode[26];
    public string? Word; // non-null at end of word
}

public static IList<string> FindWords(char[][] board, string[] words)
{
    var root = new TrieNode();
    foreach (var w in words)
    {
        var node = root;
        foreach (char c in w)
        {
            int idx = c - 'a';
            node.Children[idx] ??= new TrieNode();
            node = node.Children[idx]!;
        }
        node.Word = w;
    }

    int m = board.Length, n = board[0].Length;
    var result = new List<string>();

    void Dfs(TrieNode node, int r, int c)
    {
        if (r < 0 || r >= m || c < 0 || c >= n) return;
        char ch = board[r][c];
        if (ch == '#') return; // visited
        var child = node.Children[ch - 'a'];
        if (child is null) return;

        if (child.Word is not null)
        {
            result.Add(child.Word);
            child.Word = null; // deduplicate
        }

        board[r][c] = '#';
        Dfs(child, r+1, c); Dfs(child, r-1, c);
        Dfs(child, r, c+1); Dfs(child, r, c-1);
        board[r][c] = ch; // restore
    }

    for (int r = 0; r < m; r++)
    for (int c = 0; c < n; c++)
        Dfs(root, r, c);

    return result;
}
```

---

## Complexity Summary

| Approach          | Time                   | Space     |
|-------------------|------------------------|-----------|
| Trie + DFS        | O(m·n·4·3^(L-1))       | O(W·L)    |

*L = max word length, W = number of words.*

---

## Interview Tips

- Without a Trie, you'd restart DFS for every word — O(words × m × n × 4^L).
- **Prune Trie nodes** after finding a word — prevents reporting duplicates and speeds up future traversal.
- Mark visited cells with `#` in-place and restore on backtrack — avoids a `visited` array.
