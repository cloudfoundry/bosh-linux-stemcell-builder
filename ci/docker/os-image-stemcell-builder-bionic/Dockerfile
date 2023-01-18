# bosh/os-image-stemcell-builder
FROM ubuntu:bionic

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apt-get update \
  && apt-get -y upgrade \
  && apt-get clean \
  && apt-get install -y \
    build-essential \
    curl \
    dnsutils \
    git \
    jq \
    libreadline-dev \
    libssl-dev \
    rsync \
    tar \
    wget \
    xvfb \
    locales \
    sudo \
    lsof \
  && apt-get clean

# Nokogiri dependencies
RUN apt-get install -y libxslt-dev libxml2-dev && apt-get clean

RUN groupadd -o -g ${GROUP_ID} ubuntu                  \
  && useradd -u ${USER_ID} -g ${GROUP_ID} -m ubuntu \
  && echo 'ubuntu ALL=NOPASSWD:ALL' >> /etc/sudoers

# install ruby
ENV RUBY_SHA256="570e7773100f625599575f363831166d91d49a1ab97d3ab6495af44774155c40"
ENV RUBY_VERSION="3.0.2"

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
  && echo 'source /usr/local/share/chruby/chruby.sh; chruby 3.0.2' > ~ubuntu/.bashrc

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

ADD scripts/update.sh /tmp/update.sh
RUN /tmp/update.sh && rm /tmp/update.sh

ENV OVF_TOOL_INSTALLER VMware-ovftool-4.1.0-2459827-lin.x86_64.bundle
ENV OVF_TOOL_INSTALLER_SHA1 b907275c8d744bb54717d24bb8d414b19684fed4
ADD ${OVF_TOOL_INSTALLER} /tmp/ovftool_installer.bundle
ADD scripts/install-ovf.sh /tmp/install-ovf.sh
RUN /tmp/install-ovf.sh && rm /tmp/install-ovf.sh

RUN wget -O /usr/bin/meta4 https://github.com/dpb587/metalink/releases/download/v0.2.0/meta4-0.2.0-linux-amd64 \
  && echo "81a592eaf647358563f296aced845ac60d9061a45b30b852d1c3f3674720fe19  /usr/bin/meta4" | shasum -a 256 -c \
  && chmod +x /usr/bin/meta4

# this is unshare from ubuntu 15.10 so we can use the newer -fp flags
ADD scripts/unshare /usr/bin/unshare

RUN for GO_EXECUTABLE in $GOROOT/bin/*; do ln -s $GO_EXECUTABLE /usr/bin/; done

# Source: https://stackoverflow.com/questions/28247427/strange-locale-issue-on-arch
RUN locale-gen && sed -i '1 i\en_US.UTF-8 UTF-8' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
