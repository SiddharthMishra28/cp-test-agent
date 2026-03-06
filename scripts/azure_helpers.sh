#!/usr/bin/env bash
set -euo pipefail

# Reusable helper functions for GitLab CI jobs that call Azure REST APIs.
# Expected dependencies: curl, python3

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: Required environment variable '$name' is not set." >&2
    return 1
  fi
}

urlencode() {
  python3 - <<'PY'
import os
import urllib.parse
print(urllib.parse.quote(os.environ["VALUE"], safe=""))
PY
}

# Generic OAuth2 client credentials token request against Microsoft Entra ID.
# Arguments:
#   $1 -> scope (for example: https://management.azure.com/.default)
get_oauth2_token() {
  local scope="${1:-}"
  require_env AZURE_TENANT_ID
  require_env AZURE_CLIENT_ID
  require_env AZURE_CLIENT_SECRET

  if [[ -z "$scope" ]]; then
    echo "ERROR: scope argument is required." >&2
    return 1
  fi

  log "Requesting OAuth2 token for scope: $scope"
  local response
  response=$(curl --silent --show-error --fail \
    --request POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
    --data-urlencode "client_secret=${AZURE_CLIENT_SECRET}" \
    --data-urlencode "scope=${scope}")

  python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$response"
}

get_adf_management_token() {
  get_oauth2_token "${ADF_MANAGEMENT_SCOPE:-https://management.azure.com/.default}"
}

get_adls_storage_token() {
  get_oauth2_token "${ADLS_STORAGE_SCOPE:-https://storage.azure.com/.default}"
}

# Trigger an Azure Data Factory pipeline run using Azure REST API.
trigger_adf_pipeline() {
  require_env AZURE_SUBSCRIPTION_ID
  require_env ADF_RESOURCE_GROUP
  require_env ADF_FACTORY_NAME
  require_env ADF_PIPELINE_NAME

  local token="$1"
  if [[ -z "$token" ]]; then
    echo "ERROR: trigger_adf_pipeline requires a bearer token as argument." >&2
    return 1
  fi

  local encoded_pipeline
  VALUE="$ADF_PIPELINE_NAME" encoded_pipeline=$(urlencode)

  local body
  body="${ADF_PIPELINE_PARAMETERS_JSON:-{}}"

  log "Triggering pipeline '${ADF_PIPELINE_NAME}' in factory '${ADF_FACTORY_NAME}'."
  curl --silent --show-error --fail \
    --request POST \
    "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${ADF_RESOURCE_GROUP}/providers/Microsoft.DataFactory/factories/${ADF_FACTORY_NAME}/pipelines/${encoded_pipeline}/createRun?api-version=${ADF_API_VERSION:-2018-06-01}" \
    --header "Authorization: Bearer ${token}" \
    --header "Content-Type: application/json" \
    --data "${body}"
}

# Read and print a file from ADLS Gen2 using DFS endpoint.
# Env vars:
#   ADLS_ACCOUNT_NAME, ADLS_FILE_SYSTEM, ADLS_FILE_PATH
# Optional:
#   ADLS_TIMEOUT_SECONDS (default 120)
read_adls_file_to_console() {
  require_env ADLS_ACCOUNT_NAME
  require_env ADLS_FILE_SYSTEM
  require_env ADLS_FILE_PATH

  local token="$1"
  if [[ -z "$token" ]]; then
    echo "ERROR: read_adls_file_to_console requires a bearer token as argument." >&2
    return 1
  fi

  local encoded_path
  VALUE="$ADLS_FILE_PATH" encoded_path=$(urlencode)

  local url="https://${ADLS_ACCOUNT_NAME}.dfs.core.windows.net/${ADLS_FILE_SYSTEM}/${encoded_path}?action=read"
  log "Reading ADLS Gen2 file '${ADLS_FILE_PATH}' from filesystem '${ADLS_FILE_SYSTEM}'."

  curl --silent --show-error --fail \
    --max-time "${ADLS_TIMEOUT_SECONDS:-120}" \
    --request GET "$url" \
    --header "Authorization: Bearer ${token}" \
    --header "x-ms-version: ${ADLS_API_VERSION:-2023-11-03}" \
    --header "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')"
}
