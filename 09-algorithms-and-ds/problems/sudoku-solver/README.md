# Sudoku Solver

**Source:** LeetCode #37
**Difficulty:** 🔴 Hard
**Topics:** Array, Backtracking, Constraint Propagation

## Problem Statement

Write a program to solve a Sudoku puzzle by filling the empty cells (denoted by `'.'`). A Sudoku solution must satisfy:
- Each row contains digits 1–9 without repetition.
- Each column contains digits 1–9 without repetition.
- Each of the nine 3×3 sub-boxes contains digits 1–9 without repetition.

It is guaranteed the input has a unique solution.

## Constraints

- Fixed `9 × 9` board; `'.'` marks empty cells.

---

## Approach: Backtracking with Constraint Sets — O(9^m) time, O(1) space

*m = number of empty cells (≤ 81).*

For each empty cell, try digits 1–9; skip if already used in the same row/col/box. Backtrack if no digit works.

```csharp
public static void SolveSudoku(char[][] board)
{
    var rows  = new HashSet<char>[9];
    var cols  = new HashSet<char>[9];
    var boxes = new HashSet<char>[9];
    for (int i = 0; i < 9; i++) { rows[i] = []; cols[i] = []; boxes[i] = []; }

    for (int r = 0; r < 9; r++)
    for (int c = 0; c < 9; c++)
    {
        char ch = board[r][c];
        if (ch == '.') continue;
        rows[r].Add(ch);
        cols[c].Add(ch);
        boxes[(r / 3) * 3 + c / 3].Add(ch);
    }

    Solve(board, rows, cols, boxes, 0, 0);
}

private static bool Solve(char[][] board, HashSet<char>[] rows, HashSet<char>[] cols,
                           HashSet<char>[] boxes, int row, int col)
{
    if (row == 9) return true;
    int nextRow = col == 8 ? row + 1 : row;
    int nextCol = col == 8 ? 0 : col + 1;

    if (board[row][col] != '.')
        return Solve(board, rows, cols, boxes, nextRow, nextCol);

    int boxIdx = (row / 3) * 3 + col / 3;
    for (char d = '1'; d <= '9'; d++)
    {
        if (rows[row].Contains(d) || cols[col].Contains(d) || boxes[boxIdx].Contains(d))
            continue;

        board[row][col] = d;
        rows[row].Add(d); cols[col].Add(d); boxes[boxIdx].Add(d);

        if (Solve(board, rows, cols, boxes, nextRow, nextCol)) return true;

        board[row][col] = '.';
        rows[row].Remove(d); cols[col].Remove(d); boxes[boxIdx].Remove(d);
    }
    return false;
}
```

---

## Complexity Summary

| Approach                     | Time     | Space |
|------------------------------|----------|-------|
| Backtracking + constraint sets | O(9^m) | O(1)  |

---

## Interview Tips

- Box index = `(row / 3) * 3 + col / 3` — memorise this formula.
- Pre-building constraint sets avoids re-scanning rows/cols/boxes on every check.
- **Advanced:** Arc consistency / constraint propagation (naked singles, hidden singles) can reduce backtracking dramatically.
