## INSTALL NETWORK NODE

-  Install package:

```
apt install neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent -y
```

-  Tạo brigde br-provider và patch vào đường external network

```
ovs-vsctl add-br br-provider
ovs-vsctl add-port br-provider eth0
```

- Config netplan địa chỉ IP cho đường br-provider:

```
root@network-stein:/etc/neutron# cat /etc/netplan/01-netcfg.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
    br-provider:
      dhcp4: no
      addresses: [10.5.9.60/22]
      gateway4: 10.5.8.1
      nameservers:
              addresses: [8.8.8.8,8.8.4.4]
  ethernets:
    eth1:
      dhcp4: yes
```

- Cấu hình /etc/neutron/neutron.conf

```
cat <<EOF > /etc/neutron/neutron.conf
[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True
auth_strategy = keystone
rpc_backend = rabbit
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
transport_url = rabbit://openstack:stein-demo@172.16.78.20
state_path = /var/lib/neutron
lock_path = $state_path/lock
[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://172.16.78.20:5000
auth_url = http://172.16.78.20:5000
memcached_servers = 172.16.78.20:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = stein-demo

[nova]
auth_url = http://172.16.78.20:5000
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
region_name = RegionOne
username = nova
password = stein-demo
EOF
```

- Config dhcp_agent:

```
cat << EOF > /etc/neutron/dhcp_agent.ini
[DEFAULT]
interface_driver = openvswitch
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = True
num_sync_threads = 10
[agent]
[ovs]
EOF
```

- Config openvswitch-agent:

```
cat << EOF > /etc/neutron/plugins/ml2/openvswitch_agent.ini
[DEFAULT]
[agent]
extensions = qos
tunnel_types = gre
l2_population = True
[ovs]
bridge_mappings = provider:br-provider

local_ip = 10.5.9.60

[securitygroup]
firewall_driver = iptables_hybrid

[xenapi]
EOF
```

- Config l3_agent:

```
cat << EOF > /etc/neutron/l3_agent.ini
DEFAULT]
interface_driver = openvswitch
[agent]
#extensions = vpnaas
[ovs]
[vpnagent]
#vpn_device_driver = neutron_vpnaas.services.vpn.device_drivers.strongswan_ipsec.StrongSwanDriver
EOF
```

- Restart service:

```
service neutron-l3-agent restart
service  neutron-openvswitch-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
```

- Qua controller kiểm tra các service đã hoạt động chưa:

```
root@controller-stein:~# openstack network agent list
+--------------------------------------+--------------------+---------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host          | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+---------------+-------------------+-------+-------+---------------------------+
| 099ce64c-7282-44eb-a4ea-21e3d9666e75 | DHCP agent         | network-stein | nova              | :-)   | UP    | neutron-dhcp-agent        |
| 98383f4a-2c49-4680-8824-e33bd50e1376 | Open vSwitch agent | network-stein | None              | :-)   | UP    | neutron-openvswitch-agent |
| e988591c-9c9c-41f2-80de-b0e7ac287f45 | Metadata agent     | network-stein | None              | :-)   | UP    | neutron-metadata-agent    |
| fa9ceab9-7f9a-4617-918c-f13b3a515836 | L3 agent           | network-stein | nova              | :-)   | UP    | neutron-l3-agent          |
+--------------------------------------+--------------------+---------------+-------------------+-------+-------+---------------------------+
```