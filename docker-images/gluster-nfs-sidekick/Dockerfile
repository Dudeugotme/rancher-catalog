FROM centos:7
MAINTAINER jan@rancher.com

# Install required packages
RUN yum install -y epel-release.noarch centos-release-gluster37.noarch && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Storage && \
    yum -y install \
    # GlusterFS / Ganesha
    glusterfs glusterfs-server glusterfs-cli glusterfs-fuse glusterfs-ganesha \
    # NFS dependencies - libntirpc ?
    nfs-utils rpcbind dbus \
    # Utils used by scripts
    jq curl && \
    # Clean cache
    yum -y clean all && \
    mv /var/lib/glusterd/hooks/1/set/post/S30samba-set.sh /var/lib/glusterd/hooks/1/set/post/dS30samba-set.sh && \
    mv /var/lib/glusterd/hooks/1/start/post/S30samba-start.sh /var/lib/glusterd/hooks/1/start/post/dS30samba-start.sh && \
    mv /var/lib/glusterd/hooks/1/stop/pre/S30samba-stop.sh /var/lib/glusterd/hooks/1/stop/pre/dS30samba-stop.sh

# Add Giddyup
ENV GIDDYUP_VERSION v0.14.0
ADD https://github.com/cloudnautique/giddyup/releases/download/${GIDDYUP_VERSION}/giddyup /usr/local/bin/giddyup
RUN chmod +x /usr/local/bin/giddyup

# Add Tini
ENV TINI_VERSION v0.10.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /tini.asc
RUN set -x \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
    && gpg --verify /tini.asc \
    && rm -rf "$GNUPGHOME" /tini.asc \
    && chmod +x /tini

COPY rootfs /

VOLUME ["/data/glusterfs/brick1"]

# GlusterFS
EXPOSE 24007 24007/udp 24008 24008/udp 49152

# NFS
EXPOSE 111 111/udp 662 2049 38465-38467

ENTRYPOINT ["/tini", "--"]