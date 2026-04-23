NOTE: this repository uses a "Merge Forward" strategy

Changes should be made in the earliest applicable branch, and
merged forward through subsequent branches.
1. Create a PR into the oldest branch (`ubuntu-<short_name_0>`)
2. After this PR has been merged create a `merge-to-<next-short_name>` branch
3. Merge `ubuntu-<short_name_0>` into `merge-to-<next-short_name>`
4. Create a PR to merge `merge-to-<next-short_name>` into `ubuntu-<next-short_name>`
5. Repeat as needed for subsequent branches
