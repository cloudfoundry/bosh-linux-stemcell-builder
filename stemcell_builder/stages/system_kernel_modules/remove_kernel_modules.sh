#!/usr/bin/env bash
#
# Usage: remove_kernel_modules.sh <modules_dir> <csv>
#
# Deletes the kernel modules marked remove=Yes in <csv> from <modules_dir>
# (e.g. $chroot/usr/lib/modules/<kernel-version>) and prunes empty directories.
#
# <csv> columns: module_name,rel_path,remove,category,reason
# rel_path is relative to <modules_dir>; remove is Yes or No. A rel_path listed
# more than once must have the same remove value in every row.
#
# Every module in <modules_dir> must be listed in <csv>. If any are not, nothing
# is removed and the unlisted modules are reported so the CSV can be updated.
#
# A module marked remove=No must not depend (per <modules_dir>/modules.dep, or
# softly per <modules_dir>/modules.softdep) on a module marked remove=Yes. If one
# does, nothing is removed and the broken dependencies are reported.

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

conflicting=$(awk -F, 'NR > 1 { if ($2 in seen && seen[$2] != $3) print $2; seen[$2] = $3 }' "$csv" | sort -u)
if [ -n "$conflicting" ]; then
  echo "ERROR: modules listed in ${csv_repo_path} with both remove=Yes and remove=No:" >&2
  echo "$conflicting" | sed 's/^/  /' >&2
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
    echo "To triage them, run scripts/retriage_kernel_modules.rb against this kernel's modules directory"
    echo "(on Linux; see the comments at the top of that script), then review the updated ${csv_repo_path}."
  } >&2
  exit 1
fi

comm -13 "$tmp/present" "$tmp/listed" > "$tmp/stale"
if [ -s "$tmp/stale" ]; then
  echo "WARNING: $(wc -l < "$tmp/stale" | tr -d ' ') modules listed in ${csv_repo_path} are not present in ${modules_dir}:"
  sed 's/^/  /' "$tmp/stale"
fi

if [ ! -f "$modules_dir/modules.dep" ]; then
  echo "ERROR: ${modules_dir}/modules.dep not found; run depmod before removing modules." >&2
  exit 1
fi
# modules.dep lines look like "kernel/fs/nfs/nfs.ko.zst: kernel/net/sunrpc/sunrpc.ko.zst ..."
awk -F': *' '
  NR == FNR { remove[$0] = 1; next }
  !($1 in remove) {
    n = split($2, deps, " ")
    for (i = 1; i <= n; i++) if (deps[i] in remove) print $1 " needs " deps[i]
  }
' "$tmp/remove" "$modules_dir/modules.dep" > "$tmp/broken"
# modules.softdep names modules, not paths: "softdep cifs pre: gcm ccm ..."
if [ -f "$modules_dir/modules.softdep" ]; then
  awk '
    function norm(s) { gsub(/-/, "_", s); return s }
    FILENAME == ARGV[1] { name = $0; sub(/.*\//, "", name); sub(/\.ko(\.[a-z]+)?$/, "", name); path[norm(name)] = $0; next }
    FILENAME == ARGV[2] { remove[$0] = 1; next }
    $1 == "softdep" && (norm($2) in path) && !(path[norm($2)] in remove) {
      for (i = 3; i <= NF; i++) {
        if ($i == "pre:" || $i == "post:" || $i ~ /^platform:/) continue
        dep = norm($i)
        if ((dep in path) && (path[dep] in remove)) print path[norm($2)] " needs " path[dep] " (softdep)"
      }
    }
  ' "$tmp/present" "$tmp/remove" "$modules_dir/modules.softdep" >> "$tmp/broken"
fi
sort -u -o "$tmp/broken" "$tmp/broken"
if [ -s "$tmp/broken" ]; then
  {
    echo "ERROR: $(wc -l < "$tmp/broken" | tr -d ' ') dependencies of remove=No modules are marked remove=Yes in ${csv_repo_path}."
    echo "Mark each needed module remove=No (or the dependent module remove=Yes):"
    sed 's/^/  /' "$tmp/broken"
  } >&2
  exit 1
fi

comm -12 "$tmp/present" "$tmp/remove" > "$tmp/delete"
(cd "$modules_dir" && tr '\n' '\0' < "$tmp/delete" | xargs -0 rm -f)
find "$modules_dir" -mindepth 1 -type d -empty -delete

echo "Removed $(wc -l < "$tmp/delete" | tr -d ' ') kernel modules from ${modules_dir};" \
  "$(comm -23 "$tmp/present" "$tmp/delete" | wc -l | tr -d ' ') remain."
