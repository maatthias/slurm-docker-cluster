FROM fedora:41

RUN set -ex \
    && dnf makecache \
    && dnf -y update

RUN dnf -y install dnf-plugins-core \
    # && dnf config-manager --enable crb \
    && dnf -y install \
       wget \
       bzip2 \
       perl \
       gcc \
       gcc-c++\
       autoconf \
       automake \
       git \
       gnupg \
       dbus \
       dbus-daemon \
       dbus-devel \
       libbpf \
       libgcrypt \
       libtool \
       make \
       munge \
       munge-devel \
       pam-devel \
       python3-devel \
       python3-pip \
       python3 \
       readline-devel \
       mariadb-server \
       mariadb-devel \
       psmisc \
       bash-completion \
       vim-enhanced \
       http-parser-devel \
       json-c-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN set -ex \
    && mkdir -p /etc/slurm \
    && mkdir -p /home/slurm

COPY slurm.conf /etc/slurm/slurm.conf
COPY cgroup.conf /etc/slurm/cgroup.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf

WORKDIR /home/slurm

RUN set -ex \
    && wget https://download.schedmd.com/slurm/slurm-24.05.4.tar.bz2 \
    && bzip2 --decompress slurm-24.05.4.tar.bz2

RUN set -ex \
    && tar xf slurm-24.05.4.tar

WORKDIR /home/slurm/slurm-24.05.4

RUN ./configure --sysconfdir=/etc/slurm/
RUN make
RUN make install

COPY slurmd.service /etc/systemd/system/slurmd.service
COPY munge.service /usr/lib/systemd/system/munge.service

RUN systemctl enable --now munge
RUN systemctl enable --now slurmd.service

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]
