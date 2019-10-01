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
