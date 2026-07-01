NOTE: this repository uses a "Merge Forward" strategy

Changes should be made in the earliest applicable branch, and
merged forward through subsequent branches.
1. Create a PR into the oldest branch (`ubuntu-<short_name>`)
2. After this PR has been merged create a `merge-to-<next_short_name>` branch
3. Merge `ubuntu-<short_name>` into `merge-to-<next_short_name>`
4. Create a PR to merge `merge-to-<next_short_name>` into `ubuntu-<next_short_name>`
5. Repeat as needed for subsequent branches

### AI Review Feedback

_All AI review comments (CodeRabbit, and Copilot when assigned) must be resolved before human reviewers will look at the PR. For each comment, either:_
- _Make the suggested change, or_
- _Reply to the comment explaining why it does not apply, then resolve the thread._
