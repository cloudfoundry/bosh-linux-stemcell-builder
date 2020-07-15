FROM ubuntu:16.04

RUN apt-get clean && apt-get update && apt-get install -y locales

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN localedef -i en_US -f UTF-8 en_US.UTF-8 \
 && locale-gen en_US.UTF-8 \
 && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

RUN apt-get update
RUN apt-get -y upgrade && apt-get clean
RUN apt-get install -y \
	build-essential \
	git \
	curl \
	wget \
	tar \
	libssl-dev \
	libreadline-dev \
	dnsutils \
	xvfb \
	jq \
	realpath \
	libpq-dev \
	&& apt-get clean

# Nokogiri dependencies
RUN apt-get install -y libxslt-dev libxml2-dev && apt-get clean

ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd /tmp && ./install-ruby.sh && rm install-ruby.sh

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH
ENV PATH /opt/rubies/ruby-2.6.3/bin:/opt/rubies/ruby-2.4.5/bin:$PATH

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -o -g ${GROUP_ID} ubuntu                  \
  && useradd -u ${USER_ID} -g ${GROUP_ID} -m ubuntu \
  && echo 'ubuntu ALL=NOPASSWD:ALL' >> /etc/sudoers \
  && echo 'root ALL=(ALL:ALL) ALL' >> /etc/sudoers

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

ADD scripts/ubuntu_bashrc /home/ubuntu/.bashrc

RUN for GO_EXECUTABLE in $GOROOT/bin/*; do ln -s $GO_EXECUTABLE /usr/bin/; done
