# Creating a new stemcell line

1. Create a new branch from the passing commit you want to release from. Use `{os_name}-{os_version}/{major}.x` format for branch name (e.g. `ubuntu-xenial/1.x`).

    `git checkout -b <<BRANCH_NAME>> {commit}`

1. Add, commit, and push the new branch.

    ```
    git push origin <<BRANCH_NAME>>
    ```

1. Switch back to master branch

    ```
    git checkout master
    ```

1. On master, update `ci/{os_name}-{os_version}/configure-aggregated-pipeline.sh` with the new branch details using the previous release branch as an example. Specifically, be sure to update the interpolated variables for the correct branch. For `initial_version`, use the same value of the stemcell produced by the commit in the `master` pipeline (e.g. `2.0.0`).

    ```
    ./ci/{os_name}-{os_version}/configure-aggregated-pipeline.sh
    ```

1. Once configured, the stemcell should automatically trigger and create the next minor version of the stemcell (e.g. `2.1.0`).


# References

* [Stemcell Support Matrix](https://docs.google.com/spreadsheets/d/11LgvmuR-XxXpKB-UVi91FL0nkITGhoB-G1NHPwfnweo/edit) (internal only)
