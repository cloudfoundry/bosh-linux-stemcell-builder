# bosh/os-image-stemcell-builder
ARG BASE_IMAGE
FROM $BASE_IMAGE

LABEL maintainer="cf-bosh@lists.cloudfoundry.org"

ARG USER_ID=1000
ARG GROUP_ID=1000

# BUILD_ARGs
ARG META4_CLI_URL
ARG SYFT_CLI_URL
ARG YQ_CLI_URL

ARG RUBY_INSTALL_URL
ARG RUBY_VERSION
ARG GEM_HOME

ARG OVF_TOOL_INSTALLER
ARG OVF_TOOL_INSTALLER_SHA1

# ENV VARs
ENV DEBIAN_FRONTEND="noninteractive"
ENV LANG="en_US.UTF-8"
ENV LC_ALL="${LANG}"
ENV TZ="Etc/UTC"

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y \
        apt-utils \
        bison \
        build-essential \
        curl \
        debootstrap \
        dnsutils \
        dosfstools \
        fdisk \
        git \
        git-lfs \
        golang \
        jq \
        kpartx \
        libffi-dev \
        libgdbm-dev \
        libmysqlclient-dev \
        libncurses5-dev \
        libpq-dev \
        libreadline-dev \
        libsigsegv2 \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        libxslt-dev \
        libyaml-0-2 \
        libyaml-dev \
        linux-headers-generic \
        locales \
        lsof \
        m4 \
        neovim \
        open-vm-tools \
        parted \
        qemu-utils \
        rsync \
        s3cmd \
        sudo \
        tar \
        wget \
        xvfb \
    && locale-gen ${LANG}

# Replace the x86-64 GNU tar with the arm64 build, for Apple Silicon hosts only.
#
# Ubuntu 26.04's tar (1.35+dfsg-4ubuntu0.4) cannot *extract* archives under
# Rosetta x86-64 translation: every file creation fails with
# "Cannot open: Function not implemented" (ENOSYS), because tar issues a
# syscall Rosetta does not translate. Noble's tar is unaffected, and the arm64
# build of the same version works because it runs natively on the arm64 kernel.
#
# This has to happen before anything else in this Dockerfile that unpacks an
# archive — the ovftool bundle is self-extracting and the ruby-install and syft
# downloads are piped straight into tar, so all of them fail without it. The
# build proper shells out to tar just as heavily (the untar_base_os_image stage,
# stemcell packaging, the RSpec helpers).
#
# dpkg unpacks debs with its own built-in tar reader rather than GNU tar, so apt
# keeps working either way; only direct tar invocations are affected. Extracting
# the arm64 deb itself needs a working tar, hence the temporary busybox.
#
# Leave this false when building on real x86-64 hardware (i.e. in CI): there is
# no arm64 emulation there and the arm64 binary would not run at all.
ARG ARM64_TAR_FIX=false
RUN if [ "${ARM64_TAR_FIX}" = "true" ]; then \
      set -eu \
      && dpkg --add-architecture arm64 \
      && apt-get update \
      && apt-get install -y --no-install-recommends \
           busybox-static \
           libacl1:arm64 \
           libc6:arm64 \
           libselinux1:arm64 \
      && mkdir -p /tmp/arm64-tar/root \
      && cd /tmp/arm64-tar \
      && apt-get download tar:arm64 \
      && dpkg-deb --fsys-tarfile tar_*_arm64.deb | busybox tar -x -C /tmp/arm64-tar/root \
      && mv /usr/bin/tar /usr/bin/tar.amd64 \
      && install -m 0755 /tmp/arm64-tar/root/usr/bin/tar /usr/bin/tar \
      && cd / \
      && rm -rf /tmp/arm64-tar \
      && apt-get purge -y busybox-static \
      && apt-get autoremove -y \
      && tar --version | head -1 ; \
    fi

# AppArmor's unix-chkpwd profile can block the Rosetta translator under
# docker run --privileged on Apple Silicon; use a distinct helper name so PAM still works.
RUN cp /usr/sbin/unix_chkpwd /usr/sbin/unix_chkpwd_rosetta \
  && chmod 4755 /usr/sbin/unix_chkpwd_rosetta \
  && ln -sf unix_chkpwd_rosetta /usr/sbin/unix_chkpwd

# Give the build user the *host* uid/gid so that the directories below stay
# writable when the container is started with `--user "$(id -u):$(id -g)"`.
# The base image already ships an `ubuntu` user at uid 1000, so on hosts whose
# uid differs (macOS is typically 501-504, gid 20) that user has to be
# renumbered — a plain `useradd` would be skipped and the container would then
# run as a uid with no passwd entry, no sudo, and no write access.
RUN getent group ${GROUP_ID} >/dev/null || groupadd -g ${GROUP_ID} bosh
RUN if getent passwd ${USER_ID} >/dev/null; then \
      build_user="$(getent passwd ${USER_ID} | cut -d: -f1)"; \
    elif id -u ubuntu >/dev/null 2>&1; then \
      usermod -u ${USER_ID} -g ${GROUP_ID} ubuntu; build_user=ubuntu; \
    else \
      useradd -u ${USER_ID} -g ${GROUP_ID} -m ubuntu; build_user=ubuntu; \
    fi \
  && usermod -p '*' "${build_user}" \
  && echo "${build_user} ALL=NOPASSWD:ALL" >> /etc/sudoers

RUN temp_dir="/mnt/tmp" \
    && mkdir -p "${temp_dir}" \
    && chown -R ${USER_ID}:${GROUP_ID} "${temp_dir}" \
    && echo "export TMPDIR=${temp_dir}" >> /etc/bash.bashrc

# rake tasks will be using this as chroot
RUN mkdir -p /mnt/stemcells \
    && chown -R ${USER_ID}:${GROUP_ID} /mnt/stemcells

# VMware's ovftool is used to create vSphere stemcells
ADD ${OVF_TOOL_INSTALLER} /tmp/ovftool_installer.bundle
RUN cd /tmp \
    && echo "${OVF_TOOL_INSTALLER_SHA1} /tmp/ovftool_installer.bundle" | sha1sum -c - \
    && chmod a+x ./ovftool_installer.bundle \
    && ln -s /bin/cat /usr/local/bin/more \
    && bash  ./ovftool_installer.bundle --eulas-agreed \
    && rm -rf ./ovftool_installer.bundle /tmp/vmware-root/ /usr/local/bin/more

RUN meta4_cli_path="/usr/local/bin/meta4" \
    && curl --show-error -sL "${META4_CLI_URL}" \
      > "${meta4_cli_path}" \
    && chmod +x "${meta4_cli_path}"

ENV GEM_HOME="${GEM_HOME}" \
    BUNDLE_APP_CONFIG="${GEM_HOME}" \
    BUNDLE_SILENCE_ROOT_WARNING=1
ENV PATH="${GEM_HOME}/bin:${PATH}"

RUN cd /tmp  \
    && curl --show-error -sL "${RUBY_INSTALL_URL}" \
      | tar -xzf - \
    && cd ruby-install-* \
    && make -s install \
    && cd - \
    && rm -rf ruby-install-* \
    && echo 'gem: --no-document' > /etc/gemrc \
    && NUM_CPUS=$(grep -c ^processor /proc/cpuinfo) \
    && ruby-install --jobs=${NUM_CPUS} --cleanup --system ruby ${RUBY_VERSION} \
      -- --disable-install-doc --disable-install-rdoc \
    && gem update --system \
    && mkdir -p "${GEM_HOME}/bin" \
    && chown -R ${USER_ID}:${GROUP_ID} "${GEM_HOME}"

RUN syft_cli_path="/usr/local/bin/syft" \
    && curl --show-error -sL "${SYFT_CLI_URL}" \
      | tar -xz -C /usr/local/bin/ syft \
    && chmod +x ${syft_cli_path}

RUN yq_cli_path="/usr/local/bin/yq" \
    && curl --show-error -sL "${YQ_CLI_URL}" \
      > "${yq_cli_path}" \
    && chmod +x "${yq_cli_path}"
