#!/bin/bash

set -e

show_help() {
    cat <<EOF
Usage: $0 [STEMCELL_PATH] [options]

Arguments:
  STEMCELL_PATH             Path to the stemcell tarball (required)

Options:
  --help, -h                Show this help message and exit
  --debug                   Enable debug mode
  --debug_pub_key FILE      Path to multiline public key file
  --bump-version            Bump the version in the stemcell with 0.0.<timestamp>

Requirements:
  - Passwordless sudo access (required for mount/chroot operations)
  - Dependencies: sudo, kpartx, qemu-img

Environment Variables (optional):
  AGENT_BINARY              Path to the agent binary to be copied into the stemcell
  AGENT_JSON                Path to the agent JSON configuration file
  BOSH_DEBUG_PUB_KEY        Public key for the BOSH debug user (single line)

Supported Stemcell Types:
  - warden-boshlite         Direct filesystem
  - google-kvm              disk.raw
  - aws-xen-hvm             root.img
  - azure-hyperv            root.vhd
  - vsphere-esxi            image-disk1.vmdk

Examples:
  # Basic repack with version bump
  $0 tmp/bosh-stemcell-0.0.8-google-kvm-ubuntu-noble.tgz --bump-version

  # Repack with custom agent binary
  AGENT_BINARY=/path/to/bosh-agent $0 tmp/stemcell.tgz --bump-version

  # Repack with debug SSH key
  $0 tmp/stemcell.tgz --debug_pub_key ~/.ssh/id_rsa.pub --bump-version
EOF
}

check_dependencies() {
    local missing_deps=()
    
    command -v sudo >/dev/null 2>&1 || missing_deps+=(sudo)
    command -v kpartx >/dev/null 2>&1 || missing_deps+=(kpartx)
    command -v qemu-img >/dev/null 2>&1 || missing_deps+=(qemu-img)
    command -v tar >/dev/null 2>&1 || missing_deps+=(tar)
    command -v file >/dev/null 2>&1 || missing_deps+=(file)
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        cat >&2 <<EOF
Error: This script requires passwordless sudo access

To configure passwordless sudo, run:

  # Option 1: Allow passwordless sudo for your user (all commands)
  sudo bash -c 'echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} && chmod 0440 /etc/sudoers.d/${USER}'

  # Option 2: Allow passwordless sudo for specific commands only (more secure)
  sudo bash -c 'echo "${USER} ALL=(ALL) NOPASSWD: /usr/sbin/kpartx, /usr/bin/mount, /usr/bin/umount, /usr/bin/chroot, /usr/bin/cp, /usr/bin/tee, /usr/bin/tar, /usr/bin/chown" > /etc/sudoers.d/${USER} && chmod 0440 /etc/sudoers.d/${USER}'

After running the command, open a new terminal for the changes to take effect.
EOF
        exit 1
    fi
}

convert_multiline_to_single() {
    local input_file="$1"
    tr -d '\n' < "$input_file"
}

create_temp_dir() {
    local required_space="$1"
    local temp_location=""
    
    if [ -z "${required_space}" ]; then
        temp_location=""
    else
        local tmp_space
        tmp_space=$(df -B1 /tmp | tail -n1 | awk '{print $4}')
        
        if [ "${tmp_space}" -lt "${required_space}" ]; then
            mkdir -p "$PWD/tmp"
            temp_location="$PWD/tmp"
        fi
    fi
    
    [ -n "${temp_location}" ] && mktemp -d -p "${temp_location}" || mktemp -d
}

cleanup() {
    local cleanup_status=0
    
    if [ -n "${mnt_dir}" ] && [ -d "${mnt_dir}" ]; then
        if mountpoint -q "${mnt_dir}" 2>/dev/null; then
            sudo umount "${mnt_dir}" || { echo "Warning: Failed to unmount ${mnt_dir}" >&2; cleanup_status=1; }
        fi
        
        if [ -n "${image_dir}" ] && [ -n "${disk_image}" ] && [ -f "${image_dir}/${disk_image}" ]; then
            sudo kpartx -dv "${image_dir}/${disk_image}" 2>/dev/null || true
        fi
        
        sudo rm -rf "${mnt_dir}" || true
    fi
    
    if [ -n "${temp_dir}" ] && [ -d "${temp_dir}" ]; then
        sudo rm -rf "${temp_dir}" || true
    fi
    
    return ${cleanup_status}
}

detect_stemcell_type() {
    local image_dir="$1"
    local disk_image=""
    local original_disk_image=""
    local stemcell_type=""
    
    if [ -f "${image_dir}/disk.raw" ]; then
        disk_image="disk.raw"
        stemcell_type="google-kvm"
        echo "Detected google-kvm stemcell (disk.raw)" >&2
    elif [ -f "${image_dir}/root.img" ]; then
        disk_image="root.img"
        stemcell_type="aws"
        echo "Detected aws stemcell (root.img)" >&2
    elif [ -f "${image_dir}/root.vhd" ]; then
        disk_image="root.vhd"
        stemcell_type="azure"
        echo "Detected azure stemcell (root.vhd)" >&2
    elif [ -f "${image_dir}/image-disk1.vmdk" ]; then
        stemcell_type="vsphere"
        echo "Detected vsphere stemcell (image-disk1.vmdk)" >&2
        echo "Converting VMDK to raw format for mounting..." >&2
        qemu-img convert -f vmdk -O raw "${image_dir}/image-disk1.vmdk" "${image_dir}/disk-temp.raw"
        disk_image="disk-temp.raw"
        original_disk_image="image-disk1.vmdk"
    elif [ -d "${image_dir}/var" ]; then
        stemcell_type="warden"
        echo "Detected warden-boshlite stemcell (direct filesystem)" >&2
    else
        echo "Error: Unable to detect stemcell type" >&2
        exit 1
    fi
    
    echo "${stemcell_type}|${disk_image}|${original_disk_image}"
}

mount_disk_image() {
    local image_dir="$1"
    local disk_image="$2"
    local mnt_dir
    
    mnt_dir=$(create_temp_dir)
    
    local device
    device=$(sudo kpartx -sav "${image_dir}/${disk_image}" | grep '^add' | tail -n1 | cut -d' ' -f3)
    
    if [ -z "${device}" ]; then
        echo "Error: Failed to detect partition with kpartx" >&2
        exit 1
    fi
    
    if [ ! -e "/dev/mapper/${device}" ]; then
        echo "Error: Device /dev/mapper/${device} does not exist" >&2
        exit 1
    fi
    
    if ! sudo mount -o loop,rw "/dev/mapper/${device}" "${mnt_dir}"; then
        echo "Error: Failed to mount /dev/mapper/${device}" >&2
        sudo kpartx -dv "${image_dir}/${disk_image}" || true
        exit 1
    fi
    
    echo "${mnt_dir}"
}

unmount_disk_image() {
    local mnt_dir="$1"
    local image_dir="$2"
    local disk_image="$3"
    
    sudo umount "${mnt_dir}"
    sudo kpartx -dv "${image_dir}/${disk_image}"
}

repack_disk_image() {
    local stemcell_dir="$1"
    local image_dir="$2"
    local disk_image="$3"
    local original_disk_image="$4"
    
    if [ -n "${original_disk_image}" ]; then
        echo "Converting raw format back to VMDK..."
        qemu-img convert -f raw -O vmdk -o subformat=streamOptimized \
            "${image_dir}/${disk_image}" "${image_dir}/${original_disk_image}"
        rm -f "${image_dir}/${disk_image}"
        tar czf "${stemcell_dir}/image" -C "${image_dir}" image.ovf image.mf "${original_disk_image}"
    elif [ -f "${image_dir}/image.ovf" ]; then
        tar czf "${stemcell_dir}/image" -C "${image_dir}" image.ovf image.mf "${disk_image}"
    else
        tar czf "${stemcell_dir}/image" -C "${image_dir}" "${disk_image}"
    fi
}

repack_warden_image() {
    local stemcell_dir="$1"
    local image_dir="$2"
    
    set +e
    sudo tar czf "${stemcell_dir}/image" -C "${image_dir}" .
    local tar_exit=$?
    set -e
    
    sudo chown "$(whoami):" "${stemcell_dir}/image"
    
    if [ ! -f "${stemcell_dir}/image" ]; then
        echo "Error: tar failed and no image file was created"
        exit 1
    fi
    
    if [ ${tar_exit} -ne 0 ]; then
        echo "Warning: tar reported errors (likely device nodes) but image was created successfully"
    fi
}

trap cleanup EXIT

debug_pub_key_file=""
bump_version=false
positional_args=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --debug)
            set -x
            shift
            ;;
        --debug_pub_key)
            debug_pub_key_file="$2"
            shift 2
            ;;
        --bump-version)
            bump_version=true
            shift
            ;;
        *)
            positional_args+=("$1")
            shift
            ;;
    esac
done

if [ ${#positional_args[@]} -gt 0 ]; then
    stemcell_tgz="${positional_args[0]}"
fi

if [ -z "${stemcell_tgz}" ]; then
    echo "Error: stemcell path is required"
    echo "Usage: $0 STEMCELL_PATH [options]"
    echo "Run '$0 --help' for more information"
    exit 1
fi

# checks if the stemcell_tgz path is relative or absolute, and converts it to an absolute path if needed:
if [ "${stemcell_tgz:0:1}" != "/" ]; then
    stemcell_tgz="${PWD}/${stemcell_tgz}"
fi

if [ ! -f "${stemcell_tgz}" ]; then
    echo "Error: stemcell file not found: ${stemcell_tgz}"
    exit 1
fi

if [ -n "${debug_pub_key_file}" ]; then
    if [ ! -f "${debug_pub_key_file}" ]; then
        echo "Error: public key file not found: ${debug_pub_key_file}"
        exit 1
    fi
    BOSH_DEBUG_PUB_KEY=$(convert_multiline_to_single "${debug_pub_key_file}")
    export BOSH_DEBUG_PUB_KEY
fi

check_dependencies

stemcell_size=$(stat -c%s "${stemcell_tgz}" 2>/dev/null || stat -f%z "${stemcell_tgz}" 2>/dev/null)
required_space=$((stemcell_size * 4))
temp_dir=$(create_temp_dir "${required_space}")

stemcell_dir="${temp_dir}/stemcell"
image_dir="${temp_dir}/image"
mkdir -p "${stemcell_dir}" "${image_dir}"

echo "Extracting stemcell..."
tar xf "${stemcell_tgz}" -C "${stemcell_dir}"

if [ "${bump_version}" = true ]; then
    new_ver=$(date +%s)
fi

echo "Extracting image..."
set +e
if file "${stemcell_dir}/image" | grep -q 'gzip compressed'; then
    sudo tar xzf "${stemcell_dir}/image" -C "${image_dir}"
    tar_extract_exit=$?
else
    sudo tar xf "${stemcell_dir}/image" -C "${image_dir}"
    tar_extract_exit=$?
fi
set -e

if [ ${tar_extract_exit} -ne 0 ]; then
    echo "Warning: tar extraction reported errors (likely device nodes) but continuing"
fi

IFS='|' read -r stemcell_type disk_image original_disk_image <<< "$(detect_stemcell_type "${image_dir}")"

if [ "${stemcell_type}" = "warden" ]; then
    root_dir="${image_dir}"
else
    mnt_dir=$(mount_disk_image "${image_dir}" "${disk_image}")
    root_dir="${mnt_dir}"
fi

if [ "${bump_version}" = true ]; then
    echo "Updating version to 0.0.${new_ver}..."
    echo -n "0.0.${new_ver}" | sudo tee "${root_dir}/var/vcap/bosh/etc/stemcell_version" > /dev/null
fi

if [ -n "${AGENT_BINARY}" ]; then
    if [ ! -f "${AGENT_BINARY}" ]; then
        echo "Error: Agent binary file not found: ${AGENT_BINARY}"
        exit 1
    fi
    echo "Copying agent binary..."
    sudo cp "${AGENT_BINARY}" "${root_dir}/var/vcap/bosh/bin/bosh-agent"
fi

if [ -n "${AGENT_JSON}" ]; then
    if [ ! -f "${AGENT_JSON}" ]; then
        echo "Error: Agent JSON file not found: ${AGENT_JSON}"
        exit 1
    fi
    echo "Copying agent configuration..."
    sudo cp "${AGENT_JSON}" "${root_dir}/var/vcap/bosh/agent.json"
fi

if [ -n "${BOSH_DEBUG_PUB_KEY}" ]; then
    echo "Adding debug SSH key..."
    sudo chroot "${root_dir}" /bin/bash <<EOF
        useradd -m -s /bin/bash bosh_debug -G bosh_sudoers,bosh_sshers
        cd ~bosh_debug
        mkdir .ssh
        echo ${BOSH_DEBUG_PUB_KEY} >> .ssh/authorized_keys
        chmod go-rwx -R .
        chown -R bosh_debug:bosh_debug .
EOF
fi

echo "Repacking image..."
if [ "${stemcell_type}" = "warden" ]; then
    repack_warden_image "${stemcell_dir}" "${image_dir}"
else
    unmount_disk_image "${mnt_dir}" "${image_dir}" "${disk_image}"
    repack_disk_image "${stemcell_dir}" "${image_dir}" "${disk_image}" "${original_disk_image}"
fi

if [ "${bump_version}" = true ]; then
    sed -i.bak "s/version: .*/version: 0.0.${new_ver}/" "${stemcell_dir}/stemcell.MF"
    rm -f "${stemcell_dir}/stemcell.MF.bak"
fi

echo "Creating final stemcell tarball..."
tar czf "${stemcell_tgz}" -C "${stemcell_dir}" .

echo "ALL DONE!"
echo "Stemcell: ${stemcell_tgz}"
if [ "${bump_version}" = true ]; then
    echo "Version: 0.0.${new_ver}"
fi