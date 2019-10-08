source config.cfg
source functions.sh

echocolor "Enable the OpenStack repository"
sleep 5
apt-get update
apt-get install software-properties-common -y
add-apt-repository cloud-archive:$VERSION -y

sleep 5
echocolor "Upgrade the packages for server"
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

echocolor "Installing CRUDINI"
sleep 3
apt-get install -y crudini

echocolor "Install python client"
apt-get -y install python-openstackclient
sleep 5

##############################################
echocolor "Install and Config RabbitMQ"
sleep 3

apt-get install rabbitmq-server -y
rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
# rabbitmqctl change_password guest $RABBIT_PASS
sleep 3

service rabbitmq-server restart
echocolor "Finish setup pre-install package !!!"

echocolor "Install MYSQL"
sleep 3

echo mysql-server mysql-server/root_password password \
$MYSQL_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password \
$MYSQL_PASS | debconf-set-selections
apt-get -y install mariadb-server python-mysqldb curl

echocolor "Configuring MYSQL"
sleep 5

touch /etc/mysql/mariadb.conf.d/99-openstack.cnf
cat << EOF > /etc/mysql/mariadb.conf.d/99-openstack.cnf

[mysqld]
bind-address = 0.0.0.0

[mysqld]
default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8

EOF

sleep 5
echocolor "Restarting MYSQL"
service mysql restart

echocolor "Install Memcached"
apt install -y memcached

cat << EOF > /etc/memcached.conf
-d
logfile /var/log/memcached.log
-m 64
-p 11211
-u memcache
-l $CTL_MGNT_IP
EOF

echocolor "Restart memcache"
systemctl restart memcached 
