#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# function safe_overwrite overwrites file $1 with content $2, and is safe for use even with broken symlinks.
# If $1 is a broken symlink and the link's target file's directory doesn't exist, both the dir and file will be created.
function safe_overwrite {
  file=$1
  content=$2
  if [ -f "$file" ]; then
    # $file is an existing file, so it (or it's target if it is a symlink) gets overwritten
    echo "$content" > "$file"
  elif [ -L "$file" ] && [ -d $(dirname $(readlink "$file")) ]; then
    # $file is a broken symlink to a file in an existing dir, so the target file gets created
    echo "$content" > "$file"
  elif [ ! -L "$file" ]; then
    # $file doesn't exist (and is not a symlink), so it gets created as a normal file
    echo "$content" > "$file"
  else
    # $file is a broken symlink to a file in a non-existing dir, so:
    # creating the target file's parent dir
    mkdir -p $(dirname $(readlink "$file"))
    # create the target file
    echo "$content" > "$file"
  fi
}

echo 'Overriding for Control-Alt-Delete'
if [ "${stemcell_operating_system}" == "ubuntu" ]; then
  # stig: V-38668
  mkdir -p $chroot/etc/init
  echo 'exec /usr/bin/logger -p security.info "Control-Alt-Delete pressed"' > $chroot/etc/init/control-alt-delete.override
elif [ "${stemcell_operating_system}" == "centos" ] || [ "${stemcell_operating_system}" == "rhel" ]; then
  # stig: V-38668
  # NOTE: On some platforms, 'ctrl-alt-del.target' is a symlink, and on other platforms it is a regular file.
  # When it is a symlink to a location inside of $chroot, writing to the symlink affects both specs and VMs.
  # When it is a symlink to a location outside of $chroot, writing to the symlink will make the specs pass,
  # but won't affect VMs at runtime (since files outside of $chroot don't get copied over to the VM runtime env).
  # The spec (and the original code below) checks only "$chroot/etc/systemd/system/ctrl-alt-del.target" (now called "$target11").
  # E.g. On Centos 7, "$target11" is a regular file (not a symlink). Simply overwrite it to get the spec to pass.
  # E.g. On RHEL 8, "$target11" is a symlink to '/usr/lib/systemd/system/reboot.target' (outside of "$chroot"),
  # AND '/usr/lib/systemd/system/' does not exist (so writing to "$target11" would fail unless you create that dir first),
  # so the spec needs '/usr/lib/systemd/system/reboot.target' to have the correct content,
  # but VMs need "$chroot/usr/lib/systemd/system/reboot.target" to have the correct content.
  dir1="$chroot/etc/systemd/system/"
  dir2="$chroot/usr/lib/systemd/system/"
  filename1='ctrl-alt-del.target'
  filename2='reboot.target'
  target11="$dir1/$filename1"
  target12="$dir1/$filename2"
  target21="$dir2/$filename1"
  target22="$dir2/$filename2"

  # NOTE: Writing to all 4 file paths may alter < 4 files, if 2+ are symlinks to the same target path.
  file_content='# escaping ctrl alt del'
  safe_overwrite "$target11" "$file_content"
  safe_overwrite "$target12" "$file_content"
  safe_overwrite "$target21" "$file_content"
  safe_overwrite "$target22" "$file_content"

  if [ "${stemcell_operating_system}" == "rhel" ] ; then
    # stig: V-230531: The systemd Ctrl-Alt-Delete burst key sequence in RHEL 8 must be disabled.
    # NOTE: stig V-230531 explicitly targets RHEL 8, but the vulnerability affects RHEL 7.4 and later.
    # see: https://www.stigviewer.com/stig/red_hat_enterprise_linux_8/2021-12-03/finding/V-230531
    system_conf=$chroot/etc/systemd/system.conf
    if [[ -e $system_conf ]]; then
      sudo sed -i 's/^#?CtrlAltDelBurstAction=.*/CtrlAltDelBurstAction=none/' $system_conf
      if ! grep -q -e '^CtrlAltDelBurstAction=none$' $system_conf; then
        sudo echo 'CtrlAltDelBurstAction=none' >> $system_conf
      fi
    else
      sudo echo 'CtrlAltDelBurstAction=none' > $system_conf
    fi
  fi
fi
