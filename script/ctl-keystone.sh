#!/bin/bash                                                                                   
source config.cfg                                                                     
source functions.sh

echocolor "Install keystone"
sleep 3
apt install keystone -y

echocolor "Config keystone"
sleep 3
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
connection = mysql+pymysql://keystone:$KEYSTONE_PASS@$CTL_MGNT_IP/keystone
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

echocolor "Sync DB"
sleep 3
su -s /bin/sh -c "keystone-manage db_sync" keystone

echocolor "Create Fernet key"
sleep 3
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

echocolor " Bootstrap keystone"
sleep 3
keystone-manage bootstrap --bootstrap-password $DEFAULT_PASS \
  --bootstrap-admin-url http://$CTL_MGNT_IP:5000/v3/ \
  --bootstrap-internal-url http://$CTL_MGNT_IP:5000/v3/ \
  --bootstrap-public-url http://$CTL_EXT_IP:5000/v3/ \
  --bootstrap-region-id RegionOne

echocolor "start keystone"
sleep 3
echo "ServerName $HOST_CTL" >> /etc/apache2/apache2.conf
service apache2 restart

cat << EOF > admin-openrc
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$CTL_MGNT_IP:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

source admin-openrc

echocolor "Create service project"
openstack project create --domain default service

echocolor " Create user, endpoint for GLANCE"
sleep 3


openstack user create glance --domain default --password $GLANCE_PASS

openstack role add --project service --user glance admin

openstack service create --name glance --description \
"OpenStack Image service" image

openstack endpoint create --region $REGION_NAME \
    image public http://$CTL_EXT_IP:9292

openstack endpoint create --region $REGION_NAME \
    image internal http://$CTL_MGNT_IP:9292

openstack endpoint create --region $REGION_NAME \
    image admin http://$CTL_MGNT_IP:9292

echocolor "Create user, endpoint for NOVA"

openstack user create nova --domain default  --password $NOVA_PASS

openstack role add --project service --user nova admin

openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create --region $REGION_NAME \
    compute public http://$CTL_EXT_IP:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region $REGION_NAME \
    compute internal http://$CTL_MGNT_IP:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region $REGION_NAME \
    compute admin http://$CTL_MGNT_IP:8774/v2.1/%\(tenant_id\)s


echocolor "Create user, endpoint for placement"

openstack user create placement --domain default --password $PLACEMENT_PASS

openstack role add --user placement --project service admin

openstack service create --name placement --description "Openstack Placement" placement

openstack endpoint create --region $REGION_NAME \
    placement public http://$CTL_EXT_IP:8778

openstack endpoint create --region $REGION_NAME \
    placement internal http://$CTL_MGNT_IP:8778

openstack endpoint create --region $REGION_NAME \
    placement admin http://$CTL_MGNT_IP:8778



echocolor "Create  user, endpoint for NEUTRON"
sleep 5

openstack user create neutron --domain default --password $NEUTRON_PASS

openstack role add --project service --user neutron admin

openstack service create --name neutron \
    --description "OpenStack Networking" network

openstack endpoint create --region $REGION_NAME \
    network public http://$CTL_EXT_IP:9696

openstack endpoint create --region $REGION_NAME \
    network internal http://$CTL_MGNT_IP:9696

openstack endpoint create --region $REGION_NAME \
    network admin http://$CTL_MGNT_IP:9696

echocolor "Create  user, endpoint for CINDER"
sleep 5
openstack user create  --domain default --password $CINDER_PASS cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv2 \
    --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 \
    --description "OpenStack Block Storage" volumev3


openstack endpoint create --region $REGION_NAME \
    volumev2 public http://$CTL_MGNT_IP:8776/v2/%\(tenant_id\)s

openstack endpoint create --region $REGION_NAME \
    volumev2 internal http://$CTL_MGNT_IP:8776/v2/%\(tenant_id\)s

openstack endpoint create --region $REGION_NAME \
    volumev2 admin http://$CTL_MGNT_IP:8776/v2/%\(tenant_id\)s

openstack endpoint create --region $REGION_NAME \
    volumev3 public http://$CTL_MGNT_IP:8776/v3/%\(tenant_id\)s

openstack endpoint create --region $REGION_NAME \
    volumev3 internal http://$CTL_MGNT_IP:8776/v3/%\(tenant_id\)s

openstack endpoint create --region $REGION_NAME \
    volumev3 admin http://$CTL_MGNT_IP:8776/v3/%\(tenant_id\)s
