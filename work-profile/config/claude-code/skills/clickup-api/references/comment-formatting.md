# ClickUp Comment Formatting (Quill Delta)

Rich comment bodies on ClickUp use the `comment` array field, not `comment_text`. Each array entry is a **Quill Delta** segment: `{"text": "...", "attributes": {...}}`. Segments are concatenated in order; newlines go inside `text` as `\n`. This format is not in the OpenAPI mirror - it comes from https://developer.clickup.com/docs/comment-formatting and the GET-comments response shape.

The tell that this field is real: `GET /v2/task/{task_id}/comment` returns each comment with both a `comment` array (the structured form) and a `comment_text` (the flattened plain-string form). If you see the array come back, the field is valid to send.

## Endpoints that accept the `comment` array

All of these take the same body shape (`comment` array OR `comment_text`, plus `notify_all`):

- `POST /v2/task/{task_id}/comment` - comment on a task.
- `POST /v2/list/{list_id}/comment` - list-level comment.
- `POST /v2/view/{view_id}/comment` - comment on a chat-style view.
- `POST /v2/comment/{comment_id}/reply` - threaded reply on a comment.
- `PUT /v2/comment/{comment_id}` - edit an existing comment (same body).

## Request body shape

Plain text (no formatting):
```json
{
  "comment_text": "Migration is merged.",
  "notify_all": false
}
```

Rich (any formatting at all):
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

Do not set both `comment` and `comment_text` at once. Pick one.

## Supported attributes

Inline (attach to a segment of text, anywhere inside a line):

| Attribute | Value | Effect |
|-----------|-------|--------|
| `bold` | `true` | **bold** |
| `italic` | `true` | *italic* |
| `underline` | `true` | underline |
| `strike` | `true` | strikethrough |
| `code` | `true` | inline `code` |
| `link` | URL string | clickable link on this segment |

Inline attributes apply to the whole `text` of a segment. To mix formatted and plain text on one line, split into multiple segments.

Block (attach to a segment whose `text` ENDS WITH `\n`; the attribute applies to the whole line):

| Attribute | Value | Effect |
|-----------|-------|--------|
| `header` | `1`, `2`, or `3` | H1 / H2 / H3 heading for that line |
| `list` | `"bullet"` or `"ordered"` | bulleted or numbered list item |
| `code-block` | `true` | fenced-code-block line |

For multi-line code blocks, add one `{"text": "line\n", "attributes": {"code-block": true}}` segment per line, or one segment whose `text` contains multiple lines each terminated by `\n`.

## Common patterns

### Mixing bold into a sentence
```json
[
  {"text": "Deployed "},
  {"text": "v1.4.2", "attributes": {"bold": true}},
  {"text": " to production."}
]
```

### Bulleted list
Each bullet is its own segment ending in `\n` with `list: "bullet"`:
```json
[
  {"text": "Changes:\n", "attributes": {"header": 3}},
  {"text": "Fixed checkout button.\n", "attributes": {"list": "bullet"}},
  {"text": "Added retry logic.\n", "attributes": {"list": "bullet"}},
  {"text": "Bumped timeout to 30s.\n", "attributes": {"list": "bullet"}}
]
```

### Numbered list
Same as bulleted, `"list": "ordered"`.

### Heading followed by paragraph
```json
[
  {"text": "Summary\n", "attributes": {"header": 2}},
  {"text": "The migration completed cleanly. No rollback needed."}
]
```

### Link inside a sentence
```json
[
  {"text": "See "},
  {"text": "PR #42", "attributes": {"link": "https://github.com/org/repo/pull/42"}},
  {"text": " for details."}
]
```

### Inline code
```json
[
  {"text": "Call "},
  {"text": "GET /v2/user", "attributes": {"code": true}},
  {"text": " to get the current user."}
]
```

### Fenced code block
Each line of the block is a segment ending in `\n` with `code-block: true`:
```json
[
  {"text": "Here's the fix:\n"},
  {"text": "if (!user) throw new Error('missing');\n", "attributes": {"code-block": true}},
  {"text": "return user;\n", "attributes": {"code-block": true}}
]
```

## Pitfalls

1. **Attributes apply to the whole segment.** If you want `bold` on two words inside a longer sentence, split into three segments (before, bold, after).
2. **Block attributes require the segment to end in `\n`.** A `list: "bullet"` segment without a trailing newline will render with no bullet marker.
3. **Don't send both `comment` and `comment_text`.** If both are present, behavior is implementation-defined - some paths use one, some the other.
4. **Probe first for anything unusual.** Post a one-line test (`"test - verifying format"`) before a 2KB comment. Deleting broken comments is extra friction.
5. **The OpenAPI spec only documents `comment_text`.** Do not assume the spec is complete - the array field is real despite its absence.
6. **`notify_all` is required** on POST according to the spec. Usually you want `false` to avoid spamming watchers.

## Fetching existing comments

`GET /v2/task/{task_id}/comment` returns:
```json
{
  "comments": [
    {
      "id": "...",
      "comment": [ {"text": "...", "attributes": {...}}, ... ],
      "comment_text": "flat plaintext version",
      "user": {...},
      "date": "...",
      ...
    }
  ]
}
```

Use `comment_text` when you just want to read the content; use `comment` when re-posting a reply that preserves the original formatting.

## Deleting a broken comment

`DELETE /v2/comment/{comment_id}` with the same auth header. No body.
