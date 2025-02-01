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
        gcc \
        gcc-c++\
        git \
        gnupg \
        http-parser-devel \
        json-c-devel \
        jwt \
        kernel-headers \
        libbpf \
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

ARG MUNGE_VERSION=0.5.13

WORKDIR /tmp    
RUN wget https://github.com/dun/munge/releases/download/munge-${MUNGE_VERSION}/munge-${MUNGE_VERSION}.tar.xz
RUN tar xJf munge-${MUNGE_VERSION}.tar.xz
WORKDIR /tmp/munge-${MUNGE_VERSION}
RUN ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --runstatedir=/run
RUN make
RUN make check
RUN make install

ARG SLURM_VERSION=24.11.1

RUN mkdir -p /home/slurm

WORKDIR /home/slurm
RUN set -ex \
    && wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 \
    && bzip2 --decompress slurm-${SLURM_VERSION}.tar.bz2 \
    && tar xf slurm-${SLURM_VERSION}.tar

WORKDIR /home/slurm/slurm-${SLURM_VERSION}

RUN ./configure \
    --sysconfdir=/etc/slurm/
RUN make
RUN make install

RUN groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm

COPY slurm.conf /etc/slurm/slurm.conf
COPY cgroup.conf /etc/slurm/cgroup.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 0600 /etc/slurm/slurmdbd.conf

RUN sudo -u munge /usr/sbin/mungekey --verbose
RUN systemctl enable munge

ENTRYPOINT ["/usr/sbin/init"]
