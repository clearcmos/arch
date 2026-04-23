# Iru Endpoint Map

Task-oriented index from user intent to endpoint doc path. All paths are relative to `~/git/vendor-api-docs/kandji/docs/`. Open the listed file and Read it before composing a request - each endpoint doc has the full parameter list, body schema, and response schema.

All endpoints are v1. Base URL: `https://<subdomain>.api.kandji.io/api/v1/...` (US) or `https://<subdomain>.api.eu.kandji.io/api/v1/...` (EU). Auth: `Authorization: Bearer <token>`.

Naming scheme: `<verb>-<slug>.md`. The slug is a human-readable name ("create-custom-script"), NOT the URL path, which differs from the ClickUp docs' scheme.

## Devices - information

| Intent | Method | Path | File |
|---|---|---|---|
| List devices (up to 300/page) | GET | `/devices` | `device-information/get-list-devices.md` |
| Get one device (summary) | GET | `/devices/{device_id}` | `device-information/get-get-device.md` |
| Get full device details | GET | `/devices/{device_id}/details` | `device-information/get-get-device-details.md` |
| Update device (asset_tag, user, blueprint, tags) | PATCH | `/devices/{device_id}` | `device-information/patch-update-device.md` |
| Get device apps | GET | `/devices/{device_id}/apps` | `device-information/get-get-device-apps.md` |
| Get device activity log | GET | `/devices/{device_id}/activity` | `device-information/get-get-device-activity.md` |
| Get device library items + status | GET | `/devices/{device_id}/library-items` | `device-information/get-get-device-library-items.md` |
| Get device parameters | GET | `/devices/{device_id}/parameters` | `device-information/get-get-device-parameters.md` |
| Get device MDM command status | GET | `/devices/{device_id}/status` | `device-information/get-get-device-status.md` |
| Get Lost Mode details | GET | `/devices/{device_id}/lost-mode` | `device-information/get-get-device-lost-mode-details.md` |
| Cancel Lost Mode | DELETE | `/devices/{device_id}/lost-mode` | `device-information/delete-cancel-lost-mode.md` |

### Device notes (subcategory)

| Intent | Method | Path | File |
|---|---|---|---|
| List notes on a device | GET | `/devices/{device_id}/notes` | `device-information/notes/get-get-device-notes.md` |
| Get one note | GET | `/devices/{device_id}/notes/{note_id}` | `device-information/notes/get-retrieve-device-note.md` |
| Create a note | POST | `/devices/{device_id}/notes` | `device-information/notes/post-create-device-note.md` |
| Update a note | PATCH | `/devices/{device_id}/notes/{note_id}` | `device-information/notes/patch-update-device-note.md` |
| Delete a note | DELETE | `/devices/{device_id}/notes/{note_id}` | `device-information/notes/delete-delete-device-note.md` |

## Devices - actions

All POST. Command is queued as MDM; 200 response means queued, not completed. Verify with `GET /devices/{device_id}/status`. See `device-actions/README.md` for the full action list.

| Intent | Method | Path | File |
|---|---|---|---|
| Lock device (Mac returns unlock PIN) | POST | `/devices/{device_id}/action/lock` | `device-actions/post-lock-device.md` |
| Erase device | POST | `/devices/{device_id}/action/erase` | `device-actions/post-erase-device.md` |
| Restart device | POST | `/devices/{device_id}/action/restart` | `device-actions/post-restart-device.md` |
| Shutdown device | POST | `/devices/{device_id}/action/shutdown` | `device-actions/post-shutdown.md` |
| Clear passcode | POST | `/devices/{device_id}/action/clearpasscode` | `device-actions/post-clear-passcode.md` |
| Reset work profile passcode | POST | `/devices/{device_id}/action/reset-work-profile-passcode` | `device-actions/post-reset-work-profile-passcode.md` |
| Unlock account | POST | `/devices/{device_id}/action/unlockaccount` | `device-actions/post-unlock-account.md` |
| Update inventory | POST | `/devices/{device_id}/action/updateinventory` | `device-actions/post-update-inventory.md` |
| Perform daily check-in | POST | `/devices/{device_id}/action/check-in` | `device-actions/post-perform-daily-check-in.md` |
| Renew MDM profile | POST | `/devices/{device_id}/action/renewmdmprofile` | `device-actions/post-renew-mdm-profile.md` |
| Reinstall Iru agent | POST | `/devices/{device_id}/action/reinstallagent` | `device-actions/post-reinstall-agent.md` |
| Send blank APNs push | POST | `/devices/{device_id}/action/blankpush` | `device-actions/post-send-blankpush.md` |
| Set device name | POST | `/devices/{device_id}/action/setname` | `device-actions/post-set-name.md` |
| Enable remote desktop (Mac) | POST | `/devices/{device_id}/action/remotedesktop` | `device-actions/post-remote-desktop.md` |
| Set personal hotspot (iPhone) | POST | `/devices/{device_id}/action/sethotspot` | `device-actions/post-set-personal-hotspot.md` |
| Set data roaming (iPhone/iPad) | POST | `/devices/{device_id}/action/setdataroaming` | `device-actions/post-set-data-roaming.md` |
| Refresh eSIM | POST | `/devices/{device_id}/action/refreshesim` | `device-actions/post-refresh-esim.md` |
| Delete device user account | POST | `/devices/{device_id}/action/delete-user` | `device-actions/post-delete-user.md` |
| Delete device from Iru | DELETE | `/devices/{device_id}` | `device-actions/delete-delete-device.md` |
| List queued/past commands | GET | `/devices/{device_id}/commands` | `device-actions/get-get-device-commands.md` |

### Lost Mode (subcategory - iOS/iPadOS)

| Intent | Method | Path | File |
|---|---|---|---|
| Enable Lost Mode | POST | `/devices/{device_id}/action/enable-lost-mode` | `device-actions/lost-mode/post-enable-lost-mode.md` |
| Disable Lost Mode | POST | `/devices/{device_id}/action/disable-lost-mode` | `device-actions/lost-mode/post-disable-lost-mode.md` |
| Play Lost Mode sound | POST | `/devices/{device_id}/action/play-lost-mode-sound` | `device-actions/lost-mode/post-play-lost-mode-sound.md` |
| Update location | POST | `/devices/{device_id}/action/update-location` | `device-actions/lost-mode/post-update-location.md` |

## Device secrets

All GET. Require secret-read permission on the token. Return `null` if secret unavailable.

| Intent | Method | Path | File |
|---|---|---|---|
| FileVault recovery key (Mac) | GET | `/devices/{device_id}/secrets/filevaultkey` | `device-secrets/get-get-filevault-recovery-key.md` |
| Recovery Lock password (Apple Silicon Mac) | GET | `/devices/{device_id}/secrets/recoverylockpassword` | `device-secrets/get-get-recovery-lock-password.md` |
| Unlock PIN (Mac) | GET | `/devices/{device_id}/secrets/unlockpin` | `device-secrets/get-get-unlock-pin.md` |
| Activation Lock bypass code (Mac) | GET | `/devices/{device_id}/secrets/bypasscode` | `device-secrets/get-get-activation-lock-bypass-code.md` |

## Blueprints

| Intent | Method | Path | File |
|---|---|---|---|
| List blueprints | GET | `/blueprints` | `blueprints/get-list-blueprints.md` |
| Get one blueprint | GET | `/blueprints/{blueprint_id}` | `blueprints/get-get-blueprint.md` |
| Create blueprint (classic or map) | POST | `/blueprints` | `blueprints/post-create-blueprint.md` |
| Update blueprint | PATCH | `/blueprints/{blueprint_id}` | `blueprints/patch-update-blueprint.md` |
| Delete blueprint | DELETE | `/blueprints/{blueprint_id}` | `blueprints/delete-delete-blueprint.md` |
| List library items on blueprint | GET | `/blueprints/{blueprint_id}/list-library-items` | `blueprints/get-list-library-items.md` |
| Assign library item to blueprint | POST | `/blueprints/{blueprint_id}/assign-library-item` | `blueprints/post-assign-library-item.md` |
| Remove library item from blueprint | POST | `/blueprints/{blueprint_id}/remove-library-item` | `blueprints/post-remove-library-item.md` |
| Get blueprint templates catalog | GET | `/blueprint-templates` | `blueprints/get-get-blueprint-templates.md` |
| Get manual enrollment profile | GET | `/blueprints/{blueprint_id}/enrollment-profile` | `blueprints/get-get-manual-enrollment-profile.md` |

## Blueprint Routing (conditional auto-assignment at ADE enrollment)

| Intent | Method | Path | File |
|---|---|---|---|
| Get current routing config | GET | `/blueprint-routing` | `blueprint-routing/get-get-blueprint-routing.md` |
| Update routing config | PATCH | `/blueprint-routing` | `blueprint-routing/patch-update-blueprint-routing.md` |
| Get routing activity log | GET | `/blueprint-routing/activity` | `blueprint-routing/get-get-blueprint-routing-activity.md` |

## Library items - shared

| Intent | Method | Path | File |
|---|---|---|---|
| Get library item activity | GET | `/library/library-items/{library_item_id}/activity` | `library-items/get-get-library-item-activity.md` |
| Get per-device statuses | GET | `/library/library-items/{library_item_id}/status` | `library-items/get-get-library-item-statuses.md` |

## Library items - custom scripts

| Intent | Method | Path | File |
|---|---|---|---|
| List custom scripts | GET | `/library/custom-scripts` | `library-items/custom-scripts/get-list-custom-scripts.md` |
| Get one custom script | GET | `/library/custom-scripts/{library_item_id}` | `library-items/custom-scripts/get-get-custom-script.md` |
| Create custom script | POST | `/library/custom-scripts` | `library-items/custom-scripts/post-create-custom-script.md` |
| Update custom script (partial) | PATCH | `/library/custom-scripts/{library_item_id}` | `library-items/custom-scripts/patch-update-custom-script.md` |
| Delete custom script | DELETE | `/library/custom-scripts/{library_item_id}` | `library-items/custom-scripts/delete-delete-custom-script.md` |

Frequency values: `once`, `every_15_min`, `every_day`, `no_enforcement`.

## Library items - custom profiles (.mobileconfig)

Create and update take multipart/form-data, not JSON.

| Intent | Method | Path | File |
|---|---|---|---|
| List custom profiles | GET | `/library/custom-profiles` | `library-items/custom-profiles/get-list-custom-profiles.md` |
| Get one profile | GET | `/library/custom-profiles/{library_item_id}` | `library-items/custom-profiles/get-get-custom-profile.md` |
| Create profile (multipart) | POST | `/library/custom-profiles` | `library-items/custom-profiles/post-create-custom-profile.md` |
| Update profile (multipart) | PATCH | `/library/custom-profiles/{library_item_id}` | `library-items/custom-profiles/patch-update-custom-profile.md` |
| Delete profile | DELETE | `/library/custom-profiles/{library_item_id}` | `library-items/custom-profiles/delete-delete-custom-profile.md` |

## Library items - custom apps (3-step S3 upload flow)

Sequence for new app: (1) reserve -> (2) upload to S3 -> (3) register in Iru.

| Intent | Method | Path | File |
|---|---|---|---|
| Reserve S3 slot (get presigned POST) | POST | `/library/custom-apps/upload` | `library-items/custom-apps/post-upload-custom-app.md` |
| Upload to S3 (noauth, multipart) | POST | `{post_url}` returned from step 1 | `library-items/custom-apps/post-upload-to-s3.md` |
| Register in Iru using `file_key` | POST | `/library/custom-apps` | `library-items/custom-apps/post-create-custom-app.md` |
| List custom apps | GET | `/library/custom-apps` | `library-items/custom-apps/get-list-custom-apps.md` |
| Get one custom app | GET | `/library/custom-apps/{library_item_id}` | `library-items/custom-apps/get-get-custom-app.md` |
| Update custom app | PATCH | `/library/custom-apps/{library_item_id}` | `library-items/custom-apps/patch-update-custom-app.md` |
| Delete custom app | DELETE | `/library/custom-apps/{library_item_id}` | `library-items/custom-apps/delete-delete-custom-app.md` |

`install_type`: `package`, `zip`, `image`. `install_enforcement`: `install_once`, `continuously_enforce`, `no_enforcement`.

## Library items - in-house apps (Apple Business Manager-adjacent flow)

Similar S3 flow to custom apps. See `library-items/in-house-apps/README.md`.

| Intent | Method | Path | File |
|---|---|---|---|
| List in-house apps | GET | `/library/in-house-apps` | `library-items/in-house-apps/get-list-in-house-apps.md` |
| Get one in-house app | GET | `/library/in-house-apps/{library_item_id}` | `library-items/in-house-apps/get-get-in-house-app.md` |
| Reserve S3 slot | POST | `/library/in-house-apps/upload` | `library-items/in-house-apps/post-upload-in-house-app-to-s3.md` |
| Upload to S3 | POST | `{post_url}` | `library-items/in-house-apps/post-upload-in-house-app.md` |
| Register in Iru | POST | `/library/in-house-apps` | `library-items/in-house-apps/post-create-in-house-app.md` |
| Poll upload processing status | GET | `/library/in-house-apps/{library_item_id}/upload-status` | `library-items/in-house-apps/get-upload-in-house-app-status.md` |
| Update in-house app | PATCH | `/library/in-house-apps/{library_item_id}` | `library-items/in-house-apps/patch-update-in-house-app.md` |
| Delete in-house app | DELETE | `/library/in-house-apps/{library_item_id}` | `library-items/in-house-apps/delete-delete-in-house-app.md` |

## Library items - Self Service

| Intent | Method | Path | File |
|---|---|---|---|
| List Self Service categories (get category IDs) | GET | `/self-service/categories` | `library-items/self-service/get-list-self-service-categories.md` |

Use the returned `id` in `self_service_category_id` when creating/updating a library item with `show_in_self_service: true`.

## Tags

| Intent | Method | Path | File |
|---|---|---|---|
| List tags | GET | `/tags` | `tags/get-get-tags.md` |
| Create tag | POST | `/tags` | `tags/post-create-tag.md` |
| Update tag | PATCH | `/tags/{tag_id}` | `tags/patch-update-tag.md` |
| Delete tag | DELETE | `/tags/{tag_id}` | `tags/delete-delete-tag.md` |

To add/remove tags ON a device, use `PATCH /devices/{device_id}` with the `tags` array (`device-information/patch-update-device.md`), not these endpoints.

## Users (directory users, not admin users)

| Intent | Method | Path | File |
|---|---|---|---|
| List users | GET | `/users` | `users/get-list-users.md` |
| Get one user | GET | `/users/{user_id}` | `users/get-get-user.md` |
| Delete user | DELETE | `/users/{user_id}` | `users/delete-delete-user.md` |

## Automated Device Enrollment (ADE) integrations

| Intent | Method | Path | File |
|---|---|---|---|
| Download ADE public key (for Apple Business Manager setup) | GET | `/integrations/ade/public-key` | `automated-device-enrollment-integrations/get-download-ade-public-key.md` |
| Create ADE integration (upload ABM token) | POST | `/integrations/ade` | `automated-device-enrollment-integrations/post-create-ade-integration.md` |
| List ADE integrations | GET | `/integrations/ade` | `automated-device-enrollment-integrations/get-list-ade-integrations.md` |
| Get one ADE integration | GET | `/integrations/ade/{integration_id}` | `automated-device-enrollment-integrations/get-get-ade-integration.md` |
| Renew ADE integration | POST | `/integrations/ade/{integration_id}/renew` | `automated-device-enrollment-integrations/post-renew-ade-integration.md` |
| Update ADE integration | PATCH | `/integrations/ade/{integration_id}` | `automated-device-enrollment-integrations/patch-update-ade-integration.md` |
| Delete ADE integration | DELETE | `/integrations/ade/{integration_id}` | `automated-device-enrollment-integrations/delete-delete-ade-integration.md` |
| List devices assigned to ADE token | GET | `/integrations/ade/{integration_id}/devices` | `automated-device-enrollment-integrations/get-list-devices-associated-to-ade-token.md` |
| List ADE devices (all integrations) | GET | `/integrations/ade/devices` | `automated-device-enrollment-integrations/get-list-ade-devices.md` |
| Get one ADE device | GET | `/integrations/ade/devices/{ade_device_id}` | `automated-device-enrollment-integrations/get-get-ade-device.md` |
| Update ADE device (assign blueprint, tags, asset_tag) | PATCH | `/integrations/ade/devices/{ade_device_id}` | `automated-device-enrollment-integrations/patch-update-ade-device.md` |

## Prism (structured fleet inventory, filterable)

All GET, all support `?filter=<JSON>` with operators `eq`, `in`, `not_in`, `like`, `not_like`, `lt`, `gt`, `lte`, `gte`, `or`. See `prism/README.md` for filter examples. Response shape: `{offset, limit, total, data}`.

| Intent | Method | Path | File |
|---|---|---|---|
| Device information (primary inventory) | GET | `/prism/device_information` | `prism/get-device-information.md` |
| Installed applications | GET | `/prism/applications` | `prism/get-applications.md` |
| FileVault status | GET | `/prism/filevault` | `prism/get-filevault.md` |
| Installed profiles | GET | `/prism/installed_profiles` | `prism/get-installed-profiles.md` |
| Local users | GET | `/prism/local_users` | `prism/get-local-users.md` |
| Certificates | GET | `/prism/certificates` | `prism/get-certificates.md` |
| Activation Lock | GET | `/prism/activation_lock` | `prism/get-activation-lock.md` |
| Application firewall | GET | `/prism/application_firewall` | `prism/get-application-firewall.md` |
| Gatekeeper & XProtect | GET | `/prism/gatekeeper_and_xprotect` | `prism/get-gatekeeper-and-xprotect.md` |
| Kernel extensions | GET | `/prism/kernel_extensions` | `prism/get-kernel-extensions.md` |
| System extensions | GET | `/prism/system_extensions` | `prism/get-system-extensions.md` |
| Launch agents and daemons | GET | `/prism/launch_agents_and_daemons` | `prism/get-launch-agents-and-daemons.md` |
| Transparency (TCC) database | GET | `/prism/transparency_database` | `prism/get-transparency-database.md` |
| Startup settings | GET | `/prism/startup_settings` | `prism/get-startup-settings.md` |
| Desktop & screensaver | GET | `/prism/desktop_and_screensaver` | `prism/get-desktop-and-screensaver.md` |
| Cellular | GET | `/prism/cellular` | `prism/get-cellular.md` |
| Row count for category | GET | `/prism/{category}/count` | `prism/get-count.md` |
| Start CSV export | POST | `/prism/{category}/export` | `prism/post-request-category-export.md` |
| Poll / fetch export | GET | `/prism/exports/{export_id}` | `prism/get-get-category-export.md` |

## Threats (EDR - feature-gated)

| Intent | Method | Path | File |
|---|---|---|---|
| Get threat details | GET | `/threats/{threat_id}` | `threats/get-get-threat-details.md` |
| Get threat details (v2) | GET | `/v2/threats/{threat_id}` | `threats/get-get-threat-details-v2.md` |
| Get behavioral detections | GET | `/threats/behavioral-detections` | `threats/get-get-behavioral-detections.md` |
| Get behavioral detections (v2) | GET | `/v2/threats/behavioral-detections` | `threats/get-get-behavioral-detections-v2.md` |

## Vulnerabilities (feature-gated)

| Intent | Method | Path | File |
|---|---|---|---|
| List detections | GET | `/vulnerabilities/detections` | `vulnerabilities/get-list-detections.md` |
| List vulnerabilities | GET | `/vulnerabilities` | `vulnerabilities/get-list-vulnerabilities.md` |
| Get vulnerability description (CVE) | GET | `/vulnerabilities/{cve_id}` | `vulnerabilities/get-get-vulnerability-description.md` |
| List devices affected by a CVE | GET | `/vulnerabilities/{cve_id}/affected-devices` | `vulnerabilities/get-list-affected-devices.md` |
| List software affected by a CVE | GET | `/vulnerabilities/{cve_id}/affected-software` | `vulnerabilities/get-list-affected-software.md` |

## Audit log

| Intent | Method | Path | File |
|---|---|---|---|
| List audit events (paginated) | GET | `/audit/events` | `audit-log/get-list-audit-events.md` |

Useful query params: `limit` (max 500), `sort_by` (e.g. `-occurred_at` for newest first), `next`/`previous` URLs in response. Filterable by `action`, `actor_type`, `target_type`, `target_component`, date range.

## Settings

| Intent | Method | Path | File |
|---|---|---|---|
| Get licensing info (seat counts, plan) | GET | `/settings/licensing` | `settings/get-licensing.md` |

## If you can't find it here

1. Check the category README: `docs/<category>/README.md`.
2. Search the top-level index: `docs/README.md`.
3. Search the raw Postman collection: `~/git/vendor-api-docs/kandji/collection.json` (has every request; grep for a URL fragment or name).
