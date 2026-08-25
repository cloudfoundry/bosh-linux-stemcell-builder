# Building on Apple Silicon

How to build stemcells on an arm64 Mac. This is about the **build host**: the
builder image and the rake tasks are x86-64 and run under Rosetta translation.

It is independent of the `-rosetta` stemcell *variant*, which is a property of
the stemcell you produce — see [Rosetta stemcell variant](rosetta-stemcell-variant.md).
You can build a plain `warden` stemcell here, and the variant only matters if you
intend to run the resulting stemcell under Rosetta too.

## Prerequisites

Colima with the `vz` VM type and Rosetta enabled (`~/.colima/default/colima.yaml`):

```yaml
arch: aarch64
vmType: vz
rosetta: true
mountType: virtiofs
cpu: 16       # the build is long; give it what you can spare
memory: 32
disk: 64
```

Those are the values this was verified with. The build itself is more modest:
about 6GB of scratch in `/mnt/stemcells`, a 3GB builder image, and roughly 1.2GB
of artifacts in `tmp/`. Leave headroom for the BuildKit cache, which grows
quickly across repeated attempts (`docker buildx du`, `docker buildx prune`).

Check Rosetta is actually wired up before going further:

```shell
docker run --rm --platform linux/amd64 ubuntu:resolute uname -m   # => x86_64
```

`docker buildx ls` will *not* list `linux/amd64` among the builder's platforms.
That is cosmetic: Colima's Rosetta binfmt handler is not advertised to BuildKit
but is used anyway, and `docker build --platform linux/amd64` works.

## Build the builder image

```shell
export short_name="resolute"

docker build \
   --platform linux/amd64 \
   --build-arg BASE_IMAGE="ubuntu:${short_name}" \
   --build-arg USER_ID="$(id -u)" \
   --build-arg GROUP_ID="$(id -g)" \
   --build-arg ARM64_TAR_FIX=true \
   --build-arg META4_CLI_URL="https://github.com/dpb587/metalink/releases/download/v0.5.0/meta4-0.5.0-linux-amd64" \
   --build-arg SYFT_CLI_URL="https://github.com/anchore/syft/releases/download/v1.42.3/syft_1.42.3_linux_amd64.tar.gz" \
   --build-arg YQ_CLI_URL="https://github.com/mikefarah/yq/releases/download/v4.52.5/yq_linux_amd64" \
   --build-arg RUBY_INSTALL_URL="https://github.com/postmodern/ruby-install/releases/download/v0.10.2/ruby-install-0.10.2.tar.gz" \
   --build-arg RUBY_VERSION="$(cat .ruby-version)" \
   --build-arg GEM_HOME="/usr/local/bundle" \
   --build-arg OVF_TOOL_INSTALLER="VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle" \
   --build-arg OVF_TOOL_INSTALLER_SHA1="6c24e473be49c961cfc3bb16774b52b48e822991" \
   -t bosh/os-image-stemcell-builder:${short_name}-rosetta \
   ci/docker/os-image-stemcell-builder/
```

`ARM64_TAR_FIX=true` is required here and must stay at its `false` default in
CI, where there is no arm64 emulation and the arm64 binary would not run. It
replaces the builder image's own `tar` — see
[the tar problem](#ubuntu-2604s-x86-64-tar-does-not-work-under-rosetta) below.

Expect five to ten minutes, most of it compiling Ruby under translation.

### ovftool

`ovftool` is only used by the `image_ovf_generate` stage, which appears solely in
`ovf_package_stages` — vSphere and vCloud. **Warden stemcells never invoke it.**

The `OVF_TOOL_INSTALLER` bundle is nonetheless required to build the *builder
image*, because the Dockerfile `ADD`s it unconditionally. Download it into
`ci/docker/os-image-stemcell-builder/` first. If you only ever build warden
stemcells, making that `ADD` conditional would remove the dependency.

## Build the OS image and the stemcell

Start a long-lived container and do both builds in it. Gems live in the
container's `/usr/local/bundle`, not in the bind mount, so a fresh `docker run`
always needs `bundle install` again; keeping one container avoids that and keeps
`/mnt/stemcells` around for re-running tests.

```shell
export short_name="resolute"

docker run -it --name ${short_name}-rosetta-build \
   --platform linux/amd64 \
   --privileged \
   -v "$(pwd):/opt/bosh" \
   --workdir /opt/bosh \
   --user="$(id -u):$(id -g)" \
   bosh/os-image-stemcell-builder:${short_name}-rosetta

# You're now in the Docker container
export short_name="resolute"
gem install bundler
bundle install

# build the OS image (the stemcell build below consumes it)
bundle exec rake stemcell:build_os_image[ubuntu,${short_name},/opt/bosh/tmp/ubuntu_base_image_${short_name}.tgz]

# build the warden rosetta stemcell
bundle exec rake stemcell:build[warden,warden,ubuntu,${short_name}-rosetta,/opt/bosh/tmp/ubuntu_base_image_${short_name}.tgz,9.000]
```

Each took roughly 10-15 minutes on a 16-CPU VM with a local apt cache; expect
longer without one. Both run their RSpec suites at the end, so a clean exit
means the tests passed too.

The OS image is architecture-neutral and carries no Rosetta-specific changes.
The `-rosetta` suffix on the *stemcell* build is what inserts the
`base_ubuntu_warden_rosetta` stage, so the same OS image tarball also serves a
plain `warden` build.

### Rebuilding at the same version

`create-env` records uploaded stemcells by name and version in its state file.
Rebuilding without bumping the version leaves that record stale, and the next
`create-env` reports `Skipped [Stemcell already uploaded]` and reuses the old
image. Either bump the version or drop the `stemcells` entry (and
`current_stemcell_id`) from `state.json`.

## Speeding up repeat builds

The build downloads well over a gigabyte of debs. If you run
[apt-cacher-ng](https://hub.docker.com/r/sameersbn/apt-cacher-ng) on the host,
add `-e http_proxy=http://host.docker.internal:3142` to `docker run` and both
debootstrap and the in-chroot `apt` calls will use it.

## Gotchas

### Never use a `ROSETTA_` prefix for an env var or Docker `ARG`

Rosetta reserves that namespace and refuses to start *any* process when it sees
one it does not recognise, so the container dies instantly with `rosetta error:
invalid ROSETTA_ environment variable ...` and exit code 133. Docker turns every
`ARG` into an env var for `RUN`, which is why the tar build arg is called
`ARM64_TAR_FIX`.

### Ubuntu 26.04's x86-64 `tar` does not work under Rosetta

Every extraction fails with `Cannot open: Function not implemented` (ENOSYS),
because `tar` issues a syscall Rosetta does not translate.

As of August 2026 this affects `tar` 1.35+dfsg-4ubuntu0.4 on Ubuntu 26.04.
Ubuntu 24.04's `tar` is unaffected, so it is new in 26.04, and `tar` is the only
affected tool in the base image — `gzip`, `xz`, `zstd`, `cpio`, `rsync` and
coreutils all work. `apt` also works, because `dpkg` unpacks debs with its own
built-in tar reader; only direct `tar` calls break, including `dpkg -x`. Recheck
whether the workaround is still needed when moving to a newer `tar`.

A bare `exit code 2` from a step that unpacks an archive is almost always this.
Re-run the command by hand to see the `Function not implemented` lines.
