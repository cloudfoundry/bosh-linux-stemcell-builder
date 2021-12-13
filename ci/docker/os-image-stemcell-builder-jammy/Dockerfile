# bosh/os-image-stemcell-builder
FROM ubuntu:jammy

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





RUN groupadd -o -g ${GROUP_ID} ubuntu                  \
  && useradd -u ${USER_ID} -g ${GROUP_ID} -m ubuntu \
  && echo 'ubuntu ALL=NOPASSWD:ALL' >> /etc/sudoers

# Nokogiri dependencies
RUN apt-get install -y libxslt-dev libxml2-dev && apt-get clean

ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
# -----------------------------------------------------------------------------------------
# ROLL BACK OPENSSL3 FOR NOW. RUBY 3 DOESN'T COMPILE WITH IT. SEE ISSUE FOR TRACKING SUPPORT 
# https://github.com/ruby/openssl/issues/369

RUN wget http://launchpadlibrarian.net/524873081/wget_1.21-1ubuntu3_amd64.deb && \
    wget https://answers.launchpad.net/ubuntu/+source/openssl/1.1.1l-1ubuntu1.1/+build/22454275/+files/openssl_1.1.1l-1ubuntu1.1_amd64.deb  && dpkg -i openssl_1.1.1l-1ubuntu1.1_amd64.deb && \
    wget http://mirrors.kernel.org/ubuntu/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu7_amd64.deb && \
    wget http://mirrors.kernel.org/ubuntu/pool/main/z/zlib/zlib1g-dev_1.2.11.dfsg-2ubuntu7_amd64.deb && \
    wget http://launchpadlibrarian.net/557734981/libssl-dev_1.1.1l-1ubuntu1_amd64.deb
RUN apt -y remove libssl-dev=3.0.0-1ubuntu1 libssl3 && \
    apt install rsync libssl1.1
RUN dpkg -i wget_1.21-1ubuntu3_amd64.deb && \
    dpkg -i libssl-dev_1.1.1l-1ubuntu1_amd64.deb && \
    dpkg -i zlib1g_1.2.11.dfsg-2ubuntu7_amd64.deb && \
    dpkg -i zlib1g-dev_1.2.11.dfsg-2ubuntu7_amd64.deb
# -----------------------------------------------------------------------------------------
RUN cd /tmp && ./install-ruby.sh  && rm install-ruby.sh

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

ADD scripts/update.sh /tmp/update.sh
RUN /tmp/update.sh && rm /tmp/update.sh

ENV OVF_TOOL_INSTALLER VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle
ENV OVF_TOOL_INSTALLER_SHA1 6c24e473be49c961cfc3bb16774b52b48e822991
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
