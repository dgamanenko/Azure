#!/bin/bash

set -x
export OPENEDX_RELEASE=$1
# CONFIG_REPO=https://github.com/edx/configuration.git
CONFIG_REPO=https://github.com/raccoongang/configuration.git
ANSIBLE_ROOT=/edx/app/edx_ansible

EDXAPP_PLATFORM_NAME=$2
EDXAPP_SITE_NAME=$3
EDXAPP_CMS_SITE_NAME=$4
EDXAPP_PREVIEW_LMS_BASE=$5

AZURE_AD_CLIENT_ID=$6
AZURE_AD_APP_KEY=$7
AZURE_AD_APP_SECRET=$8

bash -c "sed -i '2iedx_platform_version: \"$OPENEDX_RELEASE\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_PLATFORM_NAME_AZURE: \"$EDXAPP_PLATFORM_NAME\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_SITE_NAME_AZURE: \"$EDXAPP_SITE_NAME\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_CMS_SITE_NAME_AZURE: \"$EDXAPP_CMS_SITE_NAME\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_PREVIEW_LMS_BASE_AZURE: \"$EDXAPP_PREVIEW_LMS_BASE\"' server-vars.yml"
bash -c "sed -i '2iEDXAPP_AZURE_AD_CLIENT_ID: \"$AZURE_AD_CLIENT_ID\"' server-vars.yml"

# SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
SECRET_KEY=$(openssl rand -base64 32)
bash -c "sed -i '2iEDXAPP_EDXAPP_SECRET_KEY_AZURE: \"$SECRET_KEY\"' server-vars.yml"

wget https://raw.githubusercontent.com/edx/configuration/master/util/install/ansible-bootstrap.sh -O- | bash

bash -c "cat <<EOF >extra-vars.yml
---
edx_platform_version: \"$OPENEDX_RELEASE\"
certs_version: \"$OPENEDX_RELEASE\"
forum_version: \"$OPENEDX_RELEASE\"
xqueue_version: \"$OPENEDX_RELEASE\"
configuration_version: \"microsoft-oauth2\"
edx_ansible_source_repo: \"$CONFIG_REPO\"
COMMON_SSH_PASSWORD_AUTH: \"yes\"
EOF"

sudo -u edx-ansible cp *.yml $ANSIBLE_ROOT

#----------------------------------------------------------------------------------
OAUTH_ROLE_ROOT=$ANSIBLE_ROOT/edx_ansible/playbooks/roles/edx-add-oauth2-backend
sudo -u edx-ansible mkdir -p $OAUTH_ROLE_ROOT/files
sudo -u edx-ansible mkdir -p $OAUTH_ROLE_ROOT/tasks

bash -c "cat <<EOF >edx-add-oauth2-backend.py
#!/usr/bin/env python
import os,sys
sys.path.append('/edx/app/edxapp/edx-platform')
os.environ['PATH'] = '/edx/app/edxapp/venvs/edxapp/bin:/edx/app/edxapp/edx-platform/bin:/edx/app/edxapp/.rbenv/bin:/edx/app/edxapp/.rbenv/shims:/edx/app/edxapp/.gem/bin:/edx/app/edxapp/edx-platform/node_modules/.bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
os.environ['DJANGO_SETTINGS_MODULE'] = 'lms.envs.aws'
os.environ['SERVICE_VARIANT'] = 'lms'
from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
from third_party_auth.models import OAuth2ProviderConfig 
OAuth2ProviderConfig.objects.create(enabled=True, icon_class='fa-sign-in', name='microsoft', skip_registration_form=True, skip_email_verification=True, backend_name='microsoft-oauth2', key='$AZURE_AD_APP_KEY', secret='$AZURE_AD_APP_SECRET', other_settings='{}')
OAuth2ProviderConfig.objects.create(enabled=True, icon_class='fa-sign-in', name='cms-microsoft', skip_registration_form=True, skip_email_verification=True, backend_name='cms-microsoft-oauth2', key='$AZURE_AD_APP_KEY', secret='$AZURE_AD_APP_SECRET', other_settings='{}')
EOF"

sudo -u edx-ansible cp edx-add-oauth2-backend.py $OAUTH_ROLE_ROOT/files/

bash -c "cat <<EOF >main.yml
- name: Add oauth2 backend
  script: edx-add-oauth2-backend.py
EOF"

sudo -u edx-ansible cp main.yml $OAUTH_ROLE_ROOT/files/roles
#----------------------------------------------------------------------------------


cd /tmp
git clone $CONFIG_REPO

cd configuration
git checkout microsoft-oauth2
pip install -r requirements.txt

cd playbooks
ansible-playbook -i localhost, -c local edx_sandbox.yml -e@$ANSIBLE_ROOT/server-vars.yml -e@$ANSIBLE_ROOT/extra-vars.yml


# sudo -Hu edxapp bash
# source /edx/app/edxapp/edxapp_env 
# python edx-add-oauth2-backend.py
# exit

