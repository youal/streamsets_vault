#! /usr/bin/env bash

/opt/vault/vault kv put secret/my_path password="secret"


# Now instead of writing the password in your pipeline, you can write:
# ${credential:getwithOptions("vault", "all", "/secret/my_path&password", "delay=1000")}
