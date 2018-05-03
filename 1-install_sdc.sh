#! /usr/bin/env bash


HTTPS_PORT=18630

# Authorize the certificate used by the vault server by the client (in this example: sdc)
# Use the certificate from the 1-install_vault.sh script
cp path/to/cert_file /etc/pki/ca-trust/source/anchors/
update-ca-trust extract

yum install java-1.8.0-openjdk.x86_64 -y

# For this example, I use the full sdc RPM for Red Hat 7
wget -P /opt https://archives.streamsets.com/datacollector/3.1.3.0/rpm/el7/streamsets-datacollector-3.1.3.0-el7-all-rpms.tar
tar xvf /opt/streamsets-datacollector-3.1.3.0-el7-all-rpms.tar -C /opt
yum install /opt/streamsets-datacollector-3.1.3.0-el7-all-rpms/streamsets*.rpm -y

# Add the Install section in the service file, used to be able to run sdc at boot time
systemctl add-wants multi-user.target sdc.service
systemctl daemon-reload

# The service runs under the sdc user, so I need to use a port above 1024
sh -c "sed s/https.port=-1/https.port=$HTTPS_PORT/ /etc/sdc/sdc.properties > /etc/sdc/sdc.properties.new"
mv /etc/sdc/sdc.properties.new /etc/sdc/sdc.properties

# Redirect the port 443 to 18631, easier than asking to open a port (if you have root access to the node)
iptables -I INPUT 1 -p tcp --dport $HTTPS_PORT -j ACCEPT
iptables -t nat -A PREROUTING -j REDIRECT -p tcp --dport 443 --to-ports $HTTPS_PORT
mkdir /etc/iptables
iptables-save > /etc/iptables/rules
sh -c "echo '/usr/sbin/iptables-restore /etc/iptables/rules' > /etc/NetworkManager/dispatcher.d/01firewall"

# Modify the cfg file to use Hashicorp vault and Https for the communication
sed s/#credentialStores=jks,vault,cyberark/credentialStores=vault/ /etc/sdc/credential-stores.properties > /etc/sdc/credential-stores.properties.tmp
sed 's;credentialStore.vault.config.addr=http://localhost:8200;credentialStore.vault.config.addr=https://localhost:8200;' /etc/sdc/credential-stores.properties.tmp > /etc/sdc/credential-stores.properties

# Inform sdc of the role-id and the secret-id of the new approle
# Use the ROLE_ID and SECRET_ID from the 1-install_vault.sh script
sed s/credentialStore.vault.config.role.id=/credentialStore.vault.config.role.id=$ROLE_ID/ /etc/sdc/credential-stores.properties > /etc/sdc/credential-stores.properties.tmp
mv /etc/sdc/credential-stores.properties.tmp /etc/sdc/credential-stores.properties
echo $SECRET_ID > /etc/sdc/vault-secret-id

systemctl enable --now sdc.service
