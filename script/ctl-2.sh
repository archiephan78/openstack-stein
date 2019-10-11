#!/bin/bash                                                                                   
source config.cfg                                                                     
source functions.sh        

echocolor "Create Database for Keystone" 
sleep 3

mysql -uroot -p$MYSQL_PASS -e "                                                 
CREATE DATABASE keystone;                                                          
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';       
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';       
FLUSH PRIVILEGES;"                                      
                                
                                                 
echocolor "Create the database for GLANCE"          
sleep 3                                                                                             
                                                                                            
mysql -uroot -p$MYSQL_PASS -e "                                 
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
FLUSH PRIVILEGES;"                                                                                                             
                                                                                                                                                                                            
                                                                                                                                                                                 
echocolor "Create DB for NOVA"
sleep 3

mysql -uroot -p$MYSQL_PASS -e "                                          
CREATE DATABASE nova_api;                                  
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova_api'@'localhost' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova_api'@'%' IDENTIFIED BY '$NOVA_API_DBPASS';
FLUSH PRIVILEGES;"          


mysql -uroot -p$MYSQL_PASS -e "
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova_cell0'@'localhost' IDENTIFIED BY '$NOVA_CELL0_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova_cell0'@'%' IDENTIFIED BY '$NOVA_CELL0_DBPASS';
FLUSH PRIVILEGES;"



mysql -uroot -p$MYSQL_PASS -e "
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$NOVA_PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$NOVA_PLACEMENT_DBPASS';
FLUSH PRIVILEGES;"



echocolor "Create DB for NEUTRON "
sleep 3

mysql -uroot -p$MYSQL_PASS -e "
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
FLUSH PRIVILEGES;"


echocolor "Create DB for CINDER"
sleep 5
mysql -uroot -p$MYSQL_PASS -e "
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
FLUSH PRIVILEGES;"


# echocolor "Create DB for OCTAVIA"
# sleep 5
# mysql -uroot -p$MYSQL_PASS -e "
# CREATE DATABASE octavia;
# GRANT ALL PRIVILEGES ON octavia.* TO 'octavia'@'localhost' IDENTIFIED BY '$OCTAVIA_DBPASS';
# GRANT ALL PRIVILEGES ON octavia.* TO 'octavia'@'%' IDENTIFIED BY '$OCTAVIA_DBPASS';
# FLUSH PRIVILEGES;"

