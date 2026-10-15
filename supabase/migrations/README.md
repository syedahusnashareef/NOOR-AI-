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
- `user_sound_preferences` (Ticket 07 — personal Sound & Feel controls)

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
