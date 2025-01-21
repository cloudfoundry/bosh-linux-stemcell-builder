#!/bin/bash

set -e

show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --help, -h                Show this help message and exit"
    echo "  --debug                   Enable debug mode"
    echo "  --debug_pub_key FILE      Set a multiline public key file"
    echo "  --bump-version            Bump the version in the stemcell with 0.0.<timestamp>"
    echo
    echo "Environment Variables:"
    echo "  stemcell_tgz              Path to the stemcell tarball *REQUIRED*"
    echo "  AGENT_BINARY              Path to the agent binary to be copied into the stemcell *OPTIONAL*"
    echo "  AGENT_JSON                Path to the agent JSON configuration file *OPTIONAL*"
    echo "  BOSH_DEBUG_PUB_KEY        Public key for the BOSH debug user in a single line *OPTIONAL*"
    echo "  OUT                       Path to the patched stemcell tarball *OPTIONAL*"
    echo "  TMPDIR                    Path with enough disk space to hold all temporary files for repacking *OPTIONAL*"
    echo
    echo "Example:"
    echo "  export stemcell_tgz=\"/home/username/workspace/bosh/bosh-linux-stemcell-builder/tmp/bosh-stemcell-0.0.8-google-kvm-ubuntu-noble-go_agent.tgz\""
    echo "  export AGENT_BINARY=\"/path/to/bosh-agent\""
    echo "  export AGENT_JSON=\"/path/to/agent.json\""
    echo "  export BOSH_DEBUG_PUB_KEY=\"ssh-rsa AAA... user@hostname\""
}

convert_multiline_to_single() {
    local input_file=$1
    local single_line_cert

    single_line_cert=$(tr -d '\n' < "$input_file")
    echo "$single_line_cert"
}

# Check for help, debug, or debug_pub_key argument
convert_cert_file=""
bump_version=false
for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            exit 0
            ;;
        --debug)
            set -x
            ;;
        --debug_pub_key)
            convert_cert_file="$2"
            shift 2
            ;;
        --bump-version)
            bump_version=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -n "$convert_cert_file" ]; then
    BOSH_DEBUG_PUB_KEY=$(convert_multiline_to_single "$convert_cert_file")
    export BOSH_DEBUG_PUB_KEY
fi


if [ -z ${stemcell_tgz} ]; then
echo "stemcell_tgz is not set. export stemcell_tgz="/home/username/workspace/bosh/bosh-linux-stemcell-builder/tmp/bosh-stemcell-0.0.8-google-kvm-ubuntu-noble-go_agent.tgz""
fi

# stemcell_tgz=/tmp/stemcell.tgz
temp_dir=$(mktemp -d)
stemcell_dir=${temp_dir}/stemcell
image_dir=${temp_dir}/image
mkdir -p $stemcell_dir $image_dir
traps='rm -rf "${temp_dir}";'
trap "$traps" EXIT

# Repack stemcell
cd $stemcell_dir
tar xvf $stemcell_tgz
new_ver=`date +%s`

# Update stemcell with new agent
cd $image_dir
tar xvf $stemcell_dir/image
mnt_dir=$(mktemp -d)
traps+='rm -rf "${mnt_dir}";'
trap "${traps}" EXIT
device=$(sudo kpartx -sav disk.raw | grep '^add' | tail -n1 | cut -d' ' -f3)
sudo mount -o loop,rw /dev/mapper/$device $mnt_dir

if [ "$bump_version" = true ]; then
    echo -n "0.0.${new_ver}" | sudo tee "$mnt_dir/var/vcap/bosh/etc/stemcell_version"
fi

if [ -n "$AGENT_BINARY" ]; then
    sudo cp $AGENT_BINARY $mnt_dir/var/vcap/bosh/bin/bosh-agent
fi

if [ -n "$AGENT_JSON" ]; then
    sudo cp $AGENT_JSON $mnt_dir/var/vcap/bosh/agent.json
fi

if [ -n "$BOSH_DEBUG_PUB_KEY" ]; then
    sudo chroot $mnt_dir /bin/bash <<EOF
        useradd -m -s /bin/bash bosh_debug -G bosh_sudoers,bosh_sshers
        cd ~bosh_debug
        mkdir .ssh
        echo $BOSH_DEBUG_PUB_KEY >> .ssh/authorized_keys
        chmod go-rwx -R .
        chown -R bosh_debug:bosh_debug .
EOF
fi

sudo umount $mnt_dir
sudo kpartx -dv disk.raw

tar czvf $stemcell_dir/image *

cd $stemcell_dir
if [ "$bump_version" = true ]; then
    sed -i.bak "s/version: .*/version: 0.0.${new_ver}/" stemcell.MF
fi
tar czvf ${OUT:-$stemcell_tgz} *

echo "ALL DONE!!!"
