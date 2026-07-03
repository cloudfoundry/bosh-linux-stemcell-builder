# Contributing to BOSH Linux Stemcell Builder

Branches are named for the Ubuntu release on which they are based:
- `ubuntu-<short_name>`

As of `2026-06-09` the following stemcell lines / branches are supported:
- Ubuntu Jammy / `ubuntu-jammy`
- Ubuntu Noble / `ubuntu-noble`
- Ubuntu Resolute / `ubuntu-resolute`

## Backporting Changes Across Branches

When a change should apply to more than one stemcell line, open your PR against
the earliest applicable branch and use **backport labels** to request automatic
cherry-picks onto other branches.

### How to backport

1. Open your PR against the oldest applicable branch (e.g. `ubuntu-jammy`).
2. Add one or more backport labels before merging:

   | Label | Target branch |
   |---|---|
   | `backport/ubuntu-jammy` | `ubuntu-jammy` |
   | `backport/ubuntu-noble` | `ubuntu-noble` |
   | `backport/ubuntu-resolute` | `ubuntu-resolute` |

3. Merge the PR. The backport workflow opens a new PR for each labeled target
   automatically, titled `[Backport <target>] <your title>`.

### Clean vs. conflict backports

- **Clean cherry-pick** — the backport PR is opened ready for review.
- **Conflict** — the backport PR is opened as a draft. The PR body names the
  failing commit. Check out the branch, resolve the conflicts, and mark the PR
  ready for review.

### Re-runs

The workflow is idempotent: if the backport branch already exists (e.g. after a
failed run), re-running the workflow skips that target silently.
