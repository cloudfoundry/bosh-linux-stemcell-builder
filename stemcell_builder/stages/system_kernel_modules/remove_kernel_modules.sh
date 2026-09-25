#!/usr/bin/env bash
#
# Usage: remove_kernel_modules.sh <modules_dir> <csv>
#
# Deletes the kernel modules marked remove=Yes in <csv> from <modules_dir>
# (e.g. $chroot/usr/lib/modules/<kernel-version>) and prunes empty directories.
#
# <csv> columns: module_name,rel_path,remove,category,reason
# rel_path is relative to <modules_dir>; remove is Yes or No.
#
# Every module in <modules_dir> must be listed in <csv>. If any are not, nothing
# is removed and the unlisted modules are reported so the CSV can be updated.

set -eu -o pipefail

modules_dir=$1
csv=$2
csv_repo_path="stemcell_builder/stages/system_kernel_modules/$(basename "$csv")"

export LC_ALL=C

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

invalid=$(awk -F, 'NR > 1 && $3 != "Yes" && $3 != "No" { print NR": "$0 }' "$csv")
if [ -n "$invalid" ]; then
  echo "ERROR: rows in ${csv_repo_path} must have remove=Yes or remove=No:" >&2
  echo "$invalid" >&2
  exit 1
fi

awk -F, 'NR > 1 { print $2 }' "$csv" | sort -u > "$tmp/listed"
awk -F, 'NR > 1 && $3 == "Yes" { print $2 }' "$csv" | sort -u > "$tmp/remove"
(cd "$modules_dir" && find . -type f -name '*.ko*' | sed 's#^\./##') | sort > "$tmp/present"

comm -23 "$tmp/present" "$tmp/listed" > "$tmp/unlisted"
if [ -s "$tmp/unlisted" ]; then
  {
    echo "ERROR: $(wc -l < "$tmp/unlisted" | tr -d ' ') kernel modules in ${modules_dir} are not listed in ${csv_repo_path}."
    echo "Add a row for each of these modules with remove=Yes or remove=No:"
    sed 's/^/  /' "$tmp/unlisted"
  } >&2
  exit 1
fi

comm -13 "$tmp/present" "$tmp/listed" > "$tmp/stale"
if [ -s "$tmp/stale" ]; then
  echo "WARNING: $(wc -l < "$tmp/stale" | tr -d ' ') modules listed in ${csv_repo_path} are not present in ${modules_dir}:"
  sed 's/^/  /' "$tmp/stale"
fi

comm -12 "$tmp/present" "$tmp/remove" > "$tmp/delete"
(cd "$modules_dir" && tr '\n' '\0' < "$tmp/delete" | xargs -0 rm -f)
find "$modules_dir" -mindepth 1 -type d -empty -delete

echo "Removed $(wc -l < "$tmp/delete" | tr -d ' ') kernel modules from ${modules_dir};" \
  "$(comm -23 "$tmp/present" "$tmp/delete" | wc -l | tr -d ' ') remain."
