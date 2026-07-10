NOTE: this repository uses a "Merge Forward" strategy

Changes should be made in the earliest applicable branch, and
merged forward through subsequent branches.
1. PR should be created against the oldest stemcell branch, ex: `ubuntu-<short_name-N>`
2. After this PR has been merged create a PR to merge `ubuntu-<short_name-N>` into `ubuntu-<short_name-N+1>`
3. Repeat as needed for subsequent stemcell line branches

### AI Review Feedback

_All AI review comments (CodeRabbit, and Copilot when assigned) must be resolved before human reviewers will look at the PR. For each comment, either:_
- _Make the suggested change, or_
- _Reply to the comment explaining why it does not apply, then resolve the thread._
