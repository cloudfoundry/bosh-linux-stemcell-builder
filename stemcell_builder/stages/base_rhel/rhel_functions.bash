#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# function rhsm_register calls `subscription-manager register`
# (ignoring ANY failures of that command).
# NOTE: This function uses the following ENV vars: RHN_USERNAME, RHN_PASSWORD.
# seealso: function rhsm_unregister
function rhsm_register {
  # HACK: We simply ignore ANY failure of the `subscription-manager register` command and continue.
  # This relies on subsequent scripts/commands (e.g. the `rhsm_enable_repo` func) to fail (and NOT continue)
  # if the registration failed for any other reason (i.e. failed for a reason other than 'already registered').
  # TODO: It would be better if we could make this function truly idempotent, such that the registration would only be
  # attempted if not already registered, so that other kinds of registration failures could be NOT ignored here.
  # NOTE: `subscription-manager register --force` is NOT idempotent. So `--force` isn't a viable option for making this function idempotent.
  #   > `--force` Registers the system even if it is already registered. Normally, any register operations will fail if the machine is already registered. With --force, the existing consumer entry is unregistered first, all of its subscriptions are returned to the pool, and then the consumer is registered as a new consumer.
  # see: https://linux.die.net/man/8/subscription-manager
  set +e # errexit

  # NOTE: Normally, any register operations will fail if the machine is already registered.
  # see: https://linux.die.net/man/8/subscription-manager
  run_in_chroot "$chroot" "subscription-manager register --username=${RHN_USERNAME} --password=${RHN_PASSWORD} --auto-attach"

  set -e # errexit
}

# function rhsm_unregister unregisters the system from the RHSM subscriptions.
# seealso: function rhsm_register
# (ignoring ANY failures of that command).
# NOTE: This function uses the following ENV vars: RHN_USERNAME, RHN_PASSWORD.
function rhsm_unregister {
  run_in_chroot "$chroot" "
    subscription-manager remove --all
    subscription-manager unregister
    "
}

# function rhsm_enable_repo ensures that the given package repository is enabled.
# $1: The package repository name.
# NOTE: This function will fail if the system is not already registered with RHSM. See function `rhsm_register`.
function rhsm_enable_repo {
  repo_name="$1"
  run_in_chroot "$chroot" "subscription-manager repos --enable=${repo_name}"
}

# function rhsm_enable_base_repos ensures that all "base" package repositories are enabled.
# SEE: https://access.redhat.com/solutions/265523 (section 'Commonly used repositories')
# > The repositories you want to enable are going to be dependent on the packages you need to install and the product you are using.
# NOTE: Calling this function is typically optional, since the base repos should normally be enabled by default.
function rhsm_enable_base_repos {
  # NOTE: The '69.pem' file is created by the base_rhel stage.
  run_in_chroot $chroot "
    if rct cat-cert /etc/pki/product/69.pem | grep -q rhel-7-server; then
      subscription-manager repos --enable=rhel-7-server-rpms
    elif rct cat-cert /etc/pki/product/69.pem | grep -q rhel-8; then
      # NOTE: BaseOS and AppStream contain all software packages, which were available in extras and optional repositories before.
      # see: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/considerations_in_adopting_rhel_8/repositories_considerations-in-adopting-rhel-8
      # > Both repositories are required for a basic RHEL installation, and are available with all RHEL subscriptions.
      subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
      subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
    else
      echo 'Product certificate from /mnt/rhel/repodata/productid is not for RHEL 7 or RHEL 8 server.'
      echo 'Please ensure you have mounted the RHEL 7 or RHEL 8 Server install DVD at /mnt/rhel.'
      exit 1
    fi
    "
}

# function rhsm_enable_dev_repos ensures that all "dev" package repositories are enabled.
# SEE: https://access.redhat.com/solutions/265523 (section 'Commonly used repositories')
# > The repositories you want to enable are going to be dependent on the packages you need to install and the product you are using.
function rhsm_enable_dev_repos {
  # NOTE: The '69.pem' file is created by the base_rhel stage.
  run_in_chroot $chroot "
    if rct cat-cert /etc/pki/product/69.pem | grep -q rhel-7-server; then
      subscription-manager repos --enable=rhel-7-server-optional-rpms
    elif rct cat-cert /etc/pki/product/69.pem | grep -q rhel-8; then
      # > the CodeReady Linux Builder repository is available with all RHEL subscriptions. It provides additional packages for use by developers. Packages included in the CodeReady Linux Builder repository are unsupported.
      subscription-manager repos --enable=codeready-builder-for-rhel-8-x86_64-rpms
    else
      echo 'Product certificate from /mnt/rhel/repodata/productid is not for RHEL 7 or RHEL 8 server.'
      echo 'Please ensure you have mounted the RHEL 7 or RHEL 8 Server install DVD at /mnt/rhel.'
      exit 1
    fi
    "
}
