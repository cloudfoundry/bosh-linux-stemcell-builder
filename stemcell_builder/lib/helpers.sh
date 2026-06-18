function disable {
  if [ -e $1 ]
  then
    mv $1 $1.back
    ln -s /bin/true $1
  fi
}

function enable {
  if [ -L $1 ]
  then
    mv $1.back $1
  else
    # No longer a symbolic link, must have been overwritten
    rm -f $1.back
  fi
}

function run_in_chroot {
  local chroot=$1
  local script=$2

  # Disable daemon startup
  disable $chroot/sbin/initctl
  disable $chroot/usr/sbin/invoke-rc.d

  # unshare: isolate mounts + PID namespace (see comment in original helpers).
  # Inner shell must not read its script from stdin (heredoc): that breaks stdin for
  # nested pipelines (e.g. grub-mkpasswd-pbkdf2). Pass command via env instead.
  #
  # setsid -f -w: new session without a controlling tty so apt/dpkg stderr does not
  # trigger SIGTTOU (job-control stop, ps state T) under sudo / nested ptys.
  env RUN_IN_CHROOT_ROOT="$chroot" \
    RUN_IN_CHROOT_CMD="$script" \
    RUN_IN_CHROOT_HTTP_PROXY="${http_proxy:-}" \
    RUN_IN_CHROOT_HTTPS_PROXY="${https_proxy:-}" \
    RUN_IN_CHROOT_NO_PROXY="${no_proxy:-}" \
    setsid -f -w -- unshare -f -p -m /bin/bash -c '
    set -e
    chroot="$RUN_IN_CHROOT_ROOT"
    mkdir -p "$chroot/dev"
    mount -n --bind /dev "$chroot/dev"
    mount -n --bind /dev/shm "$chroot/dev/shm"
    mount -n --bind /dev/pts "$chroot/dev/pts"

    mkdir -p "$chroot/proc"
    mount -n --bind /proc "$chroot/proc"

    chroot "$chroot" env -i \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      DEBIAN_FRONTEND=noninteractive \
      SYSTEMD_OFFLINE=1 \
      http_proxy="$RUN_IN_CHROOT_HTTP_PROXY" \
      https_proxy="$RUN_IN_CHROOT_HTTPS_PROXY" \
      no_proxy="$RUN_IN_CHROOT_NO_PROXY" \
      bash -e -c "$RUN_IN_CHROOT_CMD"
  '

  # Enable daemon startup
  enable $chroot/sbin/initctl
  enable $chroot/usr/sbin/invoke-rc.d
}

declare -a on_exit_items
on_exit_items=()

function on_exit {
  echo "Running ${#on_exit_items[@]} on_exit items..."
  for i in "${on_exit_items[@]}"
  do
    for try in $(seq 0 9); do
      sleep $try
      echo "Running cleanup command $i (try: ${try})"
        eval $i || continue
      break
    done
  done
}

function add_on_exit {
  local n=${#on_exit_items[@]}
  if [[ $n -eq 0 ]]; then
    on_exit_items=("$*")
    trap on_exit EXIT
  else
    on_exit_items=("$*" "${on_exit_items[@]}")
  fi
}

curl_five_times() {
  output_filename="${1}"
  address="${2}"
  download_attempt_count=0
  set +e
  until [ $download_attempt_count -ge 5 ]
  do
    curl -L -o $output_filename ${address} && break
    download_attempt_count=$((download_attempt_count+1))
  done

  if [ ! -e ${output_filename} ]; then
    echo "Failed to download ${output_filename}"
    exit 1
  fi
  set -e
}

function is_x86_64() {
  if [ `uname -m` == "x86_64" ]; then
    return 0
  else
    return 1
  fi
}
