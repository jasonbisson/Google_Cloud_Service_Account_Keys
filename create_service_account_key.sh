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
    echo $0: usage: Requires argument of i.e. senddata
    exit 1
fi

export environment=$1
export keystate=$(gcloud kms keys describe ${environment} --keyring=${environment} --location=global --format json |jq -r .primary.state)
export project_id=$(gcloud config list --format 'value(core.project)')
export bucket=${project_id}-userkeys
export now=$(date +"%Y%m%d%H%M%S")

function check_variables () {
    if [  -z "${project_id}" ]; then
        printf "ERROR: GCP PROJECT_ID is not set.\n\n"
        printf "To view the current PROJECT_ID config: gcloud config list project \n\n"
        printf "To view available projects: gcloud projects list \n\n"
        printf "To update project config: gcloud config set project PROJECT_ID \n\n"
        exit
    fi
    
    if [[ ${keystate} != *"ENABLED"* ]];then
        printf "ERROR: Symmentric cryptographic key is not enabled to perform file level encryption of service account key file.\n\n"
        printf "Run create_encryption_key.sh script <environment> to create the Symmentric cryptographic key and rerun  \n\n"
        exit
    fi
    
    
}

function create_key () {
    gcloud iam service-accounts keys create ${environment}.${now}.json --iam-account "${environment}@$project_id.iam.gserviceaccount.com" 2>/dev/null
}

function encrypt_key () {
    keyfile=$(cat ${environment}.${now}.json | base64)
    curl -v "https://cloudkms.googleapis.com/v1/projects/${project_id}/locations/global/keyRings/${environment}/cryptoKeys/${environment}:encrypt" \
    -d "{\"plaintext\":\"${keyfile}\"}" \
    -H "Authorization:Bearer $(gcloud auth application-default print-access-token 2>/dev/null)" \
    -H "Content-Type:application/json" 2>/dev/null \
    | jq .ciphertext -r > ${environment}.${now}.json.encrypted
}

function check_bucket () {
    exists=$(gsutil ls -b gs://$bucket)
    if [  -z "$exists" ]; then
        gsutil mb gs://${bucket}
    fi
}

function check_file () {
    MINSIZE=5
    ACTUALSIZE=$(wc -c ${environment}.${now}.json.encrypted | awk '{print $1}')
    if [ $ACTUALSIZE -eq $MINSIZE ]; then
        printf "ERROR: User key ${environment}.${now}.json.encrypted is the incorrect size.\n\n"
        printf "To determine failure run: gcloud auth application-default print-access-token"
        printf "Manual clean up of latest key under ${environment}@$project_id.iam.gserviceaccount.com will be required"
        exit
    fi
}

function upload_file () {
    gsutil cp ${environment}.${now}.json.encrypted gs://$bucket
    rm -f ${environment}*json*
}

check_variables
create_key
encrypt_key
check_bucket
check_file
upload_file
