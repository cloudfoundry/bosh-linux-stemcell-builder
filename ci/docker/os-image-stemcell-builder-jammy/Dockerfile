# bosh/os-image-stemcell-builder

FROM ubuntu:jammy

LABEL maintainer="cf-bosh@lists.cloudfoundry.org"

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG DEBIAN_FRONTEND=noninteractive # prevents s3cmd dpkg install asking TZ info

RUN \
  apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y \
    apt-utils \
    bison \
    build-essential \
    curl \
    debootstrap \
    dnsutils \
    git \
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
    rsync \
    s3cmd \
    sudo \
    tar \
    wget \
    xvfb \
  && apt-get clean

RUN groupadd -o -g ${GROUP_ID} ubuntu                  \
  && useradd -u ${USER_ID} -g ${GROUP_ID} -m ubuntu \
  && echo 'ubuntu ALL=NOPASSWD:ALL' >> /etc/sudoers

# we install a local ruby (3.x) because Jammy is lagging at 2.7
ENV RUBY_SHA256="d2f4577306e6dd932259693233141e5c3ec13622c95b75996541b8d5b68b28b4"
ENV RUBY_VERSION="3.2.0"

RUN \
  wget -O ruby-install-0.8.3.tar.gz https://github.com/postmodern/ruby-install/archive/v0.8.3.tar.gz \
  && tar -xzvf ruby-install-0.8.3.tar.gz \
  && cd ruby-install-0.8.3/ \
  && make install \
  && cd .. \
  && rm -r ruby-install* \
  && ruby-install $RUBY_VERSION --cleanup --sha256 $RUBY_SHA256 -- --disable-install-rdoc

# we install chruby to allow us to run `bundle` as a non-root user
RUN \
  wget -O chruby-0.3.9.tar.gz https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz \
  && tar -xzvf chruby-0.3.9.tar.gz \
  && cd chruby-0.3.9/ \
  && make install \
  && cd .. \
  && rm -r chruby-0.3.9* \
  && echo 'source /usr/local/share/chruby/chruby.sh; chruby $RUBY_VERSION ' > ~ubuntu/.bashrc

RUN \
  mkdir -p /mnt/tmp \
  && chown -R ubuntu:ubuntu /mnt/tmp \
  && echo 'export TMPDIR=/mnt/tmp' >> ~ubuntu/.bashrc

# rake tasks will be using this as chroot
RUN \
  mkdir -p /mnt/stemcells \
  && chown -R ubuntu:ubuntu /mnt/stemcells

# VMware's ovftool is used to create vSphere stemcells
ENV OVF_TOOL_INSTALLER VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle
ENV OVF_TOOL_INSTALLER_SHA1 6c24e473be49c961cfc3bb16774b52b48e822991
ADD ${OVF_TOOL_INSTALLER} /tmp/ovftool_installer.bundle
RUN \
  cd /tmp \
  && echo "${OVF_TOOL_INSTALLER_SHA1} /tmp/ovftool_installer.bundle" | sha1sum -c - \
  && chmod a+x ./ovftool_installer.bundle \
  && ln -s /bin/cat /usr/local/bin/more \
  && bash  ./ovftool_installer.bundle --eulas-agreed \
  && rm -rf ./ovftool_installer.bundle /tmp/vmware-root/ /usr/local/bin/more

RUN \
  wget -O /usr/bin/meta4 https://github.com/dpb587/metalink/releases/download/v0.2.0/meta4-0.2.0-linux-amd64 \
  && echo "81a592eaf647358563f296aced845ac60d9061a45b30b852d1c3f3674720fe19  /usr/bin/meta4" | shasum -a 256 -c \
  && chmod +x /usr/bin/meta4

# fixes "invalid byte sequence in US-ASCII" in `spec/support/os_image_chrony_shared_examples.rb`
RUN \
  sudo locale-gen en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
