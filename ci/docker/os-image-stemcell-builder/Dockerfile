# bosh/os-image-stemcell-builder
ARG BASE_IMAGE
FROM $BASE_IMAGE

LABEL maintainer="cf-bosh@lists.cloudfoundry.org"

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

ENV USER_ID=1000
ENV GROUP_ID=1000

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

RUN groupadd -o -g ${GROUP_ID} ubuntu \
  && useradd -u ${USER_ID} -g ${GROUP_ID} -m ubuntu \
  && echo 'ubuntu ALL=NOPASSWD:ALL' >> /etc/sudoers

RUN temp_dir="/mnt/tmp" \
    && mkdir -p "${temp_dir}" \
    && chown -R ubuntu:ubuntu "${temp_dir}" \
    && echo "export TMPDIR=${temp_dir}" >> ~ubuntu/.bashrc

# rake tasks will be using this as chroot
RUN mkdir -p /mnt/stemcells \
    && chown -R ubuntu:ubuntu /mnt/stemcells

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
    && chown -R ubuntu:ubuntu "${GEM_HOME}"

RUN syft_cli_path="/usr/local/bin/syft" \
    && curl --show-error -sL "${SYFT_CLI_URL}" \
      | tar -xz -C /usr/local/bin/ syft \
    && chmod +x ${syft_cli_path}

RUN yq_cli_path="/usr/local/bin/yq" \
    && curl --show-error -sL "${YQ_CLI_URL}" \
      > "${yq_cli_path}" \
    && chmod +x "${yq_cli_path}"
