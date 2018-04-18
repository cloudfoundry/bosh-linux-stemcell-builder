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
    ./ci/os-image/configure.sh
    ```

1. Review and unpause the new pipelines.




# Creating a new "single" stemcell line (for Xenial and beyond)

1. Edit `.envrc` to uncomment and update `RELEASE_BRANCH`, `STEMCELL_OS`, `STEMCELL_OS_VERSION`, and optionally `INITIAL_STEMCELL_VERSION` following the example given.

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
    ./ci/single-stemcell/configure.sh
    ```

1. Review and unpause the new pipelines.


# References

* [Stemcell Support Matrix](https://docs.google.com/spreadsheets/d/11LgvmuR-XxXpKB-UVi91FL0nkITGhoB-G1NHPwfnweo/edit) (internal only)
