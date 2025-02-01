#!/bin/bash
set -e

if [ "$1" = "slurmdbd" ]
then
    echo "---> container starting with <slurmdbd> ..."

    # echo "---> init systemd in container ..."
    # exec /usr/sbin/init

    echo "---> Starting the MUNGE Authentication service (munged) ..."
    # sudo -u munge munged
    systemctl start munge

    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."

    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."
    # sudo -u slurm slurmdbd -Dvvv
    systemctl start slurmdbd
fi

if [ "$1" = "slurmctld" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    sudo -u munge munged

    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."

    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."

    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    sudo -u slurm slurmctld -i -Dvvv
fi

if [ "$1" = "slurmd" ]
then
    mkdir -p /run/dbus/
    # dbus-daemon --system

    echo "---> Starting the MUNGE Authentication service (munged) ..."
    sudo -u munge munged

    echo "---> Waiting for slurmctld to become active before starting slurmd..."

    until 2>/dev/null >/dev/tcp/slurmctld/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    # sudo -u slurm slurmd -d /usr/local/sbin/slurmstepd -Dvvv
    sudo -u slurm slurmd -Dvvv
fi

exec "$@"
