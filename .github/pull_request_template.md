# Merge Forward

This repository uses a **merge-forward** strategy. Open your PR against the
**oldest applicable branch** and merge it. A maintainer then manually dispatches the
merge-forward workflow to open a PR into the next branch in the chain (for
`ubuntu-jammy` or `ubuntu-noble`; `ubuntu-resolute` is the end of the chain):

```text
ubuntu-jammy → ubuntu-noble → ubuntu-resolute
```

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

### AI Review Feedback

_All AI review comments (CodeRabbit, and Copilot when assigned) must be resolved before human reviewers will look at the PR. For each comment, either:_
- _Make the suggested change, or_
- _Reply to the comment explaining why it does not apply, then resolve the thread._
