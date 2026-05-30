# Algorithms & Data Structures

> Coding problems with multiple C# solutions and complexity analysis.

## Questions

_No questions added yet. Use the [question template](../_templates/question-template.md) to add one._

## Index

<!-- Add links to question files as you create them -->

### Arrays & Strings
- [Two Sum](problems/two-sum/README.md) — HashMap O(n)
- [Reverse String In-Place](problems/reverse-string-in-place/README.md) — Span\<char\>
- [Valid Palindrome](problems/valid-palindrome/README.md) — Two-pointer
- [Find Maximum Element](problems/find-maximum-element/README.md) — Linear scan
- [Best Time to Buy and Sell Stock](problems/best-time-to-buy-and-sell-stock/README.md) — Greedy single pass
- [Best Time to Buy and Sell Stock II](problems/best-time-to-buy-and-sell-stock-ii/README.md) — Greedy all upslopes
- [Container With Most Water](problems/container-with-most-water/README.md) — Two-pointer
- [Product of Array Except Self](problems/product-of-array-except-self/README.md) — Prefix/suffix products
- [Longest Substring Without Repeating Characters](problems/longest-substring-without-repeating-characters/README.md) — Sliding window
- [Minimum Window Substring](problems/minimum-window-substring/README.md) — Sliding window + freq map
- [Trapping Rain Water](problems/trapping-rain-water/README.md) — Two-pointer / stack
- [Median of Two Sorted Arrays](problems/median-of-two-sorted-arrays/README.md) — Binary search O(log(m+n))
- [Longest Palindromic Substring](problems/longest-palindromic-substring/README.md) — Expand around center / Manacher's

### Hashing & Sets
- [Group Anagrams](problems/group-anagrams/README.md) — Sort-key HashMap
- [Contains Duplicate](problems/contains-duplicate/README.md) — HashSet
- [Valid Anagram](problems/valid-anagram/README.md) — Frequency array
- [Top K Frequent Elements](problems/top-k-frequent-elements/README.md) — Min-heap / bucket sort
- [Longest Consecutive Sequence](problems/longest-consecutive-sequence/README.md) — HashSet O(n)
- [3Sum](problems/three-sum/README.md) — Sort + two-pointer + dedup
- [Subarray Sum Equals K](problems/subarray-sum-equals-k/README.md) — Prefix sum + HashMap
- [Count of Range Sum](problems/count-of-range-sum/README.md) — Merge sort

### Sorting & Searching
- [Binary Search](problems/binary-search/README.md) — Iterative + boundary templates
- [First and Last Position in Sorted Array](problems/first-and-last-position-in-sorted-array/README.md) — Two binary searches
- [Search in Rotated Sorted Array](problems/search-in-rotated-sorted-array/README.md) — Modified binary search
- [Find Minimum in Rotated Sorted Array](problems/find-minimum-in-rotated-sorted-array/README.md) — Binary search on pivot
- [Kth Largest Element in Array](problems/kth-largest-element-in-array/README.md) — QuickSelect / min-heap
- [Sort Colors](problems/sort-colors/README.md) — Dutch National Flag
- [Merge Intervals](problems/merge-intervals/README.md) — Sort + greedy merge
- [Meeting Rooms II](problems/meeting-rooms-ii/README.md) — Min-heap / sweep line
- [Median from Data Stream](problems/median-from-data-stream/README.md) — Two heaps
- [Count Inversions in Array](problems/count-inversions-in-array/README.md) — Merge sort

### Linked Lists
- [Reverse Linked List](problems/reverse-linked-list/README.md) — Iterative & recursive
- [Detect Cycle in Linked List](problems/detect-cycle-in-linked-list/README.md) — Floyd's Tortoise & Hare
- [Merge Two Sorted Lists](problems/merge-two-sorted-lists/README.md) — Dummy head + iterative
- [Remove Nth Node From End](problems/remove-nth-node-from-end/README.md) — Two-pointer, one pass
- [Reorder List](problems/reorder-list/README.md) — Find middle → reverse → merge
- [Add Two Numbers](problems/add-two-numbers/README.md) — Digit-by-digit with carry
- [Find Cycle Start Node](problems/find-cycle-start-node/README.md) — Floyd's Phase 2
- [LRU Cache](problems/lru-cache/README.md) — Doubly linked list + Dictionary
- [Merge K Sorted Lists](problems/merge-k-sorted-lists/README.md) — Min-heap / divide & conquer
- [Reverse Nodes in k-Group](problems/reverse-nodes-in-k-group/README.md) — Iterative group reversal

### Stacks & Queues
- [Valid Parentheses](problems/valid-parentheses/README.md) — Stack
- [Queue Using Two Stacks](problems/queue-using-two-stacks/README.md) — Lazy transfer, O(1) amortised
- [Min Stack](problems/min-stack/README.md) — Auxiliary min stack
- [Evaluate Reverse Polish Notation](problems/evaluate-reverse-polish-notation/README.md) — Stack
- [Daily Temperatures](problems/daily-temperatures/README.md) — Monotonic decreasing stack
- [Next Greater Element](problems/next-greater-element/README.md) — Monotonic stack + HashMap
- [Largest Rectangle in Histogram](problems/largest-rectangle-in-histogram/README.md) — Monotonic increasing stack
- [Sliding Window Maximum](problems/sliding-window-maximum/README.md) — Monotonic deque O(n)
- [Basic Calculator II](problems/basic-calculator-ii/README.md) — Stack + pending operator

### Binary Trees
- [Maximum Depth of Binary Tree](problems/maximum-depth-of-binary-tree/README.md) — DFS/BFS
- [Invert Binary Tree](problems/invert-binary-tree/README.md) — Recursive DFS
- [Symmetric Tree](problems/symmetric-tree/README.md) — Mirror DFS / BFS
- [Binary Tree Level Order Traversal](problems/binary-tree-level-order-traversal/README.md) — BFS
- [Binary Tree Zigzag Level Order](problems/binary-tree-zigzag-level-order/README.md) — BFS + direction flag
- [Validate Binary Search Tree](problems/validate-binary-search-tree/README.md) — Range check DFS
- [Lowest Common Ancestor of BST](problems/lowest-common-ancestor-bst/README.md) — BST property O(h)
- [Lowest Common Ancestor of Binary Tree](problems/lowest-common-ancestor-binary-tree/README.md) — Post-order DFS
- [Diameter of Binary Tree](problems/diameter-of-binary-tree/README.md) — DFS height + global max
- [Path Sum II](problems/path-sum-ii/README.md) — DFS backtracking
- [Construct Tree from Preorder/Inorder](problems/construct-binary-tree-from-preorder-inorder/README.md) — HashMap + DFS
- [Binary Tree Maximum Path Sum](problems/binary-tree-maximum-path-sum/README.md) — Post-order DFS

### BST & Advanced Trees
- [Serialize and Deserialize Binary Tree](problems/serialize-and-deserialize-binary-tree/README.md) — BFS or DFS encoding
- [Search in BST](problems/search-in-bst/README.md) — Iterative O(h)
- [Kth Smallest in BST](problems/kth-smallest-element-in-bst/README.md) — In-order traversal
- [Insert / Delete in BST](problems/insert-delete-in-bst/README.md) — Recursive O(h)
- [Convert Sorted Array to BST](problems/convert-sorted-array-to-bst/README.md) — Divide & conquer
- [Balance a BST](problems/balance-a-bst/README.md) — In-order + rebuild
- [Count of Smaller Numbers After Self](problems/count-of-smaller-numbers-after-self/README.md) — Merge sort / BIT
- [Range Sum Query Mutable](problems/range-sum-query-mutable/README.md) — Fenwick Tree / Segment Tree

### Graphs
- [Number of Islands](problems/number-of-islands/README.md) — DFS/BFS flood fill
- [Clone Graph](problems/clone-graph/README.md) — DFS + HashMap
- [Course Schedule](problems/course-schedule/README.md) — Cycle detection, Kahn's BFS
- [Course Schedule II](problems/course-schedule-ii/README.md) — Topological order
- [Pacific Atlantic Water Flow](problems/pacific-atlantic-water-flow/README.md) — Reverse multi-source BFS
- [Word Ladder](problems/word-ladder/README.md) — BFS shortest path
- [Graph Valid Tree](problems/graph-valid-tree/README.md) — Union-Find
- [Number of Connected Components](problems/number-of-connected-components/README.md) — Union-Find
- [Alien Dictionary](problems/alien-dictionary/README.md) — Topological sort
- [Word Search II](problems/word-search-ii/README.md) — Trie + DFS backtracking
- [Dijkstra's Shortest Path](problems/dijkstra-shortest-path/README.md) — Priority queue min-heap
- [Bellman-Ford](problems/bellman-ford/README.md) — Negative weights, cycle detection
- [Minimum Spanning Tree](problems/minimum-spanning-tree/README.md) — Prim's & Kruskal's

### Dynamic Programming — 1-D
- [Climbing Stairs](problems/climbing-stairs/README.md) — Fibonacci DP
- [House Robber](problems/house-robber/README.md) — 1-D DP, no adjacent
- [House Robber II](problems/house-robber-ii/README.md) — Circular array, two passes
- [Longest Increasing Subsequence](problems/longest-increasing-subsequence/README.md) — DP O(n²) / patience sort O(n log n)
- [Maximum Product Subarray](problems/maximum-product-subarray/README.md) — Track min & max
- [Word Break](problems/word-break/README.md) — DP + HashSet
- [Decode Ways](problems/decode-ways/README.md) — DP with '0' edge cases
- [Coin Change](problems/coin-change/README.md) — Unbounded knapsack DP
- [Longest Valid Parentheses](problems/longest-valid-parentheses/README.md) — Stack / two counters
- [Jump Game II](problems/jump-game-ii/README.md) — Greedy BFS

### Dynamic Programming — 2-D & Interval
- [Unique Paths](problems/unique-paths/README.md) — Grid DP / combinatorics
- [Minimum Path Sum](problems/minimum-path-sum/README.md) — In-place grid DP
- [Longest Common Subsequence](problems/longest-common-subsequence/README.md) — Classic 2-D DP
- [Edit Distance](problems/edit-distance/README.md) — Levenshtein 2-D DP
- [0/1 Knapsack](problems/01-knapsack/README.md) — 2-D DP / space-optimised 1-D
- [Count Palindromic Substrings](problems/palindromic-substrings-count/README.md) — Expand around centre
- [Burst Balloons](problems/burst-balloons/README.md) — Interval DP
- [Regular Expression Matching](problems/regular-expression-matching/README.md) — 2-D DP
- [Wildcard Matching](problems/wildcard-matching/README.md) — 2-D DP
- [Maximal Rectangle in Binary Matrix](problems/maximum-rectangle-in-binary-matrix/README.md) — Histogram stack

### Recursion & Backtracking
- [Permutations](problems/permutations/README.md) — Backtracking / swap-based
- [Subsets / Power Set](problems/subsets-power-set/README.md) — Backtracking / bitmask
- [Combination Sum](problems/combination-sum/README.md) — Backtracking, reuse allowed
- [Combination Sum II](problems/combination-sum-ii/README.md) — No reuse, dedup
- [Letter Combinations of a Phone Number](problems/letter-combinations-phone-number/README.md) — Backtracking
- [Generate Parentheses](problems/generate-parentheses/README.md) — Open/close counters
- [Sudoku Solver](problems/sudoku-solver/README.md) — Constraint sets backtracking
- [N-Queens](problems/n-queens/README.md) — Column + diagonal sets
- [Word Search](problems/word-search/README.md) — DFS backtracking on grid

### Tries
- [Implement Trie](problems/implement-trie/README.md) — Array-based TrieNode
- [Design Add and Search Words](problems/design-add-search-words-data-structure/README.md) — Trie + DFS wildcard
- [Word Search II](problems/word-search-ii/README.md) — Trie + DFS backtracking (also in Graphs)
- [Replace Words](problems/replace-words/README.md) — Trie prefix replacement

### Heaps & Priority Queues
- [Kth Largest in Stream](problems/kth-largest-in-stream/README.md) — Min-heap of size k
- [Top K Frequent Words](problems/top-k-frequent-words/README.md) — Min-heap of size k
- [Median from Data Stream](problems/find-median-from-data-stream-heap/README.md) — Two heaps
- [Merge K Sorted Lists](problems/merge-k-sorted-lists/README.md) — Min-heap (also in Linked Lists)

### Bit Manipulation
- [Single Number](problems/single-number/README.md) — XOR
- [Number of 1 Bits](problems/number-of-1-bits/README.md) — Brian Kernighan's trick
- [Reverse Bits](problems/reverse-bits/README.md) — Bit-by-bit / mask swapping
- [Missing Number](problems/missing-number/README.md) — XOR or Gauss formula
- [Sum of Two Integers](problems/sum-of-two-integers/README.md) — XOR carry

### Complexity & Algorithm Theory
- [Big-O, Big-Ω, Big-Θ Notation](big-o-notation.md)
- [Iterative vs Recursive](iterative-vs-recursive.md)
- [Amortised Analysis](amortised-analysis.md)
- [Hash Table vs Balanced BST](hash-table-vs-bst.md)
- [Stable vs Unstable Sorting](stable-vs-unstable-sorting.md)
- [In-Place vs Out-of-Place](in-place-vs-out-of-place.md)
- [P vs NP](p-vs-np.md)
- [NP-Complete Problems in Interviews](np-complete-problems.md)
- [Space-Time Trade-Off Patterns](space-time-tradeoffs.md)