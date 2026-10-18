# NOOR AI Supabase migrations

Project: `npzedchxfurcphvpjock` (Mumbai region). Do not point these changes at Cozy & Co or another project.

## Applied on the existing project

The existing schema was inspected before additive migrations were applied. The following migration names are recorded/applied on the live NOOR AI Supabase project:

- `student_admin_workspace`
- `school_operations_foundation`
- `school_operations_policy_hardening`
- `school_role_policy_hardening`
- `academic_smart_notes_and_school_management`
- `school_management_invites_and_permission_hardening`
- `academic_permission_and_secret_stability_fixes`
- `noor_role_membership_and_profile_guard_hardening`
- `invitation_lifecycle_and_assessment_security`
- `assessment_context_and_invitation_update_fixes`
- `assessment_history_and_regrading_permissions`
- `private_syllabus_source_uploads`
- `schedule_audit_payload_and_school_name_guard`
- `membership_aware_authorization_helpers`
- `staff_invitation_profile_completion`
- `public_authenticated_management_rpc_wrappers`
- `schedule_teacher_assignment_guard`

The first academic/management schema migrations were applied before the current source-parity pass; their exact SQL bodies are not yet mirrored one-to-one in this folder. The schedule teacher assignment guard is mirrored as `20261015193122_schedule_teacher_assignment_guard.sql`, with a non-destructive function rollback under `supabase/rollback/`. The latest assessment-history and private-upload SQL files are available here. Do **not** treat this folder as a blank-project bootstrap until all earlier applied migration bodies have been checked into version control. Existing records must be kept.

## Source and deployment rule

1. Inspect the live migration history before running anything.
2. Apply only the next unapplied migration in the dedicated NOOR AI project.
3. Back up important data and test on a non-production project before destructive changes.
4. Do not expose service-role keys, AI provider keys, secret-code hashes or invitation token hashes to the browser.
5. The database is authoritative for role/membership access; frontend navigation alone is not security.
6. Preserve old academic rows when a membership is removed. A rollback should revert code or revoke a feature, not drop historical tables.

## External server-side secrets

The deployed Edge Function is `noor-ai-academic-assistant`. Configure these through Supabase Edge Function Secrets, not `config.js` or GitHub browser code:

- `AI_PROVIDER_API_KEY` — required to generate notes/weekly plans/reports or run image OCR.
- `AI_PROVIDER_MODEL` — optional; function default is `gpt-4o-mini`.
- `AI_PROVIDER_CHAT_COMPLETIONS_URL` — optional for a compatible provider endpoint.
- `AI_INPUT_COST_PER_1K_USD`, `AI_OUTPUT_COST_PER_1K_USD` — optional rate configuration for estimated usage costs.

The function intentionally reports a configuration error when no provider key is configured. That is safer than pretending AI output has been generated.


## School Command Centre additions (18 October 2026)

Applied on the dedicated NOOR AI project; source migrations are mirrored in this branch:

- `20261018104846_school_command_centre.sql` — layout preferences, task metadata/status history/comments/attachments, automation rules/runs, email templates/delivery logs and durable reminder records. Reuses the existing schools, profiles, task, calendar and academic tables.
- `20261018105400_enable_school_task_reminders_scheduler.sql` — enables `pg_cron` and schedules the idempotent reminder queue.
- `20261018105712_school_command_centre_automation_engine.sql` — secure rule-action runner, school context validation and scheduled operational triggers.
- `20261018110225_school_command_centre_recurring_tasks_and_calendar_filters.sql` — scheduled recurring task instances; school/class/subject/teacher calendar context constraints; reminder handling for tasks without assignees.

Active scheduler jobs verified in the live project: `noor-cc-task-reminders`, `noor-cc-automation-rules`, and `noor-cc-recurring-tasks`, each every minute. These jobs queue/record work; email is not marked sent until the provider responds.

### Command Centre server-side secrets

Configure these in Supabase **Edge Function Secrets** (never `config.js`, GitHub browser code, or a client bundle):

- `BREVO_API_KEY` — Brevo transactional email API key.
- `EMAIL_FROM` — verified sender address.
- `EMAIL_FROM_NAME` — optional sender display name (defaults to `NOOR AI`).
- `AI_PROVIDER_API_KEY` — optional for AI-assisted summaries; if absent, the secure insights endpoint returns verified, database-derived signals without claiming an AI summary was generated.

Use the Email Automation page to send a test only to the currently signed-in verified account. Saving a template or enabling a rule does not prove email delivery. Provider acceptance is logged distinctly from verified inbox delivery. Configure the sender/domain authentication and school communication policy before enabling outward-facing rules.

Fee Management remains a planned phase. No production invoice, payment, collected-fee or outstanding-balance data is created by this work.
