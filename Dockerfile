FROM rockylinux/rockylinux:9

LABEL org.opencontainers.image.source="https://github.com/giovtorres/slurm-docker-cluster" \
      org.opencontainers.image.title="slurm-docker-cluster" \
      org.opencontainers.image.description="Slurm Docker cluster on Rocky Linux 8" \
      org.label-schema.docker.cmd="docker-compose up -d" \
      maintainer="Giovanni Torres"

RUN set -ex \
    && dnf makecache \
    && dnf -y update \
    && dnf -y install dnf-plugins-core \
    && dnf config-manager --enable crb \
    && dnf -y install \
       wget \
       bzip2 \
       perl \
       gcc \
       gcc-c++\
       git \
       gnupg \
       dbus \
       dbus-daemon \
       dbus-devel \
       libbpf \
       make \
       munge \
       munge-devel \
       python3-devel \
       python3-pip \
       python3 \
       mariadb-server \
       mariadb-devel \
       psmisc \
       bash-completion \
       vim-enhanced \
       http-parser-devel \
       json-c-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# RUN alternatives --set python /usr/bin/python3

RUN pip3 install Cython pytest

ARG GOSU_VERSION=1.17

RUN set -ex \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

ARG SLURM_TAG=slurm-24-05-4-1

# git clone and compile slurm
RUN set -ex \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && pushd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && popd

RUN set -ex \
    && rm -rf slurm \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g munge --uid=991 slurm

RUN mkdir -p /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /mnt/slurm_state \
        /data

RUN set -x \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
        /var/run/slurmctld.pid \
        /var/run/slurmd.pid \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key

COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
COPY cgroup.conf /etc/slurm/cgroup.conf

RUN set -x \
    && chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf \
    && chown -R slurm:slurm /var/spool/slurm* \
    # apparently rocky 9.4 defaults /etc permissions to 0777
    # causing slurm service start to complain about group-writable 
    # perms on /etc/munge/munge.key
    && chmod 0755 /etc/

# RUN set -x \
#     && chown -R slurm:slurm /var/*/slurm* \
#     && chmod -R 0755 /var/log/slurm/ \
#     # && chown -R slurm:slurm /var/spool/slurm* \
#     && chown slurm:slurm /var/run/slurmctld.pid \
#     # && chown slurm:slurm /var/run/slurmd.pid \
#     && chown -R slurm:slurm /mnt/slurm_state \
#     && /sbin/create-munge-key \
#     # apparently rocky 9.4 defaults /etc permissions to 0777
#     # causing slurm service start to complain about perms on /etc/munge/munge.key
#     && chmod 0755 /etc/

# RUN set -x \
#     && chown slurm:slurm /etc/slurm/slurmdbd.conf \
#     && chmod 600 /etc/slurm/slurmdbd.conf

# dbus stuff
# RUN mkdir -p /var/run/dbus
# RUN dbus-daemon --system --fork
# RUN exec "$@"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]
