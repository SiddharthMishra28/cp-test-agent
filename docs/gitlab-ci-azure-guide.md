# GitLab CI + Azure Data Factory + ADLS Gen2 Guide

This repository provides a parameterized `.gitlab-ci.yml` and reusable Bash helper functions in `scripts/azure_helpers.sh`.

## What this setup can do

1. Generate an OAuth2 bearer token for Azure Data Factory (Azure Resource Manager scope).
2. Trigger a specific Azure Data Factory pipeline.
3. Generate an OAuth2 bearer token for ADLS Gen2 (Storage scope).
4. Read a file from ADLS Gen2 and print it to CI logs.

## Files

- `.gitlab-ci.yml`: pipeline definition and configurable variables.
- `scripts/azure_helpers.sh`: reusable shell functions called by CI jobs.

## Required GitLab CI/CD Variables

Set these in **GitLab -> Settings -> CI/CD -> Variables**.

### Authentication (required)

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET` (set masked/protected)

### Required for Azure Data Factory jobs

- `AZURE_SUBSCRIPTION_ID`
- `ADF_RESOURCE_GROUP`
- `ADF_FACTORY_NAME`
- `ADF_PIPELINE_NAME`

### Required for ADLS file read jobs

- `ADLS_ACCOUNT_NAME`
- `ADLS_FILE_SYSTEM`
- `ADLS_FILE_PATH`

## Optional Variables (safe defaults already provided)

- `ADF_PIPELINE_PARAMETERS_JSON` default: `{}`
- `ADF_MANAGEMENT_SCOPE` default: `https://management.azure.com/.default`
- `ADF_API_VERSION` default: `2018-06-01`
- `ADLS_STORAGE_SCOPE` default: `https://storage.azure.com/.default`
- `ADLS_API_VERSION` default: `2023-11-03`
- `ADLS_TIMEOUT_SECONDS` default: `120`

## How to run

1. Commit and push your branch.
2. Open GitLab pipeline UI.
3. Run pipeline.
4. Trigger manual jobs as needed:
   - `print_adf_token`
   - `trigger_adf_pipeline`
   - `print_adls_token`
   - `read_adls_file`

## Example parameter payload for ADF

For pipeline parameters, set `ADF_PIPELINE_PARAMETERS_JSON`:

```json
{"RunDate":"2026-03-05","BatchId":"nightly-01","DryRun":false}
```

## Troubleshooting

- **401/403 responses:** Verify service principal RBAC permissions on ADF and Storage.
- **Pipeline not found:** Re-check `ADF_RESOURCE_GROUP`, `ADF_FACTORY_NAME`, and `ADF_PIPELINE_NAME`.
- **ADLS path read errors:** Confirm file system and path, and that the principal has `Storage Blob Data Reader` or equivalent ACL access.

## Security best practices

- Keep `AZURE_CLIENT_SECRET` masked and protected.
- Restrict manual jobs to protected branches/environments when needed.
- Avoid printing full tokens in logs (this setup only prints a short prefix).
