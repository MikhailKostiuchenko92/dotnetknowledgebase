# Word Search

**Source:** LeetCode #79
**Difficulty:** 🟡 Medium
**Topics:** Array, String, DFS, Backtracking

## Problem Statement

Given an `m × n` grid of characters and a string `word`, return `true` if `word` exists in the grid. The word can be constructed from letters in sequentially adjacent cells (horizontally or vertically). Each cell may be used **once** per path.

## Examples

```
board = [["A","B","C","E"],["S","F","C","S"],["A","D","E","E"]]
Input: word = "ABCCED"   Output: true
Input: word = "SEE"      Output: true
Input: word = "ABCB"     Output: false
```

## Constraints

- `1 <= m, n <= 6`; `1 <= word.Length <= 15`

---

## Approach: DFS Backtracking — O(m · n · 4^L) time, O(L) space

*L = word length.*

```csharp
public static bool Exist(char[][] board, string word)
{
    int m = board.Length, n = board[0].Length;

    bool Dfs(int r, int c, int idx)
    {
        if (idx == word.Length) return true;
        if (r < 0 || r >= m || c < 0 || c >= n || board[r][c] != word[idx]) return false;

        char temp = board[r][c];
        board[r][c] = '#'; // mark visited

        bool found = Dfs(r+1, c, idx+1) || Dfs(r-1, c, idx+1) ||
                     Dfs(r, c+1, idx+1) || Dfs(r, c-1, idx+1);

        board[r][c] = temp; // restore
        return found;
    }

    for (int r = 0; r < m; r++)
    for (int c = 0; c < n; c++)
        if (Dfs(r, c, 0)) return true;

    return false;
}
```

---

## Complexity Summary

| Approach          | Time          | Space |
|-------------------|---------------|-------|
| DFS + Backtracking | O(m·n·4^L)   | O(L)  |

---

## Interview Tips

- Mark cells with `'#'` in-place to avoid a separate visited array; restore after backtracking.
- **Early termination:** if the word has more of a char than the board → return false immediately.
- **Related:** [Word Search II](../word-search-ii/README.md) — multiple words with a Trie.
