#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -y apt-transport-https curl

mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

cat > /etc/apt/sources.list.d/mariadb.sources << 'EOL'
X-Repolib-Name: MariaDB
Types: deb
URIs: https://mariadb.gb.ssimn.org/repo/12.0/debian
Suites: bookworm
Components: main
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOL

apt-get update && apt-get install -y mariadb-server mariadb-client galera-4 rsync

# Format and mount data disk
mkfs.ext4 -F /dev/disk/by-id/google-galera-data
mkdir -p /var/lib/mysql-data
mount /dev/disk/by-id/google-galera-data /var/lib/mysql-data
echo '/dev/disk/by-id/google-galera-data /var/lib/mysql-data ext4 defaults 0 2' >> /etc/fstab

# Move MySQL data directory
systemctl stop mariadb
rsync -av /var/lib/mysql/ /var/lib/mysql-data/
rm -rf /var/lib/mysql
ln -s /var/lib/mysql-data /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql-data

# Configure Galera first
cat > /etc/mysql/mariadb.conf.d/60-galera.cnf << 'EOF'
[galera]
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_address="gcomm://${cluster_nodes}"
wsrep_cluster_name="galera_cluster"
wsrep_node_address="${node_ip}"
wsrep_node_name="${node_name}"
wsrep_sst_method=rsync
binlog_format=row
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0
datadir=/var/lib/mysql-data
EOF

# Start MariaDB first, then configure users
if [ ${node_index} -eq 0 ]; then
  galera_new_cluster
  sleep 10
  mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'GaleraRoot123!';"
  mariadb -e "CREATE USER 'root'@'%' IDENTIFIED BY 'GaleraRoot123!';"
  mariadb -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
  mariadb -e "FLUSH PRIVILEGES;"
else
  sleep $((${node_index} * 30))
  systemctl start mariadb
fi

systemctl enable mariadb
