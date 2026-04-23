---
name: iru-api
description: Call any Iru (formerly Kandji) Endpoint Management REST API endpoint using a personal API token. Use when the user says "list iru devices", "create iru custom script", "update iru script", "push custom script to iru", "assign library item to blueprint", "lock iru device", "get filevault recovery key", "list iru blueprints", "create iru tag", "query prism", "get iru vulnerabilities", "list iru threats", "get iru audit log", or otherwise asks to read, create, update, or delete anything in Iru / Kandji. Reads the token from `~/.config/api-skills/iru.yaml`. Auth is `Authorization: Bearer <token>` (not raw). Full endpoint reference lives at `~/git/vendor-api-docs/kandji/` (the vendor's docs repo still uses the old name).
---

# Iru Endpoint Management API

Call the Iru v1 REST API with a personal API token.

**Naming note:** Iru was previously called Kandji. The API hostname is still `*.api.kandji.io`, the vendor-docs repo is still named `kandji/`, and many response field names still contain "kandji". In user-facing prose and section headings, say "Iru"; in code and URLs, leave the literal `kandji` strings alone.

## Critical - read this first

1. **Auth header uses `Bearer`.** The token is an opaque string (not a `pk_...` prefix like ClickUp). Header: `Authorization: Bearer <token>`. A raw token without `Bearer` returns 401.
2. **Base URL is region-specific and still uses the kandji.io hostname.**
   - US tenants: `https://<subdomain>.api.kandji.io`
   - EU tenants: `https://<subdomain>.api.eu.kandji.io`
   The `<subdomain>` is the tenant slug (e.g. `optable`). Find it in Iru under **Settings -> Access**.
3. **All endpoints are v1.** Paths are `/api/v1/...`. There is no v2/v3 split like ClickUp.
4. **Custom apps upload is a 3-step flow, not a single POST.** `POST /library/custom-apps/upload` returns an S3 pre-signed POST. Do the S3 upload yourself (noauth multipart), then `POST /library/custom-apps` with the returned `file_key`. See "Upload a custom app" below.
5. **Library items aren't assigned to blueprints on create.** Creating a custom script / custom app / custom profile just puts it in the Library. To make it deploy, call `POST /blueprints/{blueprint_id}/assign-library-item` with `{"library_item_id": "..."}` (plus `assignment_node_id` for Assignment Map blueprints).
6. **PATCH is partial, PUT is not used.** Update endpoints are always PATCH and only the fields you send are changed. Sending just `{"script": "..."}` to `/library/custom-scripts/{id}` is valid and leaves everything else untouched.
7. **Rate limit: 10,000 requests per hour per customer** (tenant-wide, not per token). Much more generous than ClickUp's per-minute limits, but bursty fleet-wide scripts can still hit it. On 429, back off; the docs don't document a reset header explicitly.
8. **Prism and List Devices paginate differently.** Device list is offset + `next`/`previous` URLs with `limit` up to 300. Prism endpoints return `{offset, limit, total, data}` with a `filter` JSON query param (see Prism filters below). Audit log uses `sort_by` + `next`/`previous`.
9. **Device action POSTs are fire-and-forget MDM commands.** A `200 OK` means the command was queued, not that it completed on the device. Most return minimal bodies (Lock returns `{"PIN": "..."}`; Erase returns PINs too; others are empty). Poll `GET /devices/{id}/status` or `/library/library-items/{id}/status` to verify.

## Step 1: Load config and token

Read `~/.config/api-skills/iru.yaml`. Expected shape:

```yaml
token_file: /absolute/path/to/iru-token
subdomain: optable                  # required; tenant slug from Iru "Settings > Access"
region: us                          # optional; "us" (default) or "eu"
default_blueprint_id: <uuid>        # optional; used when the user doesn't specify a blueprint
default_self_service_category_id: <uuid>  # optional; used for self-service library items
```

Read the token from `token_file`. Strip trailing whitespace. If empty or a placeholder (`REPLACE_ME`, `your_token_here`), stop and ask.

Build the base URL:
- `region: us` (default) -> `https://<subdomain>.api.kandji.io`
- `region: eu` -> `https://<subdomain>.api.eu.kandji.io`

All requests use:
```
Authorization: Bearer <token>
Content-Type: application/json        # omit for multipart file uploads; curl -F handles it
Accept: application/json
```

### First-time setup (new machine, new teammate)

If `~/.config/api-skills/iru.yaml` doesn't exist, stop and walk the user through this setup. The explicit `chmod`/`install -m` calls matter: `umask` defaults differ across machines, so don't rely on it.

1. **Generate a personal API token.** In Iru: **Settings -> Access -> API Token -> Add Token**. Select the permissions the user needs (tokens are scoped by feature area - grant only what's required). Copy the token string. Tokens do not expire by default but can be rotated; treat like a password.

2. **Find the API subdomain.** Still under **Settings -> Access**, Iru shows the API URL, e.g. `https://optable.api.kandji.io`. The subdomain is the part before `.api`.

3. **Create a locked-down secrets directory and the token file.**

   ```bash
   # Directory: owner-only rwx (0700)
   mkdir -p ~/.secrets
   chmod 700 ~/.secrets

   # Token file: create empty with owner-only rw (0600) BEFORE writing the secret
   install -m 600 /dev/null ~/.secrets/iru-token

   # Paste the token into the file with an editor, or:
   read -rs -p "Paste Iru token: " TOKEN && printf '%s\n' "$TOKEN" > ~/.secrets/iru-token && unset TOKEN
   ```

   Do NOT use `echo <token> > file` on the command line - it logs the secret into shell history.

4. **Create the skill config, also locked down.**

   ```bash
   mkdir -p ~/.config/api-skills
   chmod 700 ~/.config/api-skills
   install -m 600 /dev/null ~/.config/api-skills/iru.yaml
   $EDITOR ~/.config/api-skills/iru.yaml
   ```

   Put this inside (replace `<you>` and `<subdomain>` with real values):

   ```yaml
   token_file: /home/<you>/.secrets/iru-token   # absolute path; $HOME and ~ are NOT expanded
   subdomain: <subdomain>
   region: us
   ```

5. **Verify permissions.** Expected: directories `700`, files `600`, all owned by the user.

   ```bash
   stat -c '%a %U:%G %n' ~/.secrets ~/.secrets/iru-token ~/.config/api-skills ~/.config/api-skills/iru.yaml
   # macOS: stat -f '%Lp %Su:%Sg %N' <paths>
   ```

6. **Smoke test.** Should return `200` with a list of blueprints or devices.

   ```bash
   TOKEN=$(tr -d '[:space:]' < ~/.secrets/iru-token)
   SUB=$(sed -n 's/^subdomain:[[:space:]]*//p' ~/.config/api-skills/iru.yaml)
   curl -sS -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" \
     "https://$SUB.api.kandji.io/api/v1/blueprints"
   # expect: 200
   ```

   `401` = bad token or missing `Bearer ` prefix. `404` = wrong subdomain or wrong region. See Troubleshooting.

### Security notes (tell the user if they ask, or if you see a violation)

- **Never commit the token** (or `iru.yaml` with an embedded token) to any repo. The config uses a path POINTER to the token so the config itself is safe to sync.
- **Don't put the token in a shell env var in `.zshrc`/`.bashrc`.** Env vars leak through `/proc/<pid>/environ` and child-process inheritance. A 0600 file is stricter.
- **Don't paste the token as a `curl` argument** on the command line - it shows up in `ps` and shell history. Read it from the file inside a pipeline (see smoke test).
- **If the token leaks**: rotate immediately in **Settings -> Access -> API Token**, revoke the old one.
- **Token permissions are scoped.** If a call returns `403 Forbidden` on an endpoint that exists, the token likely lacks that permission - check the token's scope settings, don't retry with more auth.

## Step 2: Find the right endpoint

**Do not guess the endpoint.** The local mirror at `~/git/vendor-api-docs/kandji/` is authoritative. (The repo kept its old name on disk.)

Navigation:
- `references/endpoint-map.md` in this skill - "I want to do X" -> path to the matching endpoint doc. Read this first.
- `~/git/vendor-api-docs/kandji/docs/<category>/README.md` - each category has an index listing its endpoints (e.g. `library-items/`, `device-actions/`, `blueprints/`).
- `~/git/vendor-api-docs/kandji/docs/README.md` - top-level index with all 14 categories.
- `~/git/vendor-api-docs/kandji/collection.json` - the raw Postman collection, only if an endpoint isn't in the pretty docs.

Each endpoint doc is named `<verb>-<slug>.md` (e.g. `post-create-custom-script.md`, `patch-update-custom-script.md`) and includes: method, URL, parameters, request body schema, response schema. Read the exact endpoint doc before composing a request.

## Step 3: Draft and confirm

Before any POST / PATCH / DELETE, show the request to the user and get explicit approval. GETs can run without confirmation unless a destructive follow-up is implied. Device-action POSTs (Lock, Erase, Restart, Shutdown, Delete Device) are VERY destructive - always confirm the target device ID with the user before sending, even if they asked. Never retry silently on error - surface the response body verbatim.

## Step 4: Send the request

Use `curl` via Bash. Read the token into a variable first so it doesn't end up in `ps`/history:

```bash
TOKEN=$(tr -d '[:space:]' < ~/.secrets/iru-token)
SUB=optable   # or pull from config
```

GET:
```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://$SUB.api.kandji.io/api/v1/devices?limit=300"
```

POST / PATCH with JSON body (HEREDOC keeps quoting sane):
```bash
curl -sS -X PATCH "https://$SUB.api.kandji.io/api/v1/library/custom-scripts/$ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "execution_frequency": "every_day",
  "active": true
}
JSON
```

**For PATCH with a large file as the value of a JSON field** (e.g. updating the `script` body of a custom script), use `jq --rawfile` to JSON-encode the file safely. Shell heredocs break on embedded backticks, quotes, and `$` in scripts:

```bash
jq -n --rawfile s scripts/claude-vertex.sh '{script: $s}' | \
  curl -sS -X PATCH "https://$SUB.api.kandji.io/api/v1/library/custom-scripts/$ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data-binary @-
```

Multipart file upload (custom profiles, in-house apps post-to-endpoint, not the S3 flow for custom apps):
```bash
curl -sS -X POST "https://$SUB.api.kandji.io/api/v1/library/custom-profiles" \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Wi-Fi Config" \
  -F "file=@/path/to/profile.mobileconfig" \
  -F "runs_on_mac=true"
```

## Step 5: Verify

- Resource-creating POSTs return `201 Created` + the full resource JSON (including `id`). Report the `id` so the user can reference it.
- PATCH returns `200 OK` + updated resource. Before reporting "done", re-GET the resource and compare `updated_at` (or hash the relevant field) to confirm the change landed. Useful when pushing script bodies - see the "Push local script to Iru library" workflow below.
- Device action POSTs return `200 OK` with minimal body. The MDM command has been queued, not executed. If the user asked to verify the command ran, poll `GET /devices/{device_id}/status` after a reasonable wait.
- DELETE returns `204 No Content`.

Error shape is usually a JSON object with a message string, sometimes a bare string, sometimes a list of strings (e.g. blueprint validation errors). Surface verbatim.

Common status codes (from the API README):
- `400` - Bad Request. Includes "Command already running" (MDM command already pending), "Command is not allowed for current device" (incompatible with platform), or JSON parse errors.
- `401` - token wrong, revoked, or expired, or missing `Bearer ` prefix.
- `403` - token lacks the required permission scope.
- `404` - resource not found, OR wrong subdomain/region for the URL.
- `415` - Unsupported Media Type. Usually a missing `Content-Type: application/json` header on a POST with JSON body.
- `429` - rate limit (10,000/hour/customer). Back off.
- `500/503` - transient. `503` can also mean a custom app is still being processed server-side after S3 upload; retry after a few seconds.

## Common workflows

### List and filter devices
Endpoint: `GET /devices` (`docs/device-information/get-list-devices.md`). Hard cap 300 results per request; use `next`/`previous` URLs in the response for pagination.

Useful query params (check the endpoint doc for the full list):
- `limit` (max 300)
- `blueprint_id`, `platform` (`Mac`, `iPhone`, `iPad`, `AppleTV`, `Android`, `Windows`)
- `serial_number`, `asset_tag`, `user_email`, `user_id`
- `os_version`, `mdm_enabled`, `agent_installed`, `is_missing`, `is_removed`, `tag`

Example - find a Mac by serial:
```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://$SUB.api.kandji.io/api/v1/devices?serial_number=FVHHFKF7Q6L4"
```

Device ID is the `device_id` UUID in the response. Use it for actions, status lookups, and secrets.

### Push local script to Iru library (update an existing custom script)
This is the most common workflow for this repo. Endpoint: `PATCH /library/custom-scripts/{library_item_id}` (`docs/library-items/custom-scripts/patch-update-custom-script.md`).

1. Find the library item ID. Either the user has it, or list scripts and match by name:
   ```bash
   curl -sS -H "Authorization: Bearer $TOKEN" \
     "https://$SUB.api.kandji.io/api/v1/library/custom-scripts" \
     | jq -r '.results[] | "\(.id)  \(.name)"'
   ```
2. Save upstream script locally first for diffing/rollback (don't skip this step unless the user says so):
   ```bash
   curl -sS -H "Authorization: Bearer $TOKEN" \
     "https://$SUB.api.kandji.io/api/v1/library/custom-scripts/$ID" \
     | jq -r '.script' > /tmp/iru-<name>.before.sh
   ```
3. Show the diff against the local file so the user can sanity-check.
4. PATCH with the new body:
   ```bash
   jq -n --rawfile s scripts/<name>.sh '{script: $s}' | \
     curl -sS -X PATCH "https://$SUB.api.kandji.io/api/v1/library/custom-scripts/$ID" \
       -H "Authorization: Bearer $TOKEN" \
       -H "Content-Type: application/json" \
       --data-binary @-
   ```
5. Verify by re-GETting and comparing `sha256sum`:
   ```bash
   curl -sS -H "Authorization: Bearer $TOKEN" \
     "https://$SUB.api.kandji.io/api/v1/library/custom-scripts/$ID" \
     | jq -r '.script' > /tmp/iru-<name>.after.sh
   sha256sum /tmp/iru-<name>.after.sh scripts/<name>.sh
   ```

Other PATCHable custom-script fields: `name`, `execution_frequency` (`once` | `every_15_min` | `every_day` | `no_enforcement`), `remediation_script`, `show_in_self_service`, `self_service_category_id`, `self_service_recommended`, `active`, `restart`.

### Create a new custom script
`POST /library/custom-scripts` (`docs/library-items/custom-scripts/post-create-custom-script.md`). Body:
```json
{
  "name": "my_new_script",
  "execution_frequency": "every_day",
  "script": "#!/bin/bash\nset -euo pipefail\n...",
  "remediation_script": "",
  "active": true,
  "restart": false,
  "show_in_self_service": false
}
```
Response includes the new `id`. To make it actually deploy to devices, assign it to a blueprint (see next workflow).

### Assign a library item to a blueprint
Library items (custom scripts, apps, profiles) don't deploy until they're on a blueprint. `POST /blueprints/{blueprint_id}/assign-library-item` (`docs/blueprints/post-assign-library-item.md`).

```json
{
  "library_item_id": "<uuid>",
  "assignment_node_id": "<node_uuid>"   // omit for classic blueprints; required for Assignment Maps with conditional logic
}
```

- **Classic blueprint:** omit `assignment_node_id`. If you send it on a classic blueprint the API returns 400 "`assignment_node_id` cannot be provided for Classic Blueprint".
- **Assignment Map blueprint:** `assignment_node_id` is required if the map has conditional logic. To find it, open the map in the Iru web UI and hold Option (macOS) to reveal node IDs. Each node ID is stable for the lifespan of that node.
- **Already assigned:** returns 400 "Library Item already exists on Blueprint" / "Library Item already exists in Assignment Node". Safe to treat as idempotent if you're re-running.

Remove with `POST /blueprints/{blueprint_id}/remove-library-item` (same body shape).

### Upload a custom app (3-step S3 flow)
Not a single POST. Sequence:

1. Reserve S3 slot: `POST /library/custom-apps/upload` with `{"name": "myapp.pkg"}`. Returns `post_url`, `post_data`, and `file_key`.
2. Upload to S3: `POST` multipart to `post_url` (noauth - it's a pre-signed S3 URL). The form fields are the `post_data` object, plus `file=@/local/path/myapp.pkg`. Must be sent in field order with `file` last (S3 requirement).
   ```bash
   curl -sS -X POST "$POST_URL" \
     $(jq -r 'to_entries[] | "-F \(.key)=\(.value)"' <<<"$POST_DATA" | xargs) \
     -F "file=@/path/to/myapp.pkg"
   ```
   Expect `204 No Content`.
3. Register in Iru: `POST /library/custom-apps` with the `file_key` from step 1, plus `name`, `install_type` (`package` | `zip` | `image`), `install_enforcement` (`install_once` | `continuously_enforce` | `no_enforcement`), and optional scripts / self-service flags. Returns the Library item.
4. Assign to a blueprint (previous workflow) so it deploys.

If step 3 returns 503, the file is still being processed in S3. Retry after a few seconds.

### Create a custom profile
`POST /library/custom-profiles` (`docs/library-items/custom-profiles/post-create-custom-profile.md`). This is multipart/form-data, NOT JSON - the .mobileconfig is uploaded as a file part:
```bash
curl -sS -X POST "https://$SUB.api.kandji.io/api/v1/library/custom-profiles" \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Wi-Fi Config" \
  -F "file=@/path/to/profile.mobileconfig" \
  -F "active=true" \
  -F "runs_on_mac=true"
```

### Run a device action (Lock, Restart, Erase, ...)
`POST /devices/{device_id}/action/<action>`. See `docs/device-actions/README.md` for the full list (21 actions).

```bash
curl -sS -X POST "https://$SUB.api.kandji.io/api/v1/devices/$DEV/action/lock" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"Message": "Lost device, please return.", "PhoneNumber": "+15145550100"}'
```

Some actions accept a body (lock message, set-name, update-inventory), most don't. Check the endpoint doc. **Always** double-confirm the `device_id` before sending Erase, Delete Device, or Lock - these are destructive and some are irreversible (Erase wipes the Mac).

### Get device secrets (FileVault key, unlock PIN, activation-lock bypass)
`docs/device-secrets/`. Pattern: `GET /devices/{device_id}/secrets/<secret_type>`. Returns `null` if the secret isn't available for that device. These endpoints require a token with the appropriate secret-read permission scope; expect 403 otherwise.

### Query Prism (structured device inventory)
Prism gives normalized, filterable data across the fleet. All endpoints under `docs/prism/`. Example categories: `device_information`, `applications`, `filevault`, `certificates`, `installed_profiles`, `local_users`, `launch_agents_and_daemons`, `application_firewall`, `cellular`, `activation_lock`, `gatekeeper_and_xprotect`, `kernel_extensions`, `system_extensions`, `transparency_database`, `startup_settings`, `desktop_and_screensaver`.

```bash
# All Apple Silicon Macs running on OS < 14
FILTER='{"apple_silicon":{"eq":true},"os_version":{"lt":"14"}}'
curl -sS -G -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "filter=$FILTER" \
  "https://$SUB.api.kandji.io/api/v1/prism/device_information"
```

Filter operators: `eq`, `in`, `not_in`, `like`, `not_like`, `lt`, `gt`, `lte`, `gte`, `or`. See `docs/prism/README.md` for examples. Response shape: `{offset, limit, total, data}`. Paginate with `offset` + `limit` (default limit 25).

Long-running exports: `POST /prism/<category>/export` starts a CSV export, `GET /prism/exports/{export_id}` polls for the ready URL.

### Tags (on devices)
`docs/tags/`. CRUD on tag definitions: `GET/POST/PATCH/DELETE /tags[/{tag_id}]`. To add a tag TO a device, update the device itself: `PATCH /devices/{device_id}` with the tag list (see `docs/device-information/patch-update-device.md`).

### List library item deployment status across the fleet
`GET /library/library-items/{library_item_id}/status` (`docs/library-items/get-get-library-item-statuses.md`). Returns per-device status (`PENDING`, `PASS`, `FAIL`, etc.) with `log` and `last_audit_run` fields. Useful to verify a custom script is actually running on devices after a PATCH.

### Blueprints (list, assign, remove)
- `GET /blueprints` - list all blueprints (classic + map).
- `GET /blueprints/{id}` - one blueprint (structure varies for classic vs map).
- `GET /blueprints/{id}/list-library-items` - which library items are on this blueprint.
- `POST /blueprints` - create (name, enrollment_code, type=classic|map; see `docs/blueprints/post-create-blueprint.md` for color/icon codes).
- `POST /blueprints/{id}/assign-library-item` / `POST /blueprints/{id}/remove-library-item` - see workflow above.

### Audit log
`GET /audit/events?limit=500&sort_by=-occurred_at` (`docs/audit-log/get-list-audit-events.md`). Events cover blueprint / library item / device / user / admin CUD plus security feature events (vuln mgmt, EDR). Response uses `next`/`previous` URLs for pagination.

### Threats (EDR) and Vulnerabilities
Feature-gated - only available if the tenant has EDR / Vulnerability Management. Endpoints under `docs/threats/` and `docs/vulnerabilities/`. Read-only (list/get); no POST/PATCH.

## Troubleshooting

### 401 Unauthorized
Wrong token, expired token, or missing `Bearer ` prefix in the Authorization header (a raw token without `Bearer ` returns 401 - this is the opposite of ClickUp). Verify the token file, confirm the header is `Authorization: Bearer <token>`, and regenerate at Iru **Settings -> Access** if in doubt.

### 403 Forbidden on an endpoint that exists
The token lacks the permission scope for that endpoint (Iru tokens are scoped by feature area). Fix in **Settings -> Access -> API Token -> [edit token permissions]**. Don't retry the same call hoping for different results.

### 404 on a clearly-correct path
Wrong subdomain or wrong region. Test: open `https://<sub>.api.kandji.io/api/v1/blueprints` in a browser while logged into Iru - if the UI shows EU data but you used the US hostname, swap to `<sub>.api.eu.kandji.io`. Also check the resource ID - 404s on `/devices/{id}` usually mean the device ID is from another tenant or has been deleted.

### 415 Unsupported Media Type
Missing or wrong `Content-Type`. For JSON bodies set `Content-Type: application/json`. For multipart uploads let `curl -F` set it (don't manually set `Content-Type: application/json` then use `-F`).

### 400 "Command already running"
MDM command of the same type is already queued for that device. Wait for it to complete (check `GET /devices/{id}/status`) or cancel it via the web UI.

### 400 "Command is not allowed for current device"
The action doesn't apply to the device's platform (e.g. "Reset Work Profile Passcode" on a Mac, "Clear Passcode" on Android without a passcode set). Check the device's `platform` field and the action's compatibility in its endpoint doc.

### 400 "Library Item already exists on Blueprint"
Idempotent case of assigning a library item twice. Safe to ignore if you're re-running a deploy script.

### 503 on custom app register
After the S3 upload, the file is still being processed server-side. Retry after 3-10 seconds.

### Custom script runs on devices but shows "FAIL" in status
The script exited non-zero. `GET /library/library-items/{script_id}/status` returns per-device `log` which contains the stdout/stderr from the last run. Inspect `log` before assuming the Iru wiring is wrong.

### Rate-limited (429)
10,000 requests/hour/customer. Back off for a minute or two. The API doesn't expose a documented reset header; don't burst.

### `updated_at` didn't change after PATCH
Check whether the field you PATCHed actually differed from the current value. Iru accepts no-op PATCHes with 200 but may not bump `updated_at`. Compare the script body hash instead, as in the "Push local script" workflow.

## Examples

### List all active custom scripts with their IDs
User: "list iru custom scripts"
1. Read config + token.
2. `GET /library/custom-scripts`.
3. Summarize as `id  [active|inactive]  frequency  name`.

### Push updated local script to the library
User: "push scripts/policy-pnpm.sh to iru"
1. Look up the library item ID (match by name in `GET /library/custom-scripts` or use one the user provides).
2. Download upstream: save `.script` field to `/tmp/iru-<name>.before.sh`.
3. Show diff vs local; user approves.
4. `jq -n --rawfile s scripts/policy-pnpm.sh '{script: $s}' | curl -X PATCH ...`.
5. Re-GET, hash, confirm match; report `updated_at`.

### Lock a lost Mac
User: "lock iru device FVHHFKF7Q6L4 with a message"
1. Resolve serial -> `device_id`: `GET /devices?serial_number=FVHHFKF7Q6L4`.
2. Confirm device details (name, user email) with the user.
3. User confirms -> `POST /devices/$DEV/action/lock` with `{"Message": "...", "PhoneNumber": "..."}`.
4. Report the returned `PIN` (six digits, used to unlock the Mac).

### Find all Macs on an old macOS
User: "which iru devices are still on macOS 13"
1. Use Prism for clean filtering: `GET /prism/device_information?filter={"os_version":{"like":["13."]},"device__family":{"in":["Mac"]}}`.
2. Summarize as `name - user - os_version - serial - last_check_in`.
3. Offer to export CSV via `POST /prism/device_information/export`.

### Get FileVault recovery key
User: "get the filevault key for device <uuid>"
1. `GET /devices/$DEV/secrets/filevault_key`.
2. Report the key. If `null`, the device hasn't escrowed one - flag to the user.

### Create and assign a new custom script in one flow
User: "create a new iru script called 'foo check' and assign to blueprint <id>"
1. Draft script body + frequency with the user.
2. `POST /library/custom-scripts` -> capture the new `id`.
3. `POST /blueprints/<bp_id>/assign-library-item` with `{"library_item_id": "<new_id>"}`.
4. Report both IDs.

## References

- `references/endpoint-map.md` - "I want to do X" -> endpoint doc path lookup across all 14 categories.
- `~/git/vendor-api-docs/kandji/docs/README.md` - top-level index (repo kept the old name).
- `~/git/vendor-api-docs/kandji/docs/<category>/README.md` - per-category endpoint indexes.
- `~/git/vendor-api-docs/kandji/collection.json` - raw Postman collection (fallback for anything not in the pretty docs).
- API token management: Iru web UI **Settings -> Access -> API Token**.
- Iru / Kandji API portal (external): https://support.kandji.io/api.
- Blueprint color codes: https://github.com/kandji-inc/support/wiki/Blueprint-API---Color-Codes.
- Blueprint icon codes: https://github.com/kandji-inc/support/wiki/Blueprint-API-Icon-Codes.
- Pagination example scripts from Iru Support: https://github.com/kandji-inc/support/tree/main/api-tools/code-examples.
