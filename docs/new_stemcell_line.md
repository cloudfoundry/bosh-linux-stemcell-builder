# Creating a new stemcell line

1. Create a new branch from the passing commit you want to release from. Use `ubuntu-${short_name}` format for branch name.

   ```shell
   export short_name="jammy"
   
   git switch -c ubuntu-${short_name} {commit}
   ```

2. Update `ci/pipelines/vars.yml` with the appropriate values

    ```yaml
    #@data/values
    stemcell_details:
      branch: ubuntu-jammy
    # ...
    blobstore_types:
      - dav
    # ...
    ```

3. Update `STEMCELL_LINE` in `ci/configure.sh`:
 
    ```shell
    STEMCELL_LINE="ubuntu-${short_name}"
    ```

4. Add, commit, and push the new branch.

    ```shell
    git push --set-upstream origin HEAD
    ```
5. Configure the new pipeline:

    ```shell
    ./ci/configure.sh
    ```

6. Once configured, the stemcell pipeline should automatically trigger.
