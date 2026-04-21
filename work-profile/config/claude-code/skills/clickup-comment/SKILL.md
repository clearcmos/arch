---
name: clickup-comment
description: Posts comments to ClickUp tasks via the ClickUp v2 API using the rich `comment` array (Quill Delta) format so bold, code, and links actually render. Use when the user says "post clickup comment", "write clickup comment", "comment on clickup task", "drop a comment on CU-<id>", or asks to leave a status update/summary on a ClickUp ticket. Reads the API token from a user-configured path in ~/.config/clickup-comment/config.yaml, probes long comments with a short test first, and avoids the common `comment_text` pitfall (plain-string field that renders markdown literally).
---

# ClickUp Comment

Post a comment to a ClickUp task via the v2 API, using the rich `comment` array format so formatting actually renders.

## Critical — read this first

**Use the `comment` array field, NOT `comment_text`.**

The ClickUp OpenAPI spec (mirrored at `~/git/vendor-api-docs/clickup`) documents `comment_text` as a plain string. `comment_text` does NOT render markdown — what you send is what users see, literally. `**bold**` will appear as `**bold**`.

To get formatting (bold, italic, code, links, lists, headings), use the `comment` array field — a list of Quill Delta segments. It's real and actively used by ClickUp's own web editor, but it lives on a separate developer-docs page not included in the OpenAPI mirror:

- https://developer.clickup.com/docs/comment-formatting

The tell that this field exists: the GET-comments response in the local OpenAPI spec returns both `comment` (array) and `comment_text` (flattened string). If you see that mismatch, it means rich format is real — don't ignore it.

**Also: don't assume markdown support in any API. Verify before posting 2 KB of content.**

## Instructions

### Step 1: Load config and token

Read `~/.config/clickup-comment/config.yaml`. Expected shape:

```yaml
token_file: /absolute/path/to/clickup-token
```

If the file doesn't exist, stop and tell the user to:
1. Create `~/.config/clickup-comment/config.yaml`
2. Set `token_file:` to the absolute path of a file containing their ClickUp personal API token (get one at https://app.clickup.com/settings/apps)

Read the token from `token_file`. Strip trailing whitespace. If empty or obviously a placeholder, stop and ask.

### Step 2: Identify the task

If the user named a task ID (e.g. `86abc123` or a URL like `https://app.clickup.com/t/86abc123`), extract the raw ID — the segment after `/t/`. Otherwise ask for it.

### Step 3: Draft the comment

Based on the current session context (what the user just did, what file they're asking you to summarize, etc.), draft the comment body. Show it to the user for approval. Do NOT post without an explicit go-ahead.

### Step 4: Choose the format field

- **Plain text only, no formatting needed** → use `comment_text`
- **Any formatting** (bold, italic, code, links, bullets, headings) → use the `comment` array

If in doubt, use `comment`. It works for plain text too (just omit `attributes`).

### Step 5: Probe long or unfamiliar rich content first

If the comment is longer than ~500 chars OR uses a format pattern you haven't verified in this session, post a one-line probe first (e.g. `"test — verifying format"`) and ask the user to check the rendering before posting the full content. Ten seconds of verification beats a 2 KB broken post that has to be deleted.

### Step 6: Post

Endpoint: `POST https://api.clickup.com/api/v2/task/{task_id}/comment`

Headers:
```
Authorization: <token>        # raw token, NO "Bearer" prefix
Content-Type: application/json
```

Plain body:
```json
{
  "comment_text": "your plain text here",
  "notify_all": false
}
```

Rich body — each segment is `{text, attributes?}`; segments concatenate in order; use `\n` inside `text` for newlines:
```json
{
  "comment": [
    {"text": "Status: ", "attributes": {"bold": true}},
    {"text": "shipped\n\n"},
    {"text": "See "},
    {"text": "PR #42", "attributes": {"link": "https://github.com/org/repo/pull/42"}},
    {"text": " for details."}
  ],
  "notify_all": false
}
```

Known Quill Delta attributes that ClickUp renders:
- `bold`, `italic`, `underline`, `strike` — booleans
- `code` — inline code, boolean
- `code-block` — fenced block, boolean (apply to the whole segment incl. trailing `\n`)
- `link` — URL string
- `list` — `"bullet"` or `"ordered"` (applied to a segment ending in `\n` to mark that line as a list item)
- `header` — `1`, `2`, or `3` (applied to a segment ending in `\n`)

For anything beyond this, consult https://developer.clickup.com/docs/comment-formatting.

Use `curl` via Bash. A HEREDOC keeps the JSON readable and avoids shell-quoting headaches:

```bash
curl -sS -X POST "https://api.clickup.com/api/v2/task/$TASK_ID/comment" \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "comment": [
    {"text": "hello", "attributes": {"bold": true}}
  ],
  "notify_all": false
}
JSON
```

### Step 7: Verify

A successful response looks like `{"id": "...", "hist_id": "...", "date": ...}`. If you get an error (e.g. `{"err": "...", "ECODE": "..."}`), surface it verbatim — don't retry silently.

## Examples

### Example 1: Short plain status
User says: "post clickup comment on 86abc123 saying the migration is merged"
1. Read config + token
2. Propose body: `{"comment_text": "Migration is merged.", "notify_all": false}`
3. User confirms → POST
4. Report the returned comment ID

### Example 2: Rich multi-part summary
User says: "write a clickup comment summarizing what we did on CU-xyz456"
1. Read config + token
2. Draft with `comment` array: bold header, bullet list of changes, link to the PR
3. Show draft; user approves
4. Content is >500 chars → post probe `"test — verifying format"` first
5. User confirms rendering looks right
6. POST the full comment
7. (Optionally) suggest deleting the probe via the ClickUp UI

## Troubleshooting

### Markdown appears literally (`**bold**` shown as asterisks)
Cause: used `comment_text` with markdown syntax. `comment_text` is plain-text only.
Solution: re-post using the `comment` array with Quill Delta segments. Delete the broken comment from the ClickUp UI, or via `DELETE /api/v2/comment/{comment_id}`.

### 401 Unauthorized
Cause: wrong `token_file` path, empty token, or revoked token.
Solution: verify `token_file` in config, check the file has a valid token (no stray whitespace on a new line can trip things — the skill strips trailing whitespace, but leading characters may not be stripped). Regenerate at https://app.clickup.com/settings/apps if unsure.

### Task not found / 404
Cause: wrong task ID, or token doesn't have access to that workspace.
Solution: the ID is the segment after `/t/` in the task URL. Confirm by opening the task in the browser while signed in with the same account the token belongs to.

### Single long segment looks unformatted
Cause: attributes apply to the whole `text` of a segment. Mixing plain and formatted text requires splitting into multiple segments.
Solution: break the string into multiple `{text, attributes}` entries — one per formatting run.

## References

- ClickUp API reference (local mirror, OpenAPI-derived): `~/git/vendor-api-docs/clickup`
- Comment formatting (NOT in the OpenAPI spec): https://developer.clickup.com/docs/comment-formatting
- Personal token management: https://app.clickup.com/settings/apps
