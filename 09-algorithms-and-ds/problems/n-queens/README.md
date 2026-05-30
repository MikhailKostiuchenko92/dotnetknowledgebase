# N-Queens

**Source:** LeetCode #51
**Difficulty:** 🔴 Hard
**Topics:** Array, Backtracking

## Problem Statement

The N-Queens puzzle: place `n` queens on an `n × n` chessboard so that no two queens attack each other (no two share a row, column, or diagonal). Return all distinct solutions.

## Examples

```
Input: n = 4
Output: [[".Q..","...Q","Q...","..Q."],["..Q.","Q...","...Q",".Q.."]]
```

## Constraints

- `1 <= n <= 9`

---

## Approach: Backtracking with Column and Diagonal Sets — O(n!) time, O(n) space ✓

Place one queen per row. Use sets to track occupied columns, positive diagonals (`r - c`), and negative diagonals (`r + c`).

```csharp
public static IList<IList<string>> SolveNQueens(int n)
{
    var result   = new List<IList<string>>();
    var cols     = new HashSet<int>();
    var diag1    = new HashSet<int>(); // r - c
    var diag2    = new HashSet<int>(); // r + c
    var board    = new int[n];         // board[r] = column of queen in row r

    void Backtrack(int row)
    {
        if (row == n)
        {
            var solution = new string[n];
            for (int r = 0; r < n; r++)
            {
                var row2 = new char[n];
                Array.Fill(row2, '.');
                row2[board[r]] = 'Q';
                solution[r] = new string(row2);
            }
            result.Add(solution);
            return;
        }

        for (int col = 0; col < n; col++)
        {
            if (cols.Contains(col) || diag1.Contains(row - col) || diag2.Contains(row + col))
                continue;

            cols.Add(col); diag1.Add(row - col); diag2.Add(row + col);
            board[row] = col;
            Backtrack(row + 1);
            cols.Remove(col); diag1.Remove(row - col); diag2.Remove(row + col);
        }
    }

    Backtrack(0);
    return result;
}
```

---

## Complexity Summary

| Approach         | Time  | Space |
|------------------|-------|-------|
| Backtracking     | O(n!) | O(n)  |

---

## Interview Tips

- **Diagonal key:** `r - c` is constant along `/` diagonals; `r + c` is constant along `\` diagonals.
- One queen per row eliminates one dimension — we only iterate columns.
- **N-Queens II** (LeetCode #52) just counts solutions — same backtracking, no board building.
