#!/bin/bash                                                                                   
source config.cfg                                                                     
source functions.sh


echocolor "Install Glance"
sleep 3
apt install glance ceph-common python3-rbd -y

echocolor "Config Glance"
sleep 3

cat << EOF > /etc/glance/glance-api.conf
[DEFAULT]
show_image_direct_url = True
enable_v2_api = true
enable_v2_registry = true
enable_v1_api = true
enable_v1_registry = true
[cors]
[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@$CTL_MGNT_IP/glance
backend = sqlalchemy
[glance_store]
stores = file, http, swift, cinder, rbd
default_store = rbd
filesystem_store_datadir = /var/lib/glance/images/
rbd_store_pool = images
rbd_store_user = glance
rbd_store_ceph_conf = /etc/ceph/ceph.conf
[image_format]
disk_formats = ami,ari,aki,vhd,vhdx,vmdk,raw,qcow2,vdi,iso,ploop.root-tar
[keystone_authtoken]
www_authenticate_uri = http://$CTL_MGNT_IP:5000
auth_url = http://$CTL_MGNT_IP:5000
memcached_servers = $CTL_MGNT_IP:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = $GLANCE_PASS
[matchmaker_redis]
[oslo_concurrency]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
flavor = keystone
[profiler]
[store_type_location_strategy]
[task]
[taskflow_executor]
EOF

echocolor "Create ceph config"
sleep 3

cat << EOF > /etc/ceph/ceph.conf
[global]
fsid = 6710902a-0466-49ba-87b4-d4653783305c
mon_initial_members = ceph-1
mon_host = 172.16.78.6
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx


public network = 172.16.78.6/24
cluster_network = 10.5.9.110/22

EOF