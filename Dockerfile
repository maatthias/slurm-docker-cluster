FROM fedora:41

RUN set -ex \
    && dnf makecache \
    && dnf -y update

RUN dnf -y install dnf-plugins-core \
    # && dnf config-manager --enable crb \
    && dnf -y install \
        autoconf \
        automake \
        bash-completion \
        bzip2 \
        dbus \
        dbus-daemon \
        dbus-devel \
        # ebpf \
        gcc \
        gcc-c++\
        git \
        gnupg \
        http-parser-devel \
        json-c-devel \
        jwt \
        kernel-headers \
        libbpf \
        # libdbus \
        libgcrypt \
        libtool \
        libyaml \
        make \
        mariadb-devel \
        mariadb-server \
        # munge contains munged daemon, mungekey executable, and client executables (munge, unmunge, and remunge)
        munge \
        munge-libs \
        openssl \
        pam-devel \
        perl \
        pkgconf \
        psmisc \
        python3-devel \
        python3-pip \
        python3 \
        readline-devel \
        systemd \
        vim-enhanced \
        wget \
        zlib \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN set -ex \
    && mkdir -p /etc/slurm \
    && mkdir -p /home/slurm

WORKDIR /tmp    
RUN wget https://github.com/dun/munge/releases/download/munge-0.5.13/munge-0.5.13.tar.xz
RUN tar xJf munge-0.5.13.tar.xz
WORKDIR /tmp/munge-0.5.13
RUN ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --runstatedir=/run
RUN make
RUN make check
RUN make install

ARG SLURM_VERSION=24.11.1

WORKDIR /home/slurm
RUN set -ex \
    && wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 \
    && bzip2 --decompress slurm-${SLURM_VERSION}.tar.bz2

RUN set -ex \
    && tar xf slurm-${SLURM_VERSION}.tar

WORKDIR /home/slurm/slurm-${SLURM_VERSION}

RUN ./configure \
    --sysconfdir=/etc/slurm/ \
    --with-bpf
RUN make
RUN make install

RUN groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm

COPY slurm.conf /etc/slurm/slurm.conf
COPY cgroup.conf /etc/slurm/cgroup.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 0600 /etc/slurm/slurmdbd.conf

COPY slurmd.service /etc/systemd/system/slurmd.service
COPY munge.service /usr/lib/systemd/system/munge.service

RUN sudo -u munge mungekey --verbose

RUN mkdir -p /var/run/munge \
    && chown -R munge:munge /var/run/munge/ \
    && chmod -R 0777 /var/run/munge/

# slurmdbd   | munged: Error: Pidfile is insecure: group-writable permissions without sticky bit set on "/run/munge"
# slurmdbd   | munged: Error: Socket is inaccessible: execute permissions for all required on "/run/munge"
RUN chmod 1777 /run/munge

RUN mkdir -p /var/log/munge \
    && chown -R munge:munge /var/log/munge/ \
    && chmod -R 0740 /var/log/munge/

RUN mkdir -p /var/run/slurmdbd \
    && touch /var/run/slurmdbd/slurmdbd.pid \
    && chown slurm:slurm /var/run/slurmdbd/slurmdbd.pid

RUN mkdir -p /var/log/slurm \
    # && touch /var/log/slurm/slurmdbd.log \
    && chown -R slurm:slurm /var/log/slurm

RUN mkdir -p /var/run/slurmd \
    && touch /var/run/slurmd/slurmctld.pid \
    && chmod 0744 /var/run/slurmd/slurmctld.pid

RUN mkdir -p /var/lib/slurmd \
    && chown -R slurm:slurm /var/lib/slurmd

RUN mkdir -p /var/spool/slurmd \
    && chown -R slurm:slurm /var/spool/slurmd

# rootless cgroup muckery
# RUN whoami && id && id -g
# USER root
# RUN sudo umount /sys/fs/cgroup
# RUN mount -t cgroup2 -o rw,seclabel,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot 0 0 /sys/fs/cgroup


# RUN mkdir -p /sys/fs/cgroup/ \
#     && chown -R slurm:slurm /sys/fs/cgroup/ \
#     && chmod -R 0777 /sys/fs/cgroup/

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]
