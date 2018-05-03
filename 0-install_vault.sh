#! /usr/bin/env bash


wget -P /opt https://releases.hashicorp.com/vault/0.10.0/vault_0.10.0_linux_amd64.zip
unzip /opt/vault_0.10.0_linux_amd64.zip -d /opt/vault
mkdir /opt/vault/{vault_storage,cert}

# Creation of the certificate used by the vault
openssl req -x509 -newkey rsa:4096 -keyout /opt/vault/cert/key.pem -out /opt/vault/cert/cert.pem -nodes


# Create the cfg file for the vault server
# In more complex setup, you might want to use something like consul to have high availability
cat > /opt/vault/config.hcl << EOF
storage "file" {
  path    = "/opt/vault/vault_storage/"


}
listener "tcp" {
 address        = "localhost:8200"
 tls_cert_file  = "/opt/vault/cert/cert.pem"
 tls_key_file   = "/opt/vault/cert/key.pem"
}
EOF

# Run the server
nohup /opt/vault/vault server -config=/opt/vault/config.hcl&


# Initialize the vault server (only once)
# Do not forget to save somewhere the 5 Unseal Keys and the Root Token
/opt/vault/vault operator init

# Each time you start the server, it is sealed
# Repeat 3 times with 3 different Unseal Keys
vaul operator unseal

# Log as root
/opt/vault/vault login

# If you want, you can now create other tokens with different permissions

# Enable the approle authentication method
/opt/vault/vault auth enable approle

# Create cfg file for the policy wich will be used by the approle
cat > /opt/vault/my_policy.hcl << EOF
path "secret/my_path" {
 capabilities = ["read"]

}
EOF

# Create the policy and the approle
/opt/vault/vault policy write my_policy /opt/vault/my_policy.hcl
/opt/vault/vault write auth/approle/role/my_approle  policies="my_policy"

# Inform sdc of the role-id and the secret-id of the new approle
ROLE_STR=$(/opt/vault/vault read auth/approle/role/my_approle/role-id)
ROLE_ID=$(echo $ROLE_STR | cut -d' ' -f 6)

SECRET_STR=$(/opt/vault/vault write -f auth/approle/role/adls/secret-id)
SECRET_ID=$(echo $SECRET_STR | cut -d' ' -f6)
