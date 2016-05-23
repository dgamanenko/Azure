#!/bin/bash

set -x

sudo apt-get update -y
sudo gpg --keyserver keyserver.ubuntu.com --recv A1715D88E1DF1F24

export OPENEDX_RELEASE=$1
# CONFIG_REPO=https://github.com/edx/configuration.git
CONFIG_REPO=https://github.com/raccoongang/configuration.git
ANSIBLE_ROOT=/edx/app/edx_ansible

EDXAPP_PLATFORM_NAME=$2
EDXAPP_SITE_NAME=$3
EDXAPP_CMS_SITE_NAME=$4
EDXAPP_PREVIEW_LMS_BASE=$5

bash -c "sed -i '2iedx_platform_version: \"$OPENEDX_RELEASE\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_PLATFORM_NAME_AZURE: \"$EDXAPP_PLATFORM_NAME\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_SITE_NAME_AZURE: \"$EDXAPP_SITE_NAME\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_CMS_SITE_NAME_AZURE: \"$EDXAPP_CMS_SITE_NAME\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_PREVIEW_LMS_BASE_AZURE: \"$EDXAPP_PREVIEW_LMS_BASE\"' server-vars.yml"

# SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
SECRET_KEY=$(openssl rand -base64 32)
bash -c "sed -i '2iEDXAPP_EDXAPP_SECRET_KEY_AZURE: \"$SECRET_KEY\"' server-vars.yml"

wget https://raw.githubusercontent.com/edx/configuration/master/util/install/ansible-bootstrap.sh -O- | bash

bash -c "cat <<EOF >extra-vars.yml
---
edx_platform_version: \"$OPENEDX_RELEASE\"
#certs_version: \"$OPENEDX_RELEASE\"
#forum_version: \"$OPENEDX_RELEASE\"
#xqueue_version: \"$OPENEDX_RELEASE\"
configuration_version: \"$OPENEDX_RELEASE\"
#edx_ansible_source_repo: \"$CONFIG_REPO\"
COMMON_SSH_PASSWORD_AUTH: \"yes\"
EOF"

sudo -u edx-ansible cp *.yml $ANSIBLE_ROOT

cd /tmp
git clone $CONFIG_REPO

cd configuration
git checkout $OPENEDX_RELEASE
pip install -r requirements.txt

bash -c "sed -i '2i- name: Ensure that optional.txt requirements exist' /tmp/configuration/playbooks/roles/edx_notes_api/tasks/main.yml"
bash -c "sed -i '3i\ \ shell: echo >>/edx/app/edx_notes_api/edx_notes_api/requirements/optional.txt' /tmp/configuration/playbooks/roles/edx_notes_api/tasks/main.yml"
bash -c "sed -i '4i\ \ sudo_user: \"{{ edx_notes_api_user }}\"' /tmp/configuration/playbooks/roles/edx_notes_api/tasks/main.yml"

cd playbooks
ansible-playbook -i localhost, -c local edx_sandbox.yml -e@$ANSIBLE_ROOT/server-vars.yml -e@$ANSIBLE_ROOT/extra-vars.yml
