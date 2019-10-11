#!/bin/bash                                                                                   
source config.cfg                                                                     
source functions.sh

sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

cat << EOM > /etc/yum.repos.d/ceph.repo
[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-$CEPH_VERISON/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1
EOM

sudo yum update
echocolor "Install ceph deploy"
sleep 3
sudo yum install ceph-deploy -y
echo "$CEPH_IP      ceph" >> /etc/hosts    
ceph-deploy new ceph

echocolor "Update config ceph"
sleep 3
echo "public_network=$CEPH_IP" >> ceph.conf

echocolor "Install ceph"
sleep 3
ceph-deploy install ceph
ceph-deploy mon create-initial
ceph-deploy osd create --data /dev/vdb ceph
ceph-deploy mgr create ceph

echocolor "Cretate volumes and images pool"
sleep 3

ceph osd pool create volumes 64
ceph osd pool set volumes size 1 --yes-i-really-mean-it
ceph osd pool create images 64
ceph osd pool set images size 1 --yes-i-really-mean-it
ceph osd pool set volumes min_size 1 --yes-i-really-mean-it
ceph osd pool set images min_size 1 --yes-i-really-mean-it
rbd pool init volumes
rbd pool init images

ceph auth get-or-create client.glance mon 'profile rbd' osd 'profile rbd pool=images'
ceph auth get-or-create client.glance | ssh root@$CTL_EXT_IP sudo tee /etc/ceph/ceph.client.glance.keyring
ceph auth get-or-create client.cinder mon 'profile rbd' osd 'profile rbd pool=volumes, profile rbd-read-only pool=images'
ceph auth get-or-create client.cinder-backup | ssh root@$CTL_EXT_IP sudo tee /etc/ceph/ceph.client.cinder-backup.keyring
