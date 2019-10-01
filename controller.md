### Install Enviroment and DB

-  Add reponesitory của Openstack (OPS) và update:

```
add-apt-repository cloud-archive:stein
apt update && apt dist-upgrade -y
apt install python3-openstackclient -y
```

- Cài đặt Mysql:

```
apt install mariadb-server python-pymysql -y
```

- Config <i>/etc/mysql/mariadb.conf.d/99-openstack.cnf</i> bind vào ip dải management của controller:

```
touch /etc/mysql/mariadb.conf.d/99-openstack.cnf
cat << EOF > /etc/mysql/mariadb.conf.d/99-openstack.cnf
[mysqld]
bind-address = 172.16.78.20

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
```
- Restart service:

```
service mysql restart
```

- Cài đăt rabbitmq:

```
apt install rabbitmq-server -y
rabbitmqctl add_user openstack stein-demo
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
```

- Cài đặt memcache:

```
apt install memcached python-memcache -y
```

- Config memcache bind vào địa chỉ mạng management và restart service:

```
sed -i 's/127.0.0.1/172.16.78.20/g' /etc/memcached.conf
service memcached restart
```

- Kiểm tra nhanh các service trên có hoạt động không:

```
systemctl status mysql && systemctl status memcached && systemctl status rabbitmq-server
```

### Install Keystone (Identity service):

- Tạo DB và user keystone:

```
mysql                                              
CREATE DATABASE keystone;                                                          
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'stein-demo';      
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'stein-demo';      
FLUSH PRIVILEGES;                                        
exit

```

- Install keystone package:

```
apt install keystone -y
```

- Config :

```
cat << EOF > /etc/keystone/keystone.conf 
[DEFAULT]
log_dir = /var/log/keystone
[access_rules_config]
[application_credential]
[assignment]
[auth]
[cache]
[catalog]
[cors]
[credential]
[database]
connection = mysql+pymysql://keystone:stein-demo@172.16.78.20/keystone
[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[extra_headers]
Distribution = Ubuntu
[federation]
[fernet_receipts]
[fernet_tokens]
[healthcheck]
[identity]
[identity_mapping]
[jwt_tokens]
[ldap]
[memcache]
[oauth1]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[policy]
[profiler]
[receipt]
[resource]
[revoke]
[role]
[saml]
[security_compliance]
[shadow_users]
[signing]
[token]
provider = fernet
[tokenless_auth]
[trust]
[unified_limit]
[wsgi]
EOF
```

- Seed DB keystone:

```
su -s /bin/sh -c "keystone-manage db_sync" keystone
```

- Create Fernet key:

```
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
```

- Bootstrap keystone

```
keystone-manage bootstrap --bootstrap-password stein-demo \
  --bootstrap-admin-url http://172.16.78.20:5000/v3/ \
  --bootstrap-internal-url http://172.16.78.20:5000/v3/ \
  --bootstrap-public-url http://10.5.8.116:5000/v3/ \
  --bootstrap-region-id RegionOne
```

- Do keystone hiện nay chạy dưới 1 module wsgi của apache nên config apache và restart:

```
echo "ServerName controller-stein" >> /etc/apache2/apache2.conf
service apache2 restart
```

- Create admin-rc:

```
cat << EOF > admin-rc
export OS_USERNAME=admin
export OS_PASSWORD=stein-demo
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://172.16.78.20:5000/v3
export OS_IDENTITY_API_VERSION=3
EOF
. admin-rc
```

- Create a domain, projects, users, and roles:

```
openstack domain create --description "An Example Domain" example
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" myproject
openstack user create --domain default --password-prompt myuser
openstack role create myrole
openstack role add --project myproject --user myuser myrole
```

## Install Glance (Image service)

- Create database:

```
mysql
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'stein-demo';
exit

```

- Create user and endpoint glance:

```
openstack user create glance --domain default --password stein-demo
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://10.5.8.116:9292
openstack endpoint create --region RegionOne image internal http://172.16.78.20:9292
openstack endpoint create --region RegionOne image admin http://172.16.78.20:9292
```

- Install glance package:

```
apt install glance ceph-common python3-rbd -y
```

- config glance:

```
cat << EOF > /etc/glance/glance-api.conf
[DEFAULT]
show_image_direct_url = True
enable_v2_api = true
enable_v2_registry = true
enable_v1_api = true
enable_v1_registry = true
[cors]
[database]
connection = mysql+pymysql://glance:stein-demo@172.16.78.20/glance
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
www_authenticate_uri = http://172.16.78.20:5000
auth_url = http://172.16.78.20:5000
memcached_servers = 172.16.78.20:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = stein-demo
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
```

- Config ceph ở bên mục ceph config glance [Here](ceph.md#glance)

- Sync DB:

```
su -s /bin/sh -c "glance-manage db_sync" glance
```

- Restart service :

```
service glance-api restart
```

- Test up image:

```
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
openstack image create "cirros" --file cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
```

- Kết quả, để ý phần proerties hiện ra là path voulme đó trên ceph:

```
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field            | Value                                                                                                                                                                                                                                                                                                |
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| checksum         | 443b7623e27ecf03dc9e01ee93f67afe                                                                                                                                                                                                                                                                     |
| container_format | bare                                                                                                                                                                                                                                                                                                 |
| created_at       | 2019-10-01T08:38:05Z                                                                                                                                                                                                                                                                                 |
| disk_format      | qcow2                                                                                                                                                                                                                                                                                                |
| file             | /v2/images/9be7bd27-9a5c-4995-b166-4517b144759b/file                                                                                                                                                                                                                                                 |
| id               | 9be7bd27-9a5c-4995-b166-4517b144759b                                                                                                                                                                                                                                                                 |
| min_disk         | 0                                                                                                                                                                                                                                                                                                    |
| min_ram          | 0                                                                                                                                                                                                                                                                                                    |
| name             | cirros                                                                                                                                                                                                                                                                                               |
| owner            | f04eaf5178eb40d7a44c6b77af183d25                                                                                                                                                                                                                                                                     |
| properties       | direct_url='rbd://6710902a-0466-49ba-87b4-d4653783305c/images/9be7bd27-9a5c-4995-b166-4517b144759b/snap', os_hash_algo='sha512', os_hash_value='6513f21e44aa3da349f248188a44bc304a3653a04122d8fb4535423c8e1d14cd6a153f735bb0982e2161b5b5186106570c17a9e58b64dd39390617cd5a350f78', os_hidden='False' |
| protected        | False                                                                                                                                                                                                                                                                                                |
| schema           | /v2/schemas/image                                                                                                                                                                                                                                                                                    |
| size             | 12716032                                                                                                                                                                                                                                                                                             |
| status           | active                                                                                                                                                                                                                                                                                               |
| tags             |                                                                                                                                                                                                                                                                                                      |
| updated_at       | 2019-10-01T08:38:08Z                                                                                                                                                                                                                                                                                 |
| virtual_size     | None                                                                                                                                                                                                                                                                                                 |
| visibility       | public                                                                                                                                                                                                                                                                                               |
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
```
- Kiểm tra bên ceph image đã được upload:

```
[root@ceph-1 ~]# rbd info images/9be7bd27-9a5c-4995-b166-4517b144759b
rbd image '9be7bd27-9a5c-4995-b166-4517b144759b':
        size 12 MiB in 2 objects
        order 23 (8 MiB objects)
        id: 10476b8b4567
        block_name_prefix: rbd_data.10476b8b4567
        format: 2
        features: layering, exclusive-lock, object-map, fast-diff, deep-flatten
        op_features: 
        flags: 
        create_timestamp: Tue Oct  1 15:38:07 2019
```
- List image:

```
root@controller-stein:~# openstack image list
+--------------------------------------+--------+--------+
| ID                                   | Name   | Status |
+--------------------------------------+--------+--------+
| 9be7bd27-9a5c-4995-b166-4517b144759b | cirros | active |
+--------------------------------------+--------+--------+
```

## INSTALL PLACEMENT (placement service)

- Crete database:

```
mysql
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'stein-demo';
exit

```

- Khởi tạo user và endpoint:

```
openstack user create placement --domain default --password stein-demo
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://10.5.8.116:8778
openstack endpoint create --region RegionOne placement internal http://172.16.78.20:8778
openstack endpoint create --region RegionOne placement admin http://172.16.78.20:8778
```

- Install package:

```
apt install placement-api -y
```

- Config:

```
cat << EOF > /etc/placement/placement.conf
[DEFAULT]
[api]
auth_strategy = keystone
[keystone_authtoken]
auth_url = http://172.16.78.20:5000/v3
memcached_servers = 172.16.78.20:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = placement
password = stein-demo
[placement]
[placement_database]
connection = mysql+pymysql://placement:stein-demo@172.16.78.20/placement
EOF
```

- Sync DB:

```
su -s /bin/sh -c "placement-manage db sync" placement
```

- Do placement api chay quia wsgi của apache nên restart apache để apply config

```
service apache2 restart
```

- Verify:

```
root@controller-stein:~# placement-status upgrade check
+----------------------------------+
| Upgrade Check Results            |
+----------------------------------+
| Check: Missing Root Provider IDs |
| Result: Success                  |
| Details: None                    |
+----------------------------------+
| Check: Incomplete Consumers      |
| Result: Success                  |
| Details: None                    |
+----------------------------------+
```


## INSTALL NOVA (Compute service)

- Create DB:

```
mysql
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'stein-demo';
exit

```

- Create the Compute service credentials:

```
openstack user create nova --domain default --password stein-demo
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://10.5.8.116:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://172.16.78.20:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://172.16.78.20:8774/v2.1
```

- Install package:

```
apt install nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler -y
```

- Config nova

```
cat << EOF > /etc/nova/nova.conf
[DEFAULT]    
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver                          
allow_resize_to_same_host = True
state_path=/var/lib/nova
enabled_apis=osapi_compute,metadata 
log_dir=/var/log/nova                  
log-dir = /var/log/nova
rootwrap_config = /etc/nova/rootwrap.conf
my_ip = 10.5.8.116         
transport_url = rabbit://openstack:stein-demo@172.16.78.20
     
                         
[api]    
auth_strategy = keystone            
[api_database]        
connection=mysql+pymysql://nova:stein-demo@172.16.78.20/nova_api
                          
[database]             
connection = mysql+pymysql://nova:stein-demo@172.16.78.20/nova
                                              
[glance]                                     
api_servers = http://172.16.78.20:9292

[keystone_authtoken]              
auth_url = http://172.16.78.20:5000  
memcached_servers = 172.16.78.20:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default 
project_name = service
username = nova
password = stein-demo

[libvirt]
virt_type = kvm

[neutron]
auth_url = http://172.16.78.20:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = neutron
password = stein-demo

service_metadata_proxy = True
metadata_proxy_shared_secret = stein-demo
url = http://172.16.78.20:9696

[oslo_concurrency]
lock_path=/var/lib/nova/tmp

[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://172.16.78.20:5000/v3
username = placement
password = stein-demo

[vnc]
server_listen = $my_ip
server_proxyclient_address = $my_ip

[wsgi]
api_paste_config=/etc/nova/api-paste.ini
## Auto discover new compute host
[scheduler]
discover_hosts_in_cells_interval = 300

[cache]
enabled = true
backend = oslo_cache.memcache_pool
memcache_servers = 172.16.78.20:11211

[workarounds]
enable_consoleauth = True
EOF
```

- Sync DB:

```
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
```

- Restart service:

```
service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
```

- Verify:

```
root@controller-stein:~# openstack compute service list
+----+------------------+------------------+----------+---------+-------+----------------------------+
| ID | Binary           | Host             | Zone     | Status  | State | Updated At                 |
+----+------------------+------------------+----------+---------+-------+----------------------------+
|  1 | nova-scheduler   | controller-stein | internal | enabled | up    | 2019-10-01T09:47:52.000000 |
|  2 | nova-consoleauth | controller-stein | internal | enabled | up    | 2019-10-01T09:47:51.000000 |
|  7 | nova-conductor   | controller-stein | internal | enabled | up    | 2019-10-01T09:47:54.000000 |
+----+------------------+------------------+----------+---------+-------+----------------------------+
```

```
root@controller-stein:~# openstack catalog list
+-----------+-----------+-------------------------------------------+
| Name      | Type      | Endpoints                                 |
+-----------+-----------+-------------------------------------------+
| nova      | compute   | RegionOne                                 |
|           |           |   internal: http://172.16.78.20:8774/v2.1 |
|           |           | RegionOne                                 |
|           |           |   admin: http://172.16.78.20:8774/v2.1    |
|           |           | RegionOne                                 |
|           |           |   public: http://10.5.8.116:8774/v2.1     |
|           |           |                                           |
| placement | placement | RegionOne                                 |
|           |           |   public: http://10.5.8.116:8778          |
|           |           | RegionOne                                 |
|           |           |   admin: http://172.16.78.20:8778         |
|           |           | RegionOne                                 |
|           |           |   internal: http://172.16.78.20:8778      |
|           |           |                                           |
| keystone  | identity  | RegionOne                                 |
|           |           |   admin: http://172.16.78.20:5000/v3/     |
|           |           | RegionOne                                 |
|           |           |   internal: http://172.16.78.20:5000/v3/  |
|           |           | RegionOne                                 |
|           |           |   public: http://10.5.8.116:5000/v3/      |
|           |           |                                           |
| glance    | image     | RegionOne                                 |
|           |           |   admin: http://172.16.78.20:9292         |
|           |           | RegionOne                                 |
|           |           |   public: http://10.5.8.116:9292          |
|           |           | RegionOne                                 |
|           |           |   internal: http://172.16.78.20:9292      |
|           |           |                                           |
+-----------+-----------+-------------------------------------------+
```


## INSTALL NEUTRON (Networking service)

- Create DB:

```
mysql
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'stein-demo';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'stein-demo';
exit

```

- Create service credentials:

```
openstack user create neutron --domain default --password stein-demo
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://10.5.8.116:9696
openstack endpoint create --region RegionOne network internal http://172.16.78.20:9696
openstack endpoint create --region RegionOne network admin http://172.16.78.20:9696
```

- Install neutron với cấu hình self-service network và sử dụng openvswitch:

```
apt install neutron-server neutron-plugin-ml2 -y
```

- Config <i>/etc/neutron/neutron.conf</i>:

```
cat <<EOF > /etc/neutron/neutron.conf
[DEFAULT]           
core_plugin = ml2                 
service_plugins = neutron.services.qos.qos_plugin.QoSPlugin, router
allow_overlapping_ips = true
auth_strategy = keystone     
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true
transport_url = rabbit://openstack:stein-demo@172.16.78.20
## HA Router                                       
l3_ha = True
allow_automatic_l3agent_failover = True
max_l3_agents_per_router = 2      
min_l3_agents_per_router = 2
                             
## HA DHCP                
dhcp_agents_per_network = 2
global_physnet_mtu = 1542     
max_allowed_address_pair = 25
rpc_response_timeout = 300                         

[agent]            
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf                                   
                        
[database]
connection = mysql+pymysql://neutron:stein-demo@172.16.78.20/neutron
max_pool_size=32

[keystone_authtoken]
auth_url = http://172.16.78.20:5000
memcached_servers = 172.16.78.20:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = stein-demo

[nova]
auth_url = http://172.16.78.20:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
region_name = RegionOne
username = nova
password = stein-demo

[service_providers]
#service_provider = VPN:strongswan:neutron_vpnaas.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default
EOF
```

- Config <i>/etc/neutron/plugins/ml2/ml2_conf.ini</i>:

```
cat <<EOF > /etc/neutron/plugins/ml2/ml2_conf.ini
[DEFAULT]
path_mtu = 1542
physical_network_mtus = physnet1:1500
[ml2]
type_drivers = flat,vlan,gre
tenant_network_types = gre,vlan
mechanism_drivers = openvswitch,l2population
extension_drivers = port_security, qoss

[ml2_type_flat]
flat_networks = external

[ml2_type_gre]
tunnel_id_ranges = 100:20000

[ml2_type_vlan]
network_vlan_ranges = physnet1:2100:2150

[securitygroup]
enable_ipset = True
EOF
```

## INSTALL HORIZON

- Install package:

```
apt install openstack-dashboard -y
```

- Config horizon <i> /etc/openstack-dashboard/local_settings.py</i> ( chỉnh sửa những dòng sau):

```
OPENSTACK_HOST = "controller"
ALLOWED_HOSTS = [*]
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': '172.16.78.20:11211',
    }
}
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
TIME_ZONE = "UTC"
```

- Reload apache2:

```
service apache2 reload
```

- Truy cập theo đường dẫn <i> http://10.5.8.116/horizon </i>:


![](static/horizon.png) 