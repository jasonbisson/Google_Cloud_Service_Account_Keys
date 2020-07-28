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
export project_id=$(gcloud config list --format 'value(core.project)')
export bucket=${project_id}-userkeys
export keyfile=$(gsutil ls -l gs://${bucket}/${environment}*json.encrypted 2>/dev/null | sort -k2n | tail -n1 | awk 'END {$1=$2=""; sub(/^[ \t]+/, ""); print }')

function check_variables () {
    if [  -z "${project_id}" ]; then
        printf "ERROR: GCP PROJECT_ID is not set.\n\n"
        printf "To view the current PROJECT_ID config: gcloud config list project \n\n"
        printf "To view available projects: gcloud projects list \n\n"
        printf "To update project config: gcloud config set project PROJECT_ID \n\n"
        exit
    fi
    
    if [  -z "${keyfile}" ]; then
        printf "No files found with prefix ${environment}*.json.encrypted in gs://${bucket}\n"
        printf "It's possible all files have been removed\n"
        exit
    fi
    
}


function decrypt_file () {
    curl -v "https://cloudkms.googleapis.com/v1/projects/$project_id/locations/global/keyRings/$environment/cryptoKeys/$environment:decrypt" \
    -d "{\"ciphertext\":\"$(gsutil cat $keyfile 2>/dev/null)\"}" \
    -H "Authorization:Bearer $(gcloud auth application-default print-access-token 2>/dev/null)"\
    -H "Content-Type:application/json" \
    | jq .plaintext -r | base64 -D > $environment.json
    export GOOGLE_APPLICATION_CREDENTIALS=$PWD/$(ls -t ${environment}*.json |head -1)
}

function check_buckets () {
    python snippets.py implicit
}

function remove_file () {
    rm -f ${environment}*.json*
}

check_variables
decrypt_file
check_buckets
remove_file
