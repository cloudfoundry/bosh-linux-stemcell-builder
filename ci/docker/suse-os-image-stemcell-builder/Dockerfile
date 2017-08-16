FROM opensuse:42.2

ENV GOROOT /usr/local/go
ENV PATH $GOROOT/bin:$PATH
RUN echo 'export PATH=$GOROOT/bin:$PATH' >> /etc/profile.d/go.sh

RUN zypper -n ar http://download.opensuse.org/repositories/Virtualization:/Appliances:/Builder/openSUSE_Leap_42.2/ kiwi
RUN zypper --gpg-auto-import-keys ref
RUN zypper -n in -t pattern devel_C_C++
RUN zypper -n in ruby-devel libmysqld-devel sqlite3-devel postgresql-devel libxslt-devel libxml2-devel libxml2 python3-kiwi wget sudo gcc-c++ curl git
RUN zypper -n in --force-resolution libopenssl-devel # RVM requirement

# Temporarily downgrade kpartx until http://bugzilla.suse.com/show_bug.cgi?id=1037533 was resolved
RUN zypper -n in --oldpackage kpartx=0.6.2+suse20161025.b80f406-1.1

ENV OVF_TOOL_INSTALLER VMware-ovftool-4.1.0-2459827-lin.x86_64.bundle
ENV OVF_TOOL_INSTALLER_SHA1 b907275c8d744bb54717d24bb8d414b19684fed4
ADD ${OVF_TOOL_INSTALLER} /tmp/ovftool_installer.bundle
ADD scripts/install-ovf.sh /tmp/install-ovf.sh
RUN /tmp/install-ovf.sh && rm /tmp/install-ovf.sh

RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN curl -sSL https://get.rvm.io | bash -s stable --ruby=2.3.1

RUN /bin/bash -c "source /usr/local/rvm/scripts/rvm && gem install bundler '--version=1.11.2' --no-format-executable"

ADD scripts/install-go.sh /tmp/install-go.sh
RUN /tmp/install-go.sh && rm /tmp/install-go.sh
RUN ln -s /usr/local/go/bin/go /usr/bin

RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.9/gosu-amd64" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.9/gosu-amd64.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash", "-l"]
