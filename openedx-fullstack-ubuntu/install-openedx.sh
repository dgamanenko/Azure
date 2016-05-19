#!/bin/bash
# Copyright (c) Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT license. See LICENSE file on the project webpage for details.

set -x
export OPENEDX_RELEASE=$1
CONFIG_REPO=https://github.com/edx/configuration.git
ANSIBLE_ROOT=/edx/app/edx_ansible

EDXAPP_PLATFORM_NAME=$2
EDXAPP_SITE_NAME=$3
EDXAPP_CMS_SITE_NAME=$4
EDXAPP_PREVIEW_LMS_BASE=$5

bash -c "cat <<EOF >>server-vars.yml
EDXAPP_PLATFORM_NAME: \"$EDXAPP_PLATFORM_NAME\"
EDXAPP_SITE_NAME: \"$EDXAPP_SITE_NAME\"
EDXAPP_CMS_SITE_NAME: \"$EDXAPP_CMS_SITE_NAME\"
EDXAPP_PREVIEW_LMS_BASE: \"$EDXAPP_PREVIEW_LMS_BASE\"
EOF"

wget https://raw.githubusercontent.com/edx/configuration/master/util/install/ansible-bootstrap.sh -O- | bash

bash -c "cat <<EOF >extra-vars.yml
---
edx_platform_version: \"$OPENEDX_RELEASE\"
certs_version: \"$OPENEDX_RELEASE\"
forum_version: \"$OPENEDX_RELEASE\"
xqueue_version: \"$OPENEDX_RELEASE\"
configuration_version: \"$OPENEDX_RELEASE\"
edx_ansible_source_repo: \"$CONFIG_REPO\"
COMMON_SSH_PASSWORD_AUTH: \"yes\"
EOF"
sudo -u edx-ansible cp *.yml $ANSIBLE_ROOT

cd /tmp
git clone $CONFIG_REPO

cd configuration
git checkout $OPENEDX_RELEASE
pip install -r requirements.txt

cd playbooks
ansible-playbook -i localhost, -c local vagrant-fullstack.yml -e@$ANSIBLE_ROOT/server-vars.yml -e@$ANSIBLE_ROOT/extra-vars.yml