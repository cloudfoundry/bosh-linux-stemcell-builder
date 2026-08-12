# Contributing to BOSH Linux Stemcell Builder

Branches are named for the Ubuntu release on which they are based:
- `ubuntu-<short_name>`

As of `2026-06-09` the following stemcell lines / branches are supported:
- Ubuntu Jammy / `ubuntu-jammy`
- Ubuntu Noble / `ubuntu-noble`
- Ubuntu Resolute / `ubuntu-resolute`

## Merge-Forward Strategy

This repository uses a **merge-forward** strategy to keep stemcell branches in sync.

**Branch order (oldest → newest):**

```
ubuntu-jammy → ubuntu-noble → ubuntu-resolute
```

### How it works

1. Open your PR against the **oldest applicable branch** (e.g. `ubuntu-jammy` if the change applies to all lines).
2. Merge it.
3. The merge-forward workflow automatically opens a PR merging that branch into the next one in the chain.
4. Merge the forwarded PR, which then triggers another forward merge to the next branch, and so on.

No labels are needed — every merged PR triggers an automatic forward merge.

### Clean vs. conflict merge-forwards

- **Clean merge** — the merge-forward PR is opened ready for review.
- **Conflict** — the merge-forward PR is opened as a draft. Check out the branch,
  perform the merge manually, resolve the conflicts, and mark the PR ready for review.

### Re-runs

The workflow is idempotent: if the merge-forward branch already exists (e.g. after a
failed run), re-running the workflow skips the merge step and only retries opening the PR.
