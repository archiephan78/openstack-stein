## INSTALL NOVA-COMPUTE

- install nova-compute:

```
apt install nova-compute ceph-common python3-rbd neutron-openvswitch-agent -y
```
- Config brigde :

```
ovs-vsctl add-br br-provider
ovs-vsctl add-port br-provider eth0
```

- Config netplan:

```
root@compute-stein:~# cat /etc/netplan/01-netcfg.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
    br-provider:
      dhcp4: no
      addresses: [10.5.9.48/22]
      gateway4: 10.5.8.1
      nameservers:
              addresses: [8.8.8.8,8.8.4.4]
  ethernets:
    eth1:
      dhcp4: yes
```

- Config /etc/nova/nova.conf

```
cat << EOF > /etc/nova/nova.conf
[DEFAULT]
allow_resize_to_same_host = True
log_dir = /var/log/nova
lock_path = /var/lock/nova
state_path = /var/lib/nova
transport_url = rabbit://openstack:stein-demo@172.16.78.20
my_ip = 172.16.78.5
notify_on_state_change = vm_and_task_state
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
force_raw_images = true
default_availability_zone = nova
[api]
auth_strategy = keystone
[api_database]
connection = mysql+pymysql://nova:stein-demo@172.16.78.20/nova_api
[barbican]
[cache]
[cells]
enable = False
[cinder]
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[database]
connection = mysql+pymysql://nova:stein-demo@172.16.78.20/nova_cell0
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://172.16.78.20:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
auth_url = http://172.16.78.20:5000/v3
memcached_servers = 172.16.78.20:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = stein-demo
[libvirt]
images_type = raw
#images_rbd_pool = vms
#images_rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_secret_uuid = 6710902a-0466-49ba-87b4-d4653783305c
rbd_user = cinder
[matchmaker_redis]
[metrics]
[mks]
[neutron]
url = http://172.16.78.20:9696
auth_url = http://172.16.78.20:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = stein-demo
[notifications]
versioned_notifications_topics = versioned_notifications
[osapi_v21]
[oslo_concurrency]
lock_path = /var/lib/nova/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
driver = messagingv2
topics = notifications
[oslo_messaging_rabbit]
[oslo_messaging_zmq]
[oslo_middleware]
[oslo_policy]
[pci]
[placement]
os_region_name = openstack
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://172.16.78.20:5000/v3
username = placement
password = stein-demo
[placement_database]
[powervm]
[profiler]
[quota]
[rdp]
[remote_debug]
[scheduler]
[serial_console]
[service_user]
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = true
server_listen = 172.16.78.5
server_proxyclient_address = 172.16.78.5
novncproxy_base_url = http://10.5.8.116:6080/vnc_auto.html
[workarounds]
[wsgi]
[xenserver]
[xvp]
[zvm]
EOF
```

- Create config ceph and cinder key:

```
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

cat << EOF > /etc/ceph/ceph.client.cinder.keyring
[client.cinder]
        key = AQDUpJpd9gGlJxAAjo2BfELofwssdluzrZ+ElA==
EOF
```

- Kiểm tra hoạt động của nova-compute:

```
root@controller-stein:~# openstack compute service list
+----+------------------+------------------+----------+---------+-------+----------------------------+
| ID | Binary           | Host             | Zone     | Status  | State | Updated At                 |
+----+------------------+------------------+----------+---------+-------+----------------------------+
|  1 | nova-scheduler   | controller-stein | internal | enabled | up    | 2019-10-07T09:58:32.000000 |
|  2 | nova-consoleauth | controller-stein | internal | enabled | up    | 2019-10-07T09:58:39.000000 |
|  7 | nova-conductor   | controller-stein | internal | enabled | up    | 2019-10-07T09:58:40.000000 |
|  8 | nova-compute     | compute-stein    | nova     | enabled | up    | 2019-10-07T09:58:32.000000 |
+----+------------------+------------------+----------+---------+-------+----------------------------+
```

- Config /etc/neutron/neutron.conf:

```
cat << EOF > /etc/neutron/neutron.conf
[DEFAULT]
service_plugins =
dhcp_agents_per_network = 2
allow_overlapping_ips = True
core_plugin = ml2
transport_url = rabbit://openstack:stein-demo@172.16.78.20
auth_strategy = keystone
state_path = /var/lib/neutron
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true
state_path = /var/lib/neutron
lock_path = $state_path/lock
[agent]
root_helper = "sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf"
[cors]
[database]
connection = mysql+pymysql://neutron:stein-demo@172.16.78.20/neutron
[keystone_authtoken]
www_authenticate_uri = http://172.16.78.20:5000
auth_url = http://172.16.78.20:5000
memcached_servers = 172.16.78.20:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = stein-demo
EOF
```

- Config neutron_openvswitch_agent:

```
cat << EOF > /etc/neutron/plugins/ml2/openvswitch_agent.ini
[DEFAULT]
[agent]
tunnel_types = gre
l2_population = True
[network_log]
[ovs]
bridge_mappings = provider:br-provider
local_ip = 10.5.9.48
[securitygroup]
firewall_driver = iptables_hybrid
[xenapi]
EOF
```

- Restart service:

```
service neutron-l3-agent restart
```

- Kiểm tra ovs agent:

```
root@controller-stein:~# openstack network agent list
+--------------------------------------+--------------------+---------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host          | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+---------------+-------------------+-------+-------+---------------------------+
| 099ce64c-7282-44eb-a4ea-21e3d9666e75 | DHCP agent         | network-stein | nova              | :-)   | UP    | neutron-dhcp-agent        |
| 98383f4a-2c49-4680-8824-e33bd50e1376 | Open vSwitch agent | network-stein | None              | :-)   | UP    | neutron-openvswitch-agent |
| beaa1d58-8316-413e-84aa-021631b3204c | Open vSwitch agent | compute-stein | None              | :-)   | UP    | neutron-openvswitch-agent |
| e988591c-9c9c-41f2-80de-b0e7ac287f45 | Metadata agent     | network-stein | None              | :-)   | UP    | neutron-metadata-agent    |
| fa9ceab9-7f9a-4617-918c-f13b3a515836 | L3 agent           | network-stein | nova              | :-)   | UP    | neutron-l3-agent          |
+--------------------------------------+--------------------+---------------+-------------------+-------+-------+---------------------------+
```