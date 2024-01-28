#!/bin/bash

# Argument validation
if [ $# -ne 1 ]; then
    echo "$0: usage: Requires an environment name (e.g., 'senddata') for key retrieval"
    exit 1
fi

environment=$1
project_id=$(gcloud config list --format 'value(core.project)')
bucket="${project_id}-userkeys"

# Function for robust variable checking
function check_variable() {
    local var_name="$1"
    local value="${!var_name}" 
    if [ -z "$value" ]; then
        echo "ERROR: Variable '$var_name' is not set or empty."
        exit 1
    fi
}

# Function for file retrieval with better handling
function get_latest_keyfile() {
    keyfile=$(gsutil ls -l "gs://${bucket}/${environment}*.json.encrypted" 2>/dev/null | sort -k2n | tail -n1 | awk 'END {$1=$2=""; sub(/^[ \t]+/, ""); print }')
    check_variable "keyfile"
}

# Function for decryption with error handling
function decrypt_file() {
    local keyfile="$1"
    local decrypted_file="${environment}.json"

    if ! curl -v "https://cloudkms.googleapis.com/v1/projects/$project_id/locations/global/keyRings/$environment/cryptoKeys/$environment:decrypt" \
        -d "{\"ciphertext\":\"$(gsutil cat "${keyfile}" 2>/dev/null)\"}" \
        -H "Authorization:Bearer $(gcloud auth application-default print-access-token 2>/dev/null)" \
        -H "Content-Type:application/json" \
        | jq .plaintext -r | base64 -D > "${decrypted_file}"; then
            echo "Decryption failed. Check KMS permissions and key validity."
            exit 1
    fi

    export GOOGLE_APPLICATION_CREDENTIALS="${decrypted_file}" 
}

# Function for external operations (contents depend on 'snippets.py')
function check_buckets() {
    python snippets.py implicit || {
        echo "Error in 'check_buckets'. Review 'snippets.py' execution."
        exit 1
    }
}

# Function for secure cleanup
function remove_file() {
     rm -f "${environment}*.json*"
}

# Main Execution
check_variable "project_id"
get_latest_keyfile
decrypt_file "$keyfile"
check_buckets
remove_file

