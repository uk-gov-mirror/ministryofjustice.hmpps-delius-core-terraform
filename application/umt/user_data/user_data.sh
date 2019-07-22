#!/bin/bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo BEGIN
date '+%Y-%m-%d %H:%M:%S'

# Setup ECS
echo "ECS_CLUSTER=${ecs_cluster_name}" >> /etc/ecs/ecs.config
service docker start
start ecs

# Install tools
sudo -i
yum install -y git wget yum-utils awslogs jq
easy_install pip
PATH=/usr/local/bin:$PATH
pip install ansible==2.6 virtualenv awscli boto botocore boto3 passlib

# Inject the CloudWatch Logs configuration file contents
export INSTANCE_ID="`curl http://169.254.169.254/latest/meta-data/instance-id`"
cat > /etc/awslogs/awslogs.conf <<- EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_group_name = ${log_group_name}
log_stream_name = $INSTANCE_ID/dmesg

[/var/log/messages]
file = /var/log/messages
log_group_name = ${log_group_name}
log_stream_name = $INSTANCE_ID/messages
datetime_format = %b %d %H:%M:%S

[/var/log/docker]
file = /var/log/docker
log_group_name = ${log_group_name}
log_stream_name = $INSTANCE_ID/docker
datetime_format = %Y-%m-%dT%H:%M:%S.%f

[/var/log/ecs/ecs-init.log]
file = /var/log/ecs/ecs-init.log
log_group_name = ${log_group_name}
log_stream_name = $INSTANCE_ID/ecs-init
datetime_format = %Y-%m-%dT%H:%M:%SZ

[/var/log/ecs/ecs-agent.log]
file = /var/log/ecs/ecs-agent.log.*
log_group_name = ${log_group_name}
log_stream_name = $INSTANCE_ID/ecs-agent
datetime_format = %Y-%m-%dT%H:%M:%SZ

[/var/log/ecs/audit.log]
file = /var/log/ecs/audit.log.*
log_group_name = ${log_group_name}
log_stream_name = $INSTANCE_ID/ecs-audit
datetime_format = %Y-%m-%dT%H:%M:%SZ

EOF

# Set the region to send CloudWatch Logs data to (the region where the container instance is located)
sed -i -e "s/region = us-east-1/region = ${region}/g" /etc/awslogs/awscli.conf

# Start the awslogs service
service awslogs start

# Download user inventory and run ansible
/usr/bin/curl -o ~/users.yml https://raw.githubusercontent.com/ministryofjustice/hmpps-delius-ansible/master/group_vars/${bastion_inventory}.yml
# - users_deleted breaks on the ECS-optimized AMI, so we remove it here:
sed -i '/users_deleted:/,$d' ~/users.yml

cat << EOF > ~/requirements.yml
---

- name: bootstrap
  src: https://github.com/ministryofjustice/hmpps-bootstrap
  version: centos
- name: users
  src: singleplatform-eng.users
- name: umt
  src: https://github.com/ministryofjustice/hmpps-delius-core-umt-bootstrap
EOF
cat << EOF > ~/vars.yml
---

region: "${region}"
environment_name: "${environment_name}"
project_name: "${project_name}"
config_location: "${config_location}"
database_url: "${database_url}"
database_username: "${database_username}"
ldap_url: "${ldap_url}"
ldap_bind_username: "${ldap_bind_username}"
ldap_user_base: "${ldap_user_base}"
ndelius_log_level: "${ndelius_log_level}"

# For user_update cron
remote_user_filename: "${bastion_inventory}"

EOF
cat << EOF > ~/bootstrap.yml
---

- hosts: localhost
  vars_files:
   - "{{ playbook_dir }}/users.yml"
   - "{{ playbook_dir }}/vars.yml"
  roles:
     - bootstrap
     - users
     - umt
EOF

PARAM=$(aws ssm get-parameters --region eu-west-2 \
--with-decryption --name \
"/${environment_name}/${project_name}/delius-database/db/delius_app_schema_password" \
"/${environment_name}/${project_name}/apacheds/apacheds/ldap_admin_password" \
"/${environment_name}/${project_name}/umt/umt/jwt_secret" \
"/${environment_name}/${project_name}/umt/umt/delius_secret" \
--query Parameters)

# set parameter values
database_password="$(echo $PARAM | jq '.[] | select(.Name | test("delius_app_schema_password")) | .Value' --raw-output)"
ldap_bind_password="$(echo $PARAM | jq '.[] | select(.Name | test("ldap_admin_password")) | .Value' --raw-output)"
jwt_secret="$(echo $PARAM | jq '.[] | select(.Name | test("jwt_secret")) | .Value' --raw-output)"
delius_secret="$(echo $PARAM | jq '.[] | select(.Name | test("delius_secret")) | .Value' --raw-output)"

ansible-galaxy install -f -r ~/requirements.yml
ansible-playbook ~/bootstrap.yml \
--extra-vars "{\
'database_password':'$database_password',\
'ldap_bind_password':'$ldap_bind_password',\
'jwt_secret':'$jwt_secret',\
'delius_secret':'$delius_secret',\
}"
