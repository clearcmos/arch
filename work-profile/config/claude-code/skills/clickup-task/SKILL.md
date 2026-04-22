---
name: clickup-task
description: Creates tasks in ClickUp via the v2 API. Use when the user says "create clickup task", "open a clickup ticket", "make a clickup task in list <id>", "file a task on CU list <id>", or asks to open a new ticket/task in ClickUp. Reads the API token from ~/.config/clickup-task/config.yaml, uses `markdown_content` for rich descriptions (not `description`, which is plain-only), and requires a list ID to post into. Does NOT post comments -- that is the clickup-comment skill.
---

# ClickUp Task

Create a new task on a ClickUp list via the v2 API.

## Critical -- read this first

**Use `markdown_content` for rich descriptions, NOT `description`.**

The ClickUp OpenAPI spec (mirrored at `~/git/vendor-api-docs/clickup/docs/api-v2/tasks/post-v2-list-list_id-task.md`) documents both fields. `description` is plain text -- markdown syntax renders literally. `markdown_content` renders as real markdown (headings, lists, code, links, bold). If both are sent, `markdown_content` wins.

Rule of thumb: if the body has any `**`, `#`, backticks, lists, or links, use `markdown_content`.

Unlike comments, task bodies do NOT use the Quill Delta array format. Just a markdown string.

## Instructions

### Step 1: Load config and token

Read `~/.config/clickup-task/config.yaml`. Expected shape:

```yaml
token_file: /absolute/path/to/clickup-token
default_list_id: 901234567890   # optional; used when the user doesn't specify a list
```

If the file doesn't exist, stop and tell the user to:
1. Create `~/.config/clickup-task/config.yaml`
2. Set `token_file:` to the absolute path of a file containing their ClickUp personal API token (get one at https://app.clickup.com/settings/apps)
3. Optionally set `default_list_id:` to a numeric list ID they use most often

A user who already has `~/.config/clickup-comment/config.yaml` can point `token_file:` at the same underlying token file -- the skills are independent by design, but nothing stops sharing the token.

Read the token from `token_file`. Strip trailing whitespace. If empty or obviously a placeholder, stop and ask.

### Step 2: Identify the list

Tasks are created on a list, not a workspace. You need a numeric `list_id`.

In order of preference:
1. The user gave a list ID directly (`901234567890`) -- use it.
2. The user gave a list URL (`https://app.clickup.com/{team}/v/li/{list_id}` or `.../l/{list_id}`) -- extract the segment after `/li/` or `/l/`.
3. `default_list_id` is set in config and the user didn't specify -- confirm with the user before using it ("Using default list `901234567890` -- OK?").
4. None of the above -- ask for the list ID or URL. Do not guess.

### Step 3: Draft the task

Based on session context (what the user just did, what bug they're describing, what TODO they want filed), draft:

- **name** (required, short -- one line, no trailing period)
- **markdown_content** (optional body; use markdown if there's any structure)
- **priority** (optional; 1 Urgent, 2 High, 3 Normal, 4 Low -- omit unless the user said so or it's clearly justified)
- **tags** (optional array of strings; only if the user asked or the list uses a known tag convention you can see from context)
- **assignees** (optional array of ClickUp user IDs; omit unless given)
- **due_date** (optional unix ms; with `due_date_time: true` if a specific time was given, else `false` for date-only)
- **status** (optional; only set if the user specified one -- list defaults apply otherwise)

Show the draft to the user for approval. Do NOT post without an explicit go-ahead.

### Step 4: Post

Endpoint: `POST https://api.clickup.com/api/v2/list/{list_id}/task`

Headers:
```
Authorization: <token>        # raw token, NO "Bearer" prefix
Content-Type: application/json
```

Body (only `name` is required):
```json
{
  "name": "Short task title",
  "markdown_content": "## Context\n\nWhat happened, linked to [PR #42](https://...).\n\n## Steps to reproduce\n\n1. Do X\n2. Observe Y",
  "priority": 3,
  "tags": ["bug"],
  "notify_all": false
}
```

Use `curl` via Bash. A HEREDOC keeps the JSON readable:

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

### Step 5: Verify

A successful response returns the full task object, including:
- `id` -- the task ID (e.g. `86abc123`)
- `url` -- the web URL to the task

Report both to the user so they can click through. If you get an error (e.g. `{"err": "...", "ECODE": "..."}`), surface it verbatim -- don't retry silently.

## Optional fields worth knowing

From `~/git/vendor-api-docs/clickup/docs/api-v2/tasks/post-v2-list-list_id-task.md`:

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | **Required.** |
| `markdown_content` | string | Rich body. Wins over `description` when both are sent. |
| `description` | string | Plain-text body. Use only if you explicitly don't want markdown. |
| `priority` | 1..4 \| null | 1 Urgent, 2 High, 3 Normal, 4 Low. Null = no priority. |
| `status` | string | Must match a status name on the target list. |
| `tags` | string[] | Must match existing tag names on the space. |
| `assignees` | integer[] | ClickUp user IDs, not emails. |
| `group_assignees` | string[] | For team/group assignees. |
| `due_date` / `start_date` | integer | Unix milliseconds. |
| `due_date_time` / `start_date_time` | boolean | True = includes a time, false = date-only. |
| `parent` | string \| null | Existing task ID -- makes this a subtask. Parent must be on the same list. |
| `links_to` | string \| null | Existing task ID -- creates a linked-dependency relationship. |
| `custom_fields` | object[] | `[{id, value}, ...]`. IDs come from `GET /v2/list/{list_id}/field`. |
| `custom_item_id` | number | For non-standard task types (0 = standard "Task"). |
| `check_required_custom_fields` | boolean | Default false; set true to enforce required custom fields. |
| `notify_all` | boolean | Notify the creator too. Default false. |

For anything beyond this, read the local OpenAPI-derived doc directly -- it's authoritative.

## Examples

### Example 1: Quick bug ticket, plain
User says: "create a clickup task on list 901234567890: checkout button broken on mobile"
1. Read config + token
2. Propose body: `{"name": "Checkout button broken on mobile", "notify_all": false}`
3. User confirms -> POST
4. Report returned `id` and `url`

### Example 2: Rich ticket with context and a repro
User says: "open a clickup ticket summarizing the bug we just debugged, throw it on my default list"
1. Read config + token; confirm default list with the user
2. Draft with `markdown_content`: a short context paragraph, a bulleted repro, a link to the failing CI run
3. Show draft; user approves
4. POST
5. Report `id` and `url`

### Example 3: Subtask
User says: "create a subtask under 86xyz999 called 'write migration test'"
1. Read config + token
2. The parent task is `86xyz999`; the subtask must be on the same list, so look up the parent's list first via `GET /api/v2/task/86xyz999` and take `.list.id` for the POST URL
3. Post with `"parent": "86xyz999"` and `"name": "Write migration test"`
4. Report `id` and `url`

## Troubleshooting

### Markdown appears literally
Cause: used `description` with markdown syntax. `description` is plain-text only.
Solution: update the task and move content to `markdown_content`:
```
PUT /api/v2/task/{task_id}
{"markdown_content": "...", "description": ""}
```

### 400 "List not found" / "Invalid list ID"
Cause: wrong list ID, or the list is in a workspace the token can't access.
Solution: open the list in the browser, copy the numeric segment after `/li/` or `/l/` in the URL. Personal tokens see only the workspaces the user has access to.

### 401 Unauthorized
Cause: wrong `token_file` path, empty token, or revoked token. Same as clickup-comment.
Solution: verify `token_file` in config, check the file has a valid token (watch for stray leading whitespace -- the skill strips trailing whitespace only). Regenerate at https://app.clickup.com/settings/apps if unsure.

### "Status not found"
Cause: `status` string doesn't match any status on the list. Statuses are list- or space-level, case-sensitive.
Solution: omit `status` to use the list default, or fetch valid statuses via `GET /v2/list/{list_id}` -> `.statuses[].status`.

### "Tag does not exist"
Cause: tags must already exist on the space. Creating a task does not create tags.
Solution: create the tag in the ClickUp UI (or via `POST /v2/space/{space_id}/tag`), then retry. Or omit tags.

### Assignee ID confusion
Cause: `assignees` wants numeric user IDs, not emails or usernames.
Solution: fetch members via `GET /v2/team/{team_id}/member` and use the numeric `user.id`.

## References

- ClickUp API reference (local mirror, OpenAPI-derived): `~/git/vendor-api-docs/clickup`
- Create Task endpoint doc: `~/git/vendor-api-docs/clickup/docs/api-v2/tasks/post-v2-list-list_id-task.md`
- Personal token management: https://app.clickup.com/settings/apps
- Sibling skill for posting comments on existing tasks: `clickup-comment`
