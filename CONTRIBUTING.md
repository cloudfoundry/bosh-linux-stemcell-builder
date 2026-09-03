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

```text
ubuntu-jammy → ubuntu-noble → ubuntu-resolute
```

### How it works

1. Open your PR against the **oldest applicable branch** (e.g. `ubuntu-jammy` if the change applies to all lines).
2. Merge it.
3. A maintainer manually dispatches `.github/workflows/merge-forward.yml` with `source_branch` set to the merged branch. Optionally, set `validated_sha` to the commit that passed Concourse validation (`aggregate-candidate-stemcells`) — when provided, the workflow merges from that exact SHA rather than the branch tip.
4. Merge the forwarded PR, then repeat from step 3 for the next branch in the chain.

No labels are needed. After each relevant merge, a maintainer dispatches the workflow to create the forward PR.

### Clean vs. conflict merge-forwards

- **Clean merge** — the merge-forward PR is opened ready for review.
- **Conflict** — the merge-forward PR is opened as a draft. Check out the branch,
  perform the merge manually, resolve the conflicts, and mark the PR ready for review.

### Re-runs

The workflow is idempotent: if the merge-forward branch already exists but has no
associated PR (i.e. the branch was pushed but PR creation failed on a previous run),
re-running retries opening the PR without re-doing the merge. If a PR already exists
(open), the run skips silently.

### CI on merge-forward PRs

GitHub suppresses workflow runs triggered by a `GITHUB_TOKEN`-pushed branch. This
means the merge-forward PR will not have CI results initially. A
maintainer can start CI by pushing a trivial commit to the forward branch.
