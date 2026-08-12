# Merge Forward

This repository uses a **merge-forward** strategy. Open your PR against the
**oldest applicable branch** and merge it — the workflow will automatically
open a PR merging it forward to the next branch in the chain:

```
ubuntu-jammy → ubuntu-noble → ubuntu-resolute
```

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

### AI Review Feedback

_All AI review comments (CodeRabbit, and Copilot when assigned) must be resolved before human reviewers will look at the PR. For each comment, either:_
- _Make the suggested change, or_
- _Reply to the comment explaining why it does not apply, then resolve the thread._
