# ClickUp Endpoint Map

Task-oriented index from user intent to endpoint doc path. All paths are relative to `~/git/vendor-api-docs/clickup/docs/`. Open the listed file and Read it before composing a request - each endpoint doc has the full parameter list, body schema, and response schema.

Naming scheme: `<verb>-<path-with-underscores>.md`. v2 paths use `/v2/...`, v3 paths use `/api/v3/...`. v2 "team" and v3 "workspace" refer to the same entity with the same numeric ID.

Conventions below:
- `{team_id}` / `{workspace_id}` = workspace ID (same number in both versions).
- For custom task IDs like `CU-abc123`, add `?custom_task_ids=true&team_id={workspace_id}` to any task endpoint.

## Tasks

| Intent | Method | Path | File |
|---|---|---|---|
| Create a task on a list | POST | `/v2/list/{list_id}/task` | `api-v2/tasks/post-v2-list-list_id-task.md` |
| Get one task | GET | `/v2/task/{task_id}` | `api-v2/tasks/get-v2-task-task_id.md` |
| Update a task | PUT | `/v2/task/{task_id}` | `api-v2/tasks/put-v2-task-task_id.md` |
| Delete a task | DELETE | `/v2/task/{task_id}` | `api-v2/tasks/delete-v2-task-task_id.md` |
| List tasks in a list (paginated) | GET | `/v2/list/{list_id}/task` | `api-v2/tasks/get-v2-list-list_id-task.md` |
| Filter tasks across whole workspace | GET | `/v2/team/{team_id}/task` | `api-v2/tasks/get-v2-team-team_id-task.md` |
| Create a task from a template | POST | `/v2/list/{list_id}/taskTemplate/{template_id}` | `api-v2/tasks/post-v2-list-list_id-tasktemplate-template_id.md` |
| Merge two tasks | POST | `/v2/task/{task_id}/merge` | `api-v2/tasks/post-v2-task-task_id-merge.md` |
| Get time-in-status for one task | GET | `/v2/task/{task_id}/time_in_status` | `api-v2/tasks/get-v2-task-task_id-time_in_status.md` |
| Get time-in-status for many tasks | GET | `/v2/task/bulk_time_in_status/task_ids` | `api-v2/tasks/get-v2-task-bulk_time_in_status-task_ids.md` |
| Move task's home list (v3) | PUT | `/api/v3/workspaces/{workspace_id}/tasks/{task_id}/home_list/{list_id}` | `api-v3/tasks/put-api-v3-workspaces-workspace_id-tasks-task_id-home_list-list_id.md` |
| Set per-user time estimates (v3) | PUT/PATCH | `/api/v3/workspaces/{workspace_id}/tasks/{task_id}/time_estimates_by_user` | `api-v3/tasks/put-...` / `patch-...` |

## Comments

| Intent | Method | Path | File |
|---|---|---|---|
| Comment on a task | POST | `/v2/task/{task_id}/comment` | `api-v2/comments/post-v2-task-task_id-comment.md` |
| Get comments on a task | GET | `/v2/task/{task_id}/comment` | `api-v2/comments/get-v2-task-task_id-comment.md` |
| Comment on a list | POST | `/v2/list/{list_id}/comment` | `api-v2/comments/post-v2-list-list_id-comment.md` |
| Get list comments | GET | `/v2/list/{list_id}/comment` | `api-v2/comments/get-v2-list-list_id-comment.md` |
| Comment on a chat-view | POST | `/v2/view/{view_id}/comment` | `api-v2/comments/post-v2-view-view_id-comment.md` |
| Get chat-view comments | GET | `/v2/view/{view_id}/comment` | `api-v2/comments/get-v2-view-view_id-comment.md` |
| Threaded reply to a comment | POST | `/v2/comment/{comment_id}/reply` | `api-v2/comments/post-v2-comment-comment_id-reply.md` |
| Get threaded replies | GET | `/v2/comment/{comment_id}/reply` | `api-v2/comments/get-v2-comment-comment_id-reply.md` |
| Update a comment | PUT | `/v2/comment/{comment_id}` | `api-v2/comments/put-v2-comment-comment_id.md` |
| Delete a comment | DELETE | `/v2/comment/{comment_id}` | `api-v2/comments/delete-v2-comment-comment_id.md` |
| List chat comment subtypes (v3) | GET | `/api/v3/workspaces/{workspace_id}/comments/types/{comment_type}/subtypes` | `api-v3/comments/get-...` |

Formatting for all comment POST/PUT endpoints: see `comment-formatting.md` in this skill.

## Workspaces, spaces, folders, lists

| Intent | Method | Path | File |
|---|---|---|---|
| List my workspaces | GET | `/v2/team` | `api-v2/workspaces/get-v2-team.md` |
| Get workspace plan | GET | `/v2/team/{team_id}/plan` | `api-v2/workspaces/get-v2-team-team_id-plan.md` |
| Get workspace seats | GET | `/v2/team/{team_id}/seats` | `api-v2/workspaces/get-v2-team-team_id-seats.md` |
| List spaces in workspace | GET | `/v2/team/{team_id}/space` | `api-v2/spaces/get-v2-team-team_id-space.md` |
| Create a space | POST | `/v2/team/{team_id}/space` | `api-v2/spaces/post-v2-team-team_id-space.md` |
| Get/update/delete space | GET/PUT/DELETE | `/v2/space/{space_id}` | `api-v2/spaces/...-v2-space-space_id.md` |
| List folders in space | GET | `/v2/space/{space_id}/folder` | `api-v2/folders/get-v2-space-space_id-folder.md` |
| Create a folder | POST | `/v2/space/{space_id}/folder` | `api-v2/folders/post-v2-space-space_id-folder.md` |
| Folder from template | POST | `/v2/space/{space_id}/folder_template/{template_id}` | `api-v2/folders/post-v2-space-space_id-folder_template-template_id.md` |
| Get/update/delete folder | GET/PUT/DELETE | `/v2/folder/{folder_id}` | `api-v2/folders/...-v2-folder-folder_id.md` |
| List lists in folder | GET | `/v2/folder/{folder_id}/list` | `api-v2/lists/get-v2-folder-folder_id-list.md` |
| Create list in folder | POST | `/v2/folder/{folder_id}/list` | `api-v2/lists/post-v2-folder-folder_id-list.md` |
| List folderless lists in space | GET | `/v2/space/{space_id}/list` | `api-v2/lists/get-v2-space-space_id-list.md` |
| Create folderless list | POST | `/v2/space/{space_id}/list` | `api-v2/lists/post-v2-space-space_id-list.md` |
| Get/update/delete list | GET/PUT/DELETE | `/v2/list/{list_id}` | `api-v2/lists/...-v2-list-list_id.md` |
| Add existing task to another list | POST | `/v2/list/{list_id}/task/{task_id}` | `api-v2/lists/post-v2-list-list_id-task-task_id.md` |
| Remove task from a list | DELETE | `/v2/list/{list_id}/task/{task_id}` | `api-v2/lists/delete-v2-list-list_id-task-task_id.md` |
| List from template (folder/space) | POST | `/v2/folder/.../list_template/...` or `/v2/space/.../list_template/...` | `api-v2/lists/post-...list_template-template_id.md` |
| Shared hierarchy summary | GET | `/v2/team/{team_id}/shared` | `api-v2/shared-hierarchy/get-v2-team-team_id-shared.md` |

## Custom fields

| Intent | Method | Path | File |
|---|---|---|---|
| List fields on a list | GET | `/v2/list/{list_id}/field` | `api-v2/custom-fields/get-v2-list-list_id-field.md` |
| List fields on a folder | GET | `/v2/folder/{folder_id}/field` | `api-v2/custom-fields/get-v2-folder-folder_id-field.md` |
| List fields on a space | GET | `/v2/space/{space_id}/field` | `api-v2/custom-fields/get-v2-space-space_id-field.md` |
| List fields on a workspace | GET | `/v2/team/{team_id}/field` | `api-v2/custom-fields/get-v2-team-team_id-field.md` |
| Set a field value on a task | POST | `/v2/task/{task_id}/field/{field_id}` | `api-v2/custom-fields/post-v2-task-task_id-field-field_id.md` |
| Clear a field value | DELETE | `/v2/task/{task_id}/field/{field_id}` | `api-v2/custom-fields/delete-v2-task-task_id-field-field_id.md` |

Value shape depends on type (text string, number, unix-ms date, dropdown UUID, labels array, etc.). See `~/git/vendor-api-docs/clickup/docs/guides/custom-fields/` for per-type notes.

## Tags

| Intent | Method | Path | File |
|---|---|---|---|
| List tags on a space | GET | `/v2/space/{space_id}/tag` | `api-v2/tags/get-v2-space-space_id-tag.md` |
| Create a space tag | POST | `/v2/space/{space_id}/tag` | `api-v2/tags/post-v2-space-space_id-tag.md` |
| Rename/edit a space tag | PUT | `/v2/space/{space_id}/tag/{tag_name}` | `api-v2/tags/put-v2-space-space_id-tag-tag_name.md` |
| Delete a space tag | DELETE | `/v2/space/{space_id}/tag/{tag_name}` | `api-v2/tags/delete-v2-space-space_id-tag-tag_name.md` |
| Add tag to task | POST | `/v2/task/{task_id}/tag/{tag_name}` | `api-v2/tags/post-v2-task-task_id-tag-tag_name.md` |
| Remove tag from task | DELETE | `/v2/task/{task_id}/tag/{tag_name}` | `api-v2/tags/delete-v2-task-task_id-tag-tag_name.md` |

## Time tracking (modern)

| Intent | Method | Path | File |
|---|---|---|---|
| Start timer | POST | `/v2/team/{team_id}/time_entries/start` | `api-v2/time-tracking/post-v2-team-team_id-time_entries-start.md` |
| Stop timer | POST | `/v2/team/{team_id}/time_entries/stop` | `api-v2/time-tracking/post-v2-team-team_id-time_entries-stop.md` |
| Get running timer | GET | `/v2/team/{team_id}/time_entries/current` | `api-v2/time-tracking/get-v2-team-team_id-time_entries-current.md` |
| Create manual entry | POST | `/v2/team/{team_id}/time_entries` | `api-v2/time-tracking/post-v2-team-team_id-time_entries.md` |
| Query entries in date range | GET | `/v2/team/{team_id}/time_entries` | `api-v2/time-tracking/get-v2-team-team_id-time_entries.md` |
| Get/update/delete one entry | GET/PUT/DELETE | `/v2/team/{team_id}/time_entries/{timer_id}` | `api-v2/time-tracking/...-v2-team-team_id-time_entries-timer_id.md` |
| Get entry history | GET | `/v2/team/{team_id}/time_entries/{timer_id}/history` | `api-v2/time-tracking/get-v2-team-team_id-time_entries-timer_id-history.md` |
| Time-entry tag CRUD | GET/POST/PUT/DELETE | `/v2/team/{team_id}/time_entries/tags` | `api-v2/time-tracking/...-v2-team-team_id-time_entries-tags.md` |

Legacy time tracking (task-scoped, prefer the modern endpoints above): `api-v2/time-tracking-legacy/`.

## Attachments

| Intent | Method | Path | File |
|---|---|---|---|
| Attach file to task (v2, multipart) | POST | `/v2/task/{task_id}/attachment` | `api-v2/attachments/post-v2-task-task_id-attachment.md` |
| v3 entity attachment (also File custom fields) | POST | `/api/v3/workspaces/{workspace_id}/{entity_type}/{entity_id}/attachments` | `api-v3/attachments/post-...` |
| List attachments on an entity | GET | `/api/v3/workspaces/{workspace_id}/{entity_type}/{entity_id}/attachments` | `api-v3/attachments/get-...` |

Task attachments use `multipart/form-data` with `-F attachment=@/path/to/file`.

## Checklists and subtasks-like structure

| Intent | Method | Path | File |
|---|---|---|---|
| Create checklist on task | POST | `/v2/task/{task_id}/checklist` | `api-v2/task-checklists/post-v2-task-task_id-checklist.md` |
| Edit/delete a checklist | PUT/DELETE | `/v2/checklist/{checklist_id}` | `api-v2/task-checklists/...-v2-checklist-checklist_id.md` |
| Add checklist item | POST | `/v2/checklist/{checklist_id}/checklist_item` | `api-v2/task-checklists/post-v2-checklist-checklist_id-checklist_item.md` |
| Edit/delete checklist item | PUT/DELETE | `/v2/checklist/{checklist_id}/checklist_item/{checklist_item_id}` | `api-v2/task-checklists/...-v2-checklist-checklist_id-checklist_item-checklist_item_id.md` |

Note: subtasks are real tasks with a `parent` field on the POST body. They aren't in a separate section.

## Task relationships

| Intent | Method | Path | File |
|---|---|---|---|
| Add dependency | POST | `/v2/task/{task_id}/dependency` | `api-v2/task-relationships/post-v2-task-task_id-dependency.md` |
| Delete dependency | DELETE | `/v2/task/{task_id}/dependency` | `api-v2/task-relationships/delete-v2-task-task_id-dependency.md` |
| Add task-to-task link | POST | `/v2/task/{task_id}/link/{links_to}` | `api-v2/task-relationships/post-v2-task-task_id-link-links_to.md` |
| Delete task-to-task link | DELETE | `/v2/task/{task_id}/link/{links_to}` | `api-v2/task-relationships/delete-v2-task-task_id-link-links_to.md` |

## Members and users

| Intent | Method | Path | File |
|---|---|---|---|
| Current authenticated user | GET | `/v2/user` | `api-v2/authorization/get-v2-user.md` |
| Workspace members (direct) | GET | `/v2/team/{team_id}/member` | (no pretty doc, see openapi-v2.json) |
| List members | GET | `/v2/list/{list_id}/member` | `api-v2/members/get-v2-list-list_id-member.md` |
| Task members (watchers) | GET | `/v2/task/{task_id}/member` | `api-v2/members/get-v2-task-task_id-member.md` |
| Invite user | POST | `/v2/team/{team_id}/user` | `api-v2/users/post-v2-team-team_id-user.md` |
| Get/edit/remove user | GET/PUT/DELETE | `/v2/team/{team_id}/user/{user_id}` | `api-v2/users/...-v2-team-team_id-user-user_id.md` |
| Custom roles | GET | `/v2/team/{team_id}/customroles` | `api-v2/roles/get-v2-team-team_id-customroles.md` |

## Guests

All under `api-v2/guests/`: invite/remove/get/edit at workspace level (`/v2/team/{team_id}/guest...`); add/remove on task (`/v2/task/{task_id}/guest/{guest_id}`), list (`/v2/list/.../guest/...`), or folder (`/v2/folder/.../guest/...`).

## User groups

| Intent | Method | Path | File |
|---|---|---|---|
| List groups | GET | `/v2/group` | `api-v2/user-groups/get-v2-group.md` |
| Create group | POST | `/v2/team/{team_id}/group` | `api-v2/user-groups/post-v2-team-team_id-group.md` |
| Update/delete group | PUT/DELETE | `/v2/group/{group_id}` | `api-v2/user-groups/...-v2-group-group_id.md` |

## Views

| Intent | Method | Path | File |
|---|---|---|---|
| Get views (at any level) | GET | `/v2/{team\|space\|folder\|list}/{id}/view` | `api-v2/views/get-v2-...-view.md` |
| Create view at that level | POST | same paths | `api-v2/views/post-v2-...-view.md` |
| Get/update/delete a view | GET/PUT/DELETE | `/v2/view/{view_id}` | `api-v2/views/...-v2-view-view_id.md` |
| List tasks in a view | GET | `/v2/view/{view_id}/task` | `api-v2/views/get-v2-view-view_id-task.md` |

## Templates

| Intent | Method | Path | File |
|---|---|---|---|
| List task templates | GET | `/v2/team/{team_id}/taskTemplate` | `api-v2/templates/get-v2-team-team_id-tasktemplate.md` |
| List list templates | GET | `/v2/team/{team_id}/list_template` | `api-v2/templates/get-v2-team-team_id-list_template.md` |
| List folder templates | GET | `/v2/team/{team_id}/folder_template` | `api-v2/templates/get-v2-team-team_id-folder_template.md` |

## Goals

| Intent | Method | Path | File |
|---|---|---|---|
| List goals | GET | `/v2/team/{team_id}/goal` | `api-v2/goals/get-v2-team-team_id-goal.md` |
| Create goal | POST | `/v2/team/{team_id}/goal` | `api-v2/goals/post-v2-team-team_id-goal.md` |
| Get/update/delete goal | GET/PUT/DELETE | `/v2/goal/{goal_id}` | `api-v2/goals/...-v2-goal-goal_id.md` |
| Key result CRUD | POST/PUT/DELETE | `/v2/goal/{goal_id}/key_result`, `/v2/key_result/{key_result_id}` | `api-v2/goals/...` |

## Webhooks

| Intent | Method | Path | File |
|---|---|---|---|
| List webhooks | GET | `/v2/team/{team_id}/webhook` | `api-v2/webhooks/get-v2-team-team_id-webhook.md` |
| Create webhook | POST | `/v2/team/{team_id}/webhook` | `api-v2/webhooks/post-v2-team-team_id-webhook.md` |
| Update/delete webhook | PUT/DELETE | `/v2/webhook/{webhook_id}` | `api-v2/webhooks/...-v2-webhook-webhook_id.md` |

Signing and event semantics: `~/git/vendor-api-docs/clickup/docs/guides/webhooks/`.

## Docs (Doc pages, v3)

| Intent | Method | Path | File |
|---|---|---|---|
| List docs | GET | `/api/v3/workspaces/{workspace_id}/docs` | `api-v3/docs/get-api-v3-workspaces-workspace_id-docs.md` |
| Create doc | POST | `/api/v3/workspaces/{workspace_id}/docs` | `api-v3/docs/post-api-v3-workspaces-workspace_id-docs.md` |
| Get doc | GET | `/api/v3/workspaces/{workspace_id}/docs/{doc_id}` | `api-v3/docs/get-api-v3-workspaces-workspace_id-docs-doc_id.md` |
| Get doc page listing | GET | `/api/v3/workspaces/{workspace_id}/docs/{doc_id}/page_listing` | `api-v3/docs/...page_listing.md` |
| List pages | GET | `/api/v3/workspaces/{workspace_id}/docs/{doc_id}/pages` | `api-v3/docs/...pages.md` |
| Create page | POST | `/api/v3/workspaces/{workspace_id}/docs/{doc_id}/pages` | `api-v3/docs/post-...pages.md` |
| Get/update single page | GET/PUT | `/api/v3/workspaces/{workspace_id}/docs/{doc_id}/pages/{page_id}` | `api-v3/docs/...pages-page_id.md` |

## Chat (v3)

Channel CRUD, message send/edit/delete, reactions, replies, followers, DMs, location (task-attached) channels. All under `api-v3/chat/` with file names following `<verb>-api-v3-workspaces-workspace_id-chat-<sub>.md`. Examples:
- Create channel: `post-api-v3-workspaces-workspace_id-chat-channels.md`
- Send message: `post-api-v3-workspaces-workspace_id-chat-channels-channel_id-messages.md`
- Start DM: `post-api-v3-workspaces-workspace_id-chat-channels-direct_message.md`
- Thread reply: `post-api-v3-workspaces-workspace_id-chat-messages-message_id-replies.md`
- Reactions: `post-/delete-api-v3-workspaces-workspace_id-chat-messages-message_id-reactions[-reaction].md`

## Audit logs (v3)

| Intent | Method | Path | File |
|---|---|---|---|
| Query audit logs | POST | `/api/v3/workspaces/{workspace_id}/auditlogs` | `api-v3/audit-logs/post-api-v3-workspaces-workspace_id-auditlogs.md` |

## Privacy and access (v3)

| Intent | Method | Path | File |
|---|---|---|---|
| Patch ACLs on an object | PATCH | `/api/v3/workspaces/{workspace_id}/{object_type}/{object_id}/acls` | `api-v3/privacy-and-access/patch-api-v3-workspaces-workspace_id-object_type-object_id-acls.md` |

## OAuth (for 3rd-party app builders only)

Personal-token users skip this section.

| Intent | Method | Path | File |
|---|---|---|---|
| Exchange auth code for access token | POST | `/v2/oauth/token` | `api-v2/authorization/post-v2-oauth-token.md` |

## If you can't find it here

1. Check the category READMEs: `api-v2/<category>/README.md` and `api-v3/<category>/README.md`.
2. Search the OpenAPI specs directly: `openapi-v2.json` (paths-keyed JSON) or `openapi-v3.yaml`.
3. Check guides: `docs/guides/<topic>/` - especially `webhooks/`, `custom-fields/`, `tasks/`, `getting-started/`.
