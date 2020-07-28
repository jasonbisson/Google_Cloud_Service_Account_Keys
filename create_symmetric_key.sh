#!/bin/bash
#set -x
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ $# -ne 1 ]; then
    echo $0: usage: Requires environment argument of i.e. senddata
    exit 1
fi

ENVIRONMENT=$1
KEYRING=$ENVIRONMENT
CRYPTOKEY=$ENVIRONMENT
LOCATION=global
export project_id=$(gcloud config list --format 'value(core.project)')

function check_variables () {
    if [  -z "$project_id" ]; then
        printf "ERROR: GCP PROJECT_ID is not set.\n\n"
        printf "To view the current PROJECT_ID config: gcloud config list project \n\n"
        printf "To view available projects: gcloud projects list \n\n"
        printf "To update project config: gcloud config set project PROJECT_ID \n\n"
        exit
    fi
}

function enable_service () {
    gcloud services enable cloudkms.googleapis.com
}

function create_key_ring () {
    gcloud kms keyrings create $KEYRING --location $LOCATION
}

function create_key () {
    gcloud kms keys create $CRYPTOKEY --location global  --keyring $KEYRING --purpose encryption
}

check_variables
enable_service
create_key_ring
create_key
