FROM fedora:41 AS slurm

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
        munge-devel \
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
        slurm-slurmctld \
        slurm-slurmd \
        slurm-slurmdbd \
        systemd \
        vim-enhanced \
        wget \
        zlib \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm

COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
COPY cgroup.conf /etc/slurm/cgroup.conf
RUN set -x \
    && chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf
    
ARG SLURM_TAG=slurm-24-11-1-1

RUN set -ex \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && pushd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
    && make install \
    # && install -D -m644 /etc/slurm/cgroup.conf \
    # && install -D -m644 /etc/slurm/slurm.conf \
    # && install -D -m644 /etc/slurm/slurmdbd.conf \
    # && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && popd \
    && rm -rf slurm

RUN mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm*

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

RUN sudo -u munge /usr/sbin/mungekey --verbose

RUN mkdir -p /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm*

RUN systemctl enable munge

FROM slurm AS slurmdbd

RUN systemctl enable slurmdbd

ENTRYPOINT ["/usr/sbin/init"]

FROM slurm AS slurmctld

RUN systemctl enable slurmctld

ENTRYPOINT ["/usr/sbin/init"]

FROM slurm AS slurmd

RUN systemctl enable slurmd

ENTRYPOINT ["/usr/sbin/init"]
