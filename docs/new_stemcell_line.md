# Creating a new stemcell line (for Trusty/CentOS 7)

1. From the main stemcells pipeline, find the corresponding `version`, e.g. `3468.0.0`, for the commit from which the branch should be created.

1. Edit `.envrc` to uncomment `RELEASE_BRANCH` and update its value with the version family (e.g. `3468.0.0` -> `3468.x`).

    `vim .envrc`

1. Be sure to update your environment with the new value.

    `direnv allow`

1. Create a new branch from the passing commit you want to branch.

    `git checkout -b $RELEASE_BRANCH {commit}`

1. Add, commit, and push the updated `.envrc` to the branch.

    ```
    git add .envrc
    git ci -m "Branch for $RELEASE_BRANCH"
    git push origin "$RELEASE_BRANCH"
    ```

1. Create the stemcell and OS image branch pipelines.

    ```
    ./ci/configure.sh
    ```

1. Review and unpause the new pipelines.


# Creating a new "single" stemcell line (for Xenial and beyond)

1. Create a new branch from the passing commit you want to release from. Use `{os_name}-{os_version}/{major}.x` format for branch name (e.g. `ubuntu-xenial/1.x`).

    `git checkout -b <<BRANCH_NAME>> {commit}`

1. Add, commit, and push the new branch.

    ```
    git push origin <<BRANCH_NAME>>
    ```

1. On master, update `ci/{os_name}-{os_version}/configure-aggregated-pipeline.sh` with the new branch details using the previous release branch as an example. Specifically, be sure to update the interpolated variables for the correct branch. For `initial_version`, use the same value of the stemcell produced by the commit in the `master` pipeline (e.g. `2.0.0`).

    ```
    ./ci/{os_name}-{os_version}/configure-aggregated-pipeline.sh
    ```

1. Once configured, the stemcell should automatically trigger and create the next minor version of the stemcell (e.g. `2.1.0`).


# References

* [Stemcell Support Matrix](https://docs.google.com/spreadsheets/d/11LgvmuR-XxXpKB-UVi91FL0nkITGhoB-G1NHPwfnweo/edit) (internal only)
