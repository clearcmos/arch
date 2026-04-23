---
name: clickup-api
description: Call any ClickUp REST API endpoint (v2 or v3) using a personal API token. Use when the user says "create clickup task", "open a clickup ticket", "post clickup comment", "comment on CU-<id>", "update clickup task", "add clickup tag", "start clickup time tracking", "find clickup list/folder/space", "upload attachment to clickup", "search clickup tasks", "add custom field value on clickup", or otherwise asks to read, create, update, or delete anything in ClickUp. Reads the token from ~/.config/api-skills/clickup.yaml. For task bodies use `markdown_content` (not plain-text `description`); for comments use the rich `comment` array (Quill Delta) not `comment_text`. Full endpoint reference lives at ~/git/vendor-api-docs/clickup/.
---

# ClickUp API

Call the ClickUp v2 or v3 REST API with a personal API token. Supersedes the old `clickup-task`, `clickup-comment`, and `clickup-personal` skills.

## Critical - read this first

1. **Auth header is raw token, no `Bearer` prefix.** Personal tokens start with `pk_`. Header: `Authorization: pk_...`.
2. **Task bodies: use `markdown_content`, NOT `description`.** `description` is plain text - markdown syntax renders literally. If both are sent, `markdown_content` wins.
3. **Comments: use the `comment` array (Quill Delta), NOT `comment_text`.** `comment_text` is plain text; `**bold**` appears literally. The `comment` array is real and used by ClickUp's web editor, but is not documented in the OpenAPI spec - see `references/comment-formatting.md`.
4. **v2 "Team" = v3 "Workspace".** Same thing, different name. v2 uses `/v2/team/{team_id}/...`; v3 uses `/api/v3/workspaces/{workspace_id}/...`. Both use the same numeric ID.
5. **Don't assume markdown support in any API.** Probe long/unfamiliar rich content with a short test first (see Branch B below).
6. **Rate limits are per token, per minute.** 100/min on Free/Unlimited/Business, 1000/min on Business Plus, 10000/min on Enterprise. On 429 the response has `X-RateLimit-Reset` (unix seconds).

## Step 1: Load config and token

Read `~/.config/api-skills/clickup.yaml`. Expected shape:

```yaml
token_file: /absolute/path/to/clickup-token
default_list_id: 901234567890   # optional; used for task creation when the user doesn't specify a list
default_team_id: 12345678       # optional; the workspace/team ID (same number in v2 and v3)
```

Read the token from `token_file`. Strip trailing whitespace. If empty or obviously a placeholder (`pk_your_token_here`, `REPLACE_ME`, etc.), stop and ask.

All requests use:
```
Authorization: <token>        # raw token, NO "Bearer" prefix
Content-Type: application/json
```

Base URL: `https://api.clickup.com` - v2 paths are `/api/v2/...`, v3 paths are `/api/v3/...`. OAuth access tokens (from 3rd-party app flow) DO use `Authorization: Bearer <access_token>` - but that's only if the user is building an OAuth app, which is rare for personal use.

### First-time setup (new machine, new teammate)

If `~/.config/api-skills/clickup.yaml` doesn't exist, stop and walk the user through this setup. Run the commands verbatim - they are chosen so the token file is never group/world-readable regardless of the user's `umask`. Works on Linux and macOS.

1. **Generate a personal API token.** In ClickUp: avatar -> Settings -> Apps -> API Token -> Generate (or go to https://app.clickup.com/settings/apps). Copy the `pk_...` string. Tokens never expire; treat them like a password.

2. **Create a locked-down secrets directory and the token file.** The explicit `chmod` calls matter: `umask` defaults differ across machines, so don't rely on it.

   ```bash
   # Directory: owner-only rwx (0700)
   mkdir -p ~/.secrets
   chmod 700 ~/.secrets

   # Token file: create empty with owner-only rw (0600) BEFORE writing the secret
   install -m 600 /dev/null ~/.secrets/clickup-token

   # Paste the pk_... token into the file with an editor, or:
   read -rs -p "Paste ClickUp token: " TOKEN && printf '%s\n' "$TOKEN" > ~/.secrets/clickup-token && unset TOKEN
   ```

   `install -m 600 /dev/null <path>` atomically creates (or truncates) the file with mode 600. `read -rs` keeps the token off the screen and out of shell history on most shells. Do NOT use `echo pk_xyz > file` on the command line - that logs the secret into your shell history.

3. **Create the skill config, also locked down.**

   ```bash
   mkdir -p ~/.config/api-skills
   chmod 700 ~/.config/api-skills
   install -m 600 /dev/null ~/.config/api-skills/clickup.yaml
   $EDITOR ~/.config/api-skills/clickup.yaml
   ```

   Put this inside (replace the workspace/list IDs with the user's own if they want defaults; both are optional):

   ```yaml
   token_file: /home/<you>/.secrets/clickup-token   # use absolute path; $HOME and ~ are NOT expanded
   default_list_id: 901234567890
   default_team_id: 12345678
   ```

4. **Verify permissions.** Expected: directories `700`, files `600`, all owned by the user.

   ```bash
   stat -c '%a %U:%G %n' ~/.secrets ~/.secrets/clickup-token ~/.config/api-skills ~/.config/api-skills/clickup.yaml
   # macOS: stat -f '%Lp %Su:%Sg %N' <paths>
   ```

   If any mode is wider than expected, rerun the matching `chmod`.

5. **Smoke test.** Should return the authorized user as JSON; the exit status is 0 on success.

   ```bash
   TOKEN=$(tr -d '[:space:]' < ~/.secrets/clickup-token)
   curl -sS -o /dev/null -w '%{http_code}\n' -H "Authorization: $TOKEN" https://api.clickup.com/api/v2/user
   # expect: 200
   ```

   A `401` means the token is wrong, empty, or has a stray `Bearer ` prefix. See Troubleshooting.

### Security notes (tell the user if they ask, or if you see a violation)

- **Never commit the token** (or `config.yaml` with an embedded token) to any repo. The config uses a path POINTER to the token so the config itself is safe to sync - the secret never lives in it.
- **Don't put the token in a shell env var in `.zshrc`/`.bashrc`.** Env vars leak through `/proc/<pid>/environ` (readable by the same user's other processes) and through child-process inheritance. A 0600 file is stricter.
- **Don't paste the token as a `curl` argument** on the command line - it shows up in `ps` output and shell history. Read it from the file inside a pipeline, as in the smoke test above.
- **If the token leaks** (committed, shared, screenshotted, pasted into the wrong tool): rotate immediately at https://app.clickup.com/settings/apps -> Regenerate. The old token becomes invalid the moment a new one is generated.
- **If 1Password CLI is set up** (see `~/arch/CLAUDE.md` in the config repo), a stricter alternative is to keep the token in 1Password and materialize it at login to `~/.secrets/clickup-token` - e.g. a systemd user service or a shell-profile line that runs `op read "op://Private/ClickUp/token" > ~/.secrets/clickup-token && chmod 600 ~/.secrets/clickup-token`. The skill always reads `token_file` as a plain file, so the materialization step is outside the skill. Not required; the plain-file flow above is already fine on a personal workstation.
- **Backups of `~/.secrets/` should be encrypted** (the arch repo does this via `age -p`). If the user's backup tool copies home plaintext, the token goes with it.

## Step 2: Find the right endpoint

**Do not guess the endpoint.** The local mirror at `~/git/vendor-api-docs/clickup/` is authoritative and includes request/response schemas for every endpoint.

Navigation:
- `references/endpoint-map.md` in this skill - "I want to do X" -> path to the matching endpoint doc. Read this first when you don't already know the exact endpoint.
- `~/git/vendor-api-docs/clickup/docs/api-v2/<category>/README.md` - each v2 category has an index listing its endpoints.
- `~/git/vendor-api-docs/clickup/docs/api-v3/<category>/README.md` - same for v3.
- `~/git/vendor-api-docs/clickup/docs/guides/` - prose guides (auth, webhooks, rate limits, v2/v3 terminology, custom fields, webhooks, MCP).
- `~/git/vendor-api-docs/clickup/openapi-v2.json` and `openapi-v3.yaml` - raw specs, only needed if an endpoint isn't in the pretty docs.

Each endpoint doc is named `<verb>-<path>.md` (e.g. `post-v2-list-list_id-task.md`) and includes: method, URL, all parameters with types, request body schema, response schema. Read the exact endpoint doc before composing a request.

**v2 vs v3:** Prefer v3 where it exists (attachments, comments replies, tasks home list, docs, chat, ACLs). v2 covers everything else. When both exist, the doc usually notes which is preferred.

## Step 3: Draft and confirm

Before any POST / PUT / DELETE / PATCH, show the request to the user and get explicit approval. GETs can run without confirmation unless the user asked for a destructive follow-up. Never retry silently on error - surface the error body verbatim.

## Step 4: Send the request

Use `curl` via Bash with a HEREDOC so JSON stays readable and shell escaping doesn't bite:

```bash
curl -sS -X POST "https://api.clickup.com/api/v2/list/$LIST_ID/task" \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "name": "Short task title",
  "markdown_content": "## Context\n\n...",
  "priority": 3,
  "notify_all": false
}
JSON
```

For GET, drop `-X` and `-d`:
```bash
curl -sS "https://api.clickup.com/api/v2/list/$LIST_ID?archived=false" \
  -H "Authorization: $TOKEN"
```

For file uploads (task attachments, v3 entity attachments) use `-F` multipart/form-data, not JSON:
```bash
curl -sS -X POST "https://api.clickup.com/api/v2/task/$TASK_ID/attachment" \
  -H "Authorization: $TOKEN" \
  -F "attachment=@/absolute/path/to/file.pdf"
```

**Don't pipe the token through echo/printf into logs.** Keep it in an env var.

## Step 5: Verify

Successful responses usually include the full resource (tasks: `id` + `url`; comments: `id`, `hist_id`, `date`). Report the `id` and any `url` so the user can click through.

Error shape: `{"err": "...", "ECODE": "..."}`. Surface verbatim. Common codes:
- `OAUTH_019` / `OAUTH_025` - 401 auth failure (see Troubleshooting).
- `TASK_013` - List or task not found / unauthorized for that workspace.
- `CREATE_TASK_001` / `CREATE_TASK_002` - validation error on task create; the `err` string names the bad field.
- `SUBCAT_008` - Status/tag not found on the target space.

## Common workflows

### Create a task
Endpoint: `POST /v2/list/{list_id}/task` (`docs/api-v2/tasks/post-v2-list-list_id-task.md`).

List resolution order:
1. User gave a list ID directly.
2. User gave a list URL (`https://app.clickup.com/{team}/v/li/{list_id}` or `.../l/{list_id}`) - extract the segment after `/li/` or `/l/`.
3. `default_list_id` from config - confirm with the user first ("Using default list `901234567890` - OK?").
4. Otherwise ask. Do not guess.

Minimum body: `{"name": "...", "notify_all": false}`. For rich bodies add `markdown_content`. Task bodies are a markdown STRING, not a Quill Delta array.

Useful optional fields (from the endpoint doc):
- `priority`: 1 Urgent, 2 High, 3 Normal, 4 Low, null none.
- `tags`: string array; tags must already exist on the space.
- `assignees`: integer array of ClickUp user IDs (not emails).
- `status`: string; must match a status on the list (case-sensitive).
- `due_date` / `start_date`: unix milliseconds; with matching `due_date_time` / `start_date_time` boolean.
- `parent`: task ID for a subtask; parent must be on the SAME list.
- `custom_fields`: `[{"id": "...", "value": ...}]`; look up field IDs via `GET /v2/list/{list_id}/field`.

### Update a task
`PUT /v2/task/{task_id}` (`docs/api-v2/tasks/put-v2-task-task_id.md`). Same fields as create; omit fields you don't want to change. To clear a markdown body: `{"markdown_content": "", "description": ""}`.

### Get tasks (filtering, pagination)
- Within one list: `GET /v2/list/{list_id}/task` - supports `archived`, `page`, `order_by`, `reverse`, `subtasks`, `statuses[]`, `include_closed`, `assignees[]`, etc.
- Across a workspace: `GET /v2/team/{team_id}/task` - wider filters including due-date ranges and custom-field filters.
- Pagination: `page=0`, `page=1`, ... until fewer than 100 tasks come back (default page size).

### Post a comment
`POST /v2/task/{task_id}/comment`. If formatting matters at all -> use the `comment` array. See `references/comment-formatting.md` for the full Quill Delta spec (attributes like `bold`, `italic`, `code-block`, `link`, `list`, `header`). Plain body:
```json
{"comment_text": "Migration is merged.", "notify_all": false}
```
Rich body:
```json
{
  "comment": [
    {"text": "Status: ", "attributes": {"bold": true}},
    {"text": "shipped\n\nSee "},
    {"text": "PR #42", "attributes": {"link": "https://github.com/org/repo/pull/42"}},
    {"text": " for details."}
  ],
  "notify_all": false
}
```

**Probe long/unfamiliar rich content first.** If the comment is longer than ~500 chars OR uses a Quill attribute you haven't verified in this session, post a one-line probe ("test - verifying format") and ask the user to check the rendering before sending the full payload. Ten seconds of verification beats deleting a 2KB broken post.

### Other comment endpoints
List comments: `POST /v2/list/{list_id}/comment`. View comments: `POST /v2/view/{view_id}/comment`. Threaded reply on a comment: `POST /v2/comment/{comment_id}/reply`. Update: `PUT /v2/comment/{comment_id}`. Delete: `DELETE /v2/comment/{comment_id}`.

### Workspace hierarchy (find a list you don't have an ID for)
Drill down: `GET /v2/team` (list workspaces) -> `GET /v2/team/{team_id}/space?archived=false` -> `GET /v2/space/{space_id}/folder?archived=false` -> `GET /v2/folder/{folder_id}/list?archived=false`. Folderless lists live at `GET /v2/space/{space_id}/list?archived=false`.

### Resolve a member by name or email
`GET /v2/team/{team_id}/member` returns `{members: [{user: {id, username, email}, ...}]}`. Match by `email` first (exact), then `username` (case-insensitive contains). Use the numeric `user.id` for `assignees` fields.

### Custom fields
- List a list's fields with their IDs: `GET /v2/list/{list_id}/field`.
- Set on create: include `{"custom_fields": [{"id": "...", "value": ...}]}` in the task POST body.
- Set/clear on existing task: `POST /v2/task/{task_id}/field/{field_id}` (set), `DELETE /v2/task/{task_id}/field/{field_id}` (clear).
- Value shape depends on the field type (text string, number, date unix ms, dropdown uuid, labels array, etc.). Read `docs/guides/custom-fields/` or the endpoint doc for type specifics.

### Tags
- List tags on a space: `GET /v2/space/{space_id}/tag`.
- Tags must exist on the space before a task can use them. Create missing ones with `POST /v2/space/{space_id}/tag`.
- Add/remove on a task: `POST /v2/task/{task_id}/tag/{tag_name}` / `DELETE /v2/task/{task_id}/tag/{tag_name}`.

### Time tracking
Modern endpoints (`docs/api-v2/time-tracking/`):
- Start: `POST /v2/team/{team_id}/time_entries/start` with `{tid: "<task_id>"}`.
- Stop: `POST /v2/team/{team_id}/time_entries/stop`.
- Current: `GET /v2/team/{team_id}/time_entries/current`.
- Add manual entry: `POST /v2/team/{team_id}/time_entries` with `start`, `duration` (ms), `tid`.
- Query: `GET /v2/team/{team_id}/time_entries?start_date=...&end_date=...&assignee=...`.

### Attachments
- Task attachment (v2, multipart): `POST /v2/task/{task_id}/attachment` with `-F attachment=@/path/to/file`.
- Entity attachment (v3, also supports File-type custom fields): `POST /api/v3/workspaces/{workspace_id}/...`. See `docs/api-v3/attachments/`.

### Webhooks
Create: `POST /v2/team/{team_id}/webhook`. Events listed in `docs/guides/webhooks/`. Signature verification uses the webhook `secret` + HMAC-SHA256 of the raw body - see the guide before trusting payloads.

## Troubleshooting

### 401 Unauthorized (OAUTH_019 / OAUTH_025)
Wrong `token_file` path, empty token, revoked token, or accidental `Bearer ` prefix. Verify the path in the config, check the file has a valid `pk_...` token with no stray leading whitespace (the skill strips trailing only). Regenerate at https://app.clickup.com/settings/apps if in doubt.

### 404 or "not found" on list/task/folder
Personal tokens only see workspaces the user has access to. Open the resource in the browser under the same account. The task ID is the segment after `/t/`; the list ID is the numeric segment after `/li/` or `/l/`. For custom task IDs (e.g. `CU-abc123`), add `?custom_task_ids=true&team_id=<workspace_id>` to the request.

### Task markdown renders literally
Used `description` instead of `markdown_content`. Fix by `PUT /v2/task/{task_id}` with `{"markdown_content": "...", "description": ""}`.

### Comment markdown renders literally (`**bold**` shown as asterisks)
Used `comment_text` instead of the `comment` array. Re-post using Quill Delta segments; delete the broken comment via `DELETE /v2/comment/{comment_id}` or the UI.

### "Status not found" (CREATE_TASK / SUBCAT errors)
`status` string must match a status on the target list, case-sensitive. Omit to use list default, or fetch valid statuses via `GET /v2/list/{list_id}` -> `.statuses[].status`.

### "Tag does not exist"
Tags must pre-exist on the space. Create with `POST /v2/space/{space_id}/tag`, then retry. Or drop the tags field.

### Assignee ID confusion
`assignees` wants numeric user IDs, not emails or usernames. Fetch members via `GET /v2/team/{team_id}/member` and use `user.id`.

### Rate-limited (429)
Back off until `X-RateLimit-Reset` (unix seconds). Don't burst.

### Single long comment segment looks unformatted
Quill `attributes` apply to the whole `text` of a segment. Split into multiple `{text, attributes}` segments - one per formatting run.

### Custom task ID not resolving
Add `?custom_task_ids=true&team_id=<workspace_id>` to the URL. Without `team_id`, ClickUp can't disambiguate.

## Examples

### Quick plain-text bug task
User: "create a clickup task on list 901234567890: checkout button broken on mobile"
1. Read config + token.
2. Draft: `{"name": "Checkout button broken on mobile", "notify_all": false}`.
3. User confirms -> `POST /v2/list/901234567890/task`.
4. Report `id` and `url`.

### Rich task from conversation context
User: "open a clickup ticket summarizing the bug we just debugged, throw it on my default list"
1. Confirm default list.
2. Draft `markdown_content` with context paragraph + bulleted repro + link to failing CI run.
3. Show draft; user approves.
4. POST.
5. Report `id` and `url`.

### Subtask
User: "create a subtask under 86xyz999 called 'write migration test'"
1. Look up parent's list: `GET /v2/task/86xyz999` -> `.list.id`.
2. POST to that list with `"parent": "86xyz999"` and `"name": "Write migration test"`.
3. Report `id` and `url`.

### Rich multi-part comment
User: "write a clickup comment summarizing what we did on CU-xyz456"
1. Draft `comment` array: bold header, bullet list, PR link.
2. Show; user approves.
3. Length > 500 chars -> probe `"test - verifying format"` first.
4. User confirms rendering; post the full comment.
5. (Optional) suggest deleting the probe via UI.

### Start time tracking on a task
User: "start clickup time tracking on 86abc123"
1. Resolve team_id from config (`default_team_id`) or ask.
2. `POST /v2/team/$TEAM_ID/time_entries/start` with `{"tid": "86abc123"}`.
3. Report the returned entry `id`.

### Upload a screenshot attachment
User: "attach /tmp/screenshot.png to CU-abc123"
1. `curl -X POST .../task/86abc123/attachment -F attachment=@/tmp/screenshot.png -H "Authorization: $TOKEN"`.
2. Report the attachment URL from the response.

### Filter tasks across a workspace
User: "show me my open clickup tasks due this week"
1. Resolve team_id and user_id (`GET /v2/user` for the token's own id).
2. Compute this-week bounds in unix ms.
3. `GET /v2/team/$TEAM_ID/task?assignees[]=$UID&due_date_gt=$START&due_date_lt=$END&include_closed=false`.
4. Summarize the tasks (name, id, due, status, url).

## References

- `references/comment-formatting.md` - Quill Delta spec for comments (not in OpenAPI).
- `references/endpoint-map.md` - "I want to do X" -> endpoint doc path lookup.
- `~/git/vendor-api-docs/clickup/docs/api-v2/<category>/README.md` - v2 endpoint indexes.
- `~/git/vendor-api-docs/clickup/docs/api-v3/<category>/README.md` - v3 endpoint indexes.
- `~/git/vendor-api-docs/clickup/docs/guides/` - prose guides: authentication, rate limits, v2-vs-v3 terminology, webhooks, custom fields, MCP.
- `~/git/vendor-api-docs/clickup/openapi-v2.json` / `openapi-v3.yaml` - raw OpenAPI specs (fallback).
- Personal token management: https://app.clickup.com/settings/apps.
- Comment formatting upstream doc (source for Quill Delta details): https://developer.clickup.com/docs/comment-formatting.
