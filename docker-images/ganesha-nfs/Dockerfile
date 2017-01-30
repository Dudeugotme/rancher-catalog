FROM centos:7
MAINTAINER jan@rancher.com

# Install required packages
RUN yum install -y epel-release.noarch centos-release-gluster37.noarch && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Storage && \
    yum -y install \
    # Ganesha
    nfs-ganesha nfs-ganesha-xfs nfs-ganesha-vfs \
    # NFS dependencies - libntirpc ?
    nfs-utils rpcbind dbus \
    # Utils used by scripts
    jq curl && \
    # Clean cache
    yum -y clean all

COPY rootfs /

VOLUME ["/data/nfs"]

# NFS
EXPOSE 111 111/udp 662 2049 38465-38467

# ENTRYPOINT ["/tini", "--"]