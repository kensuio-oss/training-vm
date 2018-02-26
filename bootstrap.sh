#! /usr/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt install -y locales
locale-gen en_US.UTF-8

export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8

apt-get install -y python software-properties-common python-software-properties

apt-add-repository ppa:ansible/ansible -y

apt-get update

apt-get -y dist-upgrade

apt-get install -y ansible


cd /srv/tmp/ansible_install
ansible-galaxy install -r requirements.yaml
ansible-playbook -i inventory playbook.yaml

rm -Rf /srv/tmp/ansible_install
touch /srv/installed_with_ansible
export HISTSIZE=0
sync

echo 'set GMT with timedatectl'
/usr/bin/timedatectl set-timezone UTC
