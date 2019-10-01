## Install CEPH

- Add Ceph repository:

```
cat << EOM > /etc/yum.repos.d/ceph.repo
[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-mimic/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
EOM
```

- Update your repository and install ceph-deploy:

```
sudo yum update
sudo yum install ceph-deploy
```

- Khai báo hostname:

```
echo "172.16.78.6 ceph-1" ?? /etc/hosts
```

- Create the cluster

```
ceph-deploy new ceph-1
```

- Thêm các dòng sau vài file <i>ceph.conf</i>:

```
[global]
fsid = 6710902a-0466-49ba-87b4-d4653783305c
mon_initial_members = ceph-1
mon_host = 172.16.78.6
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx


public network = 172.16.78.6/24
cluster_network = 10.5.9.110/22

osd crush update on start = true

[osd]
osd_max_backfills = 1
osd_recovery_max_active = 1
osd_recovery_op_priority = 1

osd_map_cache_size=20
osd_map_max_advance=10
osd_map_share_max_epochs=10
osd_pg_epoch_persisted_max_stale=10

osd_scrub_begin_hour = 23
osd_scrub_end_hour = 6

osd_scrub_load_threshold = 0.25

```

-  Install Ceph packages:

```
ceph-deploy install ceph-1
```

- Deploy the initial monitor(s) and gather the keys:

```
ceph-deploy mon create-initial
```

- Copy config file and deploy manager daemon:

```
ceph-deploy admin ceph-1
ceph-deploy mgr create ceph-1
```

- Khởi tạo osd:

```
ceph-deploy osd create --data /dev/vdb ceph-1
```

- Kiểm tra hoạt động của Ceph cluster:

```
[root@ceph-1 ~]# ceph -s
  cluster:
    id:     6710902a-0466-49ba-87b4-d4653783305c
    health: HEALTH_OK
 
  services:
    mon: 1 daemons, quorum ceph-1
    mgr: ceph-1(active)
    osd: 1 osds: 1 up, 1 in
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0  objects, 0 B
    usage:   1.0 GiB used, 19 GiB / 20 GiB avail
    pgs:     

```

- Kiểm tra ceph version:

```
[root@ceph-1 ~]# ceph versions
{
    "mon": {
        "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)": 1
    },
    "mgr": {
        "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)": 1
    },
    "osd": {
        "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)": 1
    },
    "mds": {},
    "overall": {
        "ceph version 13.2.6 (7b695f835b03642f85998b2ae7b6dd093d9fbce4) mimic (stable)": 3
    }
}
```


## <a name="glance"> CEPH GLANCE INTEGRATION </a>

- Tạo pool chứa images:

```
ceph osd pool create images 64
```

- Init pool images với rbd:

```
rbd pool init images
```

- Tạo user cho glance trên ceph và cpoy sang controller:

```
ceph auth get-or-create client.glance mon 'profile rbd' osd 'profile rbd pool=images'
ceph auth get-or-create client.glance | ssh root@172.16.78.20 sudo tee /etc/ceph/ceph.client.glance.keyring
```

- Thêm config glance trong <i>/etc/glance/glance-api.conf</i>:

```
[glance_store]
stores = rbd
default_store = rbd
rbd_store_pool = images
rbd_store_user = glance
filesystem_store_datadir = /var/lib/glance/images/
rbd_store_ceph_conf = /etc/ceph/ceph.conf
rbd_store_chunk_size = 8
```

- Tạo file config ceph trên controller:

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
```

