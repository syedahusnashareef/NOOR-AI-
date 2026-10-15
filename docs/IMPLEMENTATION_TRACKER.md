# NOOR AI Implementation Tracker

Last updated: 2026-10-16 (verified live migrations and policy hardening)

This tracker separates live database work from frontend features that are still prototypes or awaiting end-to-end tests.

## Dedicated project
- [x] Created and verified the separate Supabase project NOOR-AI (npzedchxfurcphvpjock) in the Mumbai region.
- [x] Confirmed project state ACTIVE_HEALTHY.
- [x] Connected the unified frontend to the project using a browser-safe publishable key.
- [x] Confirmed there are no Supabase security-advisor findings after the current migrations.
- [x] Re-ran the performance advisor: no remaining unindexed-foreign-key or overlapping-permissive-policy findings; unused-index notices remain because the database is empty.
- [ ] Provision the first trusted Platform Creator account using a secure account-setup process.
- [ ] Create and verify the first school workspace and its Headmaster account.
- [ ] Add automated cross-school authorization tests before onboarding real schools.

## Database migrations verified live
- [x] Initial identity and school workspace schema: student_admin_workspace.
- [x] Profiles, schools, school directory, classes, sections, teacher class assignments and audit logs.
- [x] RLS enabled on all current public tables.
- [x] Student profile fields include full name, email, mobile, parent/guardian name, roll number, class, section and private avatar path.
- [x] Private student-photo bucket configured for image uploads.
- [x] Added and applied school_operations_foundation:
  - school settings and subject catalogue
  - attendance sessions and per-student attendance records
  - tasks and individual assignees
  - school notices and calendar/meeting events
  - notification event log
  - AI-generation usage ledger
- [x] Added and applied school_operations_policy_hardening:
  - school/class assignment checks for attendance
  - task access helper to avoid recursive RLS policy evaluation
  - task assignee validation and foreign-key indexes
- [x] Added and applied school_role_policy_hardening:
  - removed permissive legacy policies that allowed teachers to manage school-wide classes/sections
  - restricted class, section and teacher-assignment management to school leadership
  - consolidated overlapping profile-update policies
  - indexed remaining foreign-key paths flagged by the advisor
- [x] Verified the new tables are present and RLS-enabled.
- [ ] Mirror the live operational SQL into version-controlled migration files and verify a clean-database replay.
- [ ] Add automated tests for attendance, task access, role permissions and school isolation.

## Frontend / identity
- [x] Unified burgundy/rose, ivory and champagne-gold visual interface.
- [x] Student registration UI asks for student name, email/login, password, school, join code, roll number, class, section, mobile, parent/guardian name and student photo.
- [x] Student dashboard greeting uses the saved profile name (for example, Hello, first name).
- [x] Sign-in handler calls Supabase Auth and checks the database profile role/status before entering the workspace.
- [ ] Test a full registration and email-verification cycle with a real mailbox.
- [ ] Confirm photo upload and profile persistence with a real test account.
- [ ] Complete and verify the secure staff account provisioning/invitation flow.
- [ ] Finish production-quality, role-specific dashboards with database-backed data.

## Teacher / Headmaster / Manager / Creator operations
- [x] Database tables created for attendance, subjects, tasks, notices, calendar events, notification logging and AI usage tracking.
- [ ] Connect teacher attendance entry to the new tables and verify save/reload.
- [ ] Connect Headmaster class/section/teacher management and school notices.
- [ ] Connect teacher-to-student and Headmaster-to-teacher task assignment and status updates.
- [ ] Complete Manager's restricted permission set and verify every sensitive action server-side.
- [ ] Build Creator admin console for school provisioning, subscription/usage overview and account support.

## Task 3 — student progress and AI assessment
- [ ] Connect student dashboard to authorized attendance and marks records.
- [ ] Build attendance/marks calculations and school-branded PDF reports.
- [ ] Add syllabus uploads with server-side OCR, text review and correction.
- [ ] Add secure server-side AI paper generation, editable saved papers, PDF export and protected answer keys.
- [ ] Add usage limits and provider-cost tracking before enabling paid AI calls.

## Task 4 — notifications and email
- [x] Notification event table exists for queued/sent/failed/skipped events.
- [ ] Configure a trusted email provider and server-side secrets.
- [ ] Send guardian absence emails only after attendance is saved; test delivery and logs.
- [ ] Add teacher absence alerts, notices, meeting invitations and in-app notifications.
- [ ] Never label a queued event as sent without provider confirmation.

## Deployment and safety
- [x] GitHub Pages deployment is live at https://syedahusnashareef.github.io/NOOR-AI-/.
- [x] Security advisor check is clean as of 2026-10-16.
- [ ] Resolve performance-advisor foreign-key index warnings for the full schema.
- [ ] Run end-to-end tests before treating the website as production-ready.
- [ ] Never commit Supabase service-role keys, passwords or AI/email provider secrets.
- [ ] Do not enter real student or guardian data until account provisioning, authorization and persistence tests pass.

Current honest status: the dedicated database and operational schema foundations are live. The website still needs end-to-end workflow wiring and verification; this is not yet a production-ready school SaaS.



## Task 5 + Task 6 integration update — 16 October 2026

This work extends the existing NOOR AI application and its existing Supabase project `npzedchxfurcphvpjock`; it does not create a second app or project.

### Implemented in the current codebase

- New teacher views: **My Teaching & Smart Notes**, **Weekly Teaching Plan**, **Today's Teaching Report**, **My Schedule**, and **Assessments & Marks**.
- Smart Notes supports rough notes, reviewed OCR text, AI-generated draft notes, class/year/subject context, teacher approval before publish, saved drafts, and print/save-as-PDF.
- Multiple JPG/PNG/WebP syllabus images can be uploaded with limits (8 per request, 4 MB each, 12 MB total). Original files are stored in the private `noor-syllabus-source` bucket with school/context metadata and restricted storage policies.
- Weekly plans distinguish a saved plan from actual teaching completion. Daily reports have a draft/submitted/reviewed/returned status, local recovery, server autosave, version/revision trail, review feedback, and a teacher-facing notification stream.
- Syllabus units/progress support chapter/lesson/topic status and optional teacher-reported percentages. Management summaries use saved records and label percentages as reported indicators.
- Published Smart Notes have a student view restricted to approved notes for the student's class/section. Internal reports, draft notes and review remarks are not student-facing.
- Assessment/test metadata and assessment-result tables now store actual marks, grades, and feedback; student views only read their own saved results and management can see authorized student results.
- Management navigation now includes the School Management Portal, Student Directory, Teacher Directory, Academic Monitoring, Attendance, Assessments & Marks, Schedules & Extra Classes, Meetings, Notices, Staff & Access, and Audit Logs. The Management role chooser exposes exactly Principal, School Creator/Owner, and Manager; selecting a role by itself does not grant it.
- Secure owner onboarding is mediated by a verified-email server RPC. School codes are random; the secret code is stored only as a hash and displayed once after creation/rotation. School invites use single-use token hashes, email matching and expiry. Existing membership removal preserves academic history; a trusted RPC handles reactivation.
- Manager grants default to denied. The Manager permission matrix is Owner-controlled. Profile role/school/email fields are protected by database guardrails; membership gates limit school-specific records after removal.
- A JWT-protected Edge Function `noor-ai-academic-assistant` handles AI generation/OCR server-side and logs token/cost estimates. No provider key is in frontend code.

### Database work applied to the existing NOOR AI project

Applied additive migrations include `academic_smart_notes_and_school_management`, `school_management_invites_and_permission_hardening`, `academic_permission_and_secret_stability_fixes`, `noor_role_membership_and_profile_guard_hardening`, `invitation_lifecycle_and_assessment_security`, `assessment_context_and_invitation_update_fixes`, `assessment_history_and_regrading_permissions`, and `private_syllabus_source_uploads`.

Tables added/extended include academic years, syllabus units and progress, smart notes, weekly lesson plans, daily reports, report revisions/reviews, memberships, permission grants, invitations, teacher schedules, extra classes, administrative audit logs, assessments, assessment results, and private syllabus upload metadata. RLS is enabled on new tenant data and source files. Server-side constraints validate school/year/class/section/subject/assessment context and marks limits. No school/user academic history was dropped.

### Validation performed and not yet complete

- The schema was inspected before changes and the database migrations/RPCs/Edge Function were applied to the dedicated NOOR AI project.
- The frontend source is integrated into the existing app and published via GitHub Pages.
- **Full acceptance testing with real user accounts is not yet possible**: there were no provisioned school/teacher/student Auth records at the time of this change. A verified Owner must create the first school, configure its academic year/classes/subjects, assign teachers, and run the workflows with test accounts.
- Set `AI_PROVIDER_API_KEY` as a Supabase Edge Function secret before AI generation/OCR can run. Optional `AI_PROVIDER_MODEL`, `AI_PROVIDER_CHAT_COMPLETIONS_URL`, `AI_INPUT_COST_PER_1K_USD`, and `AI_OUTPUT_COST_PER_1K_USD` are server-side configuration only.
- OCR currently accepts image files only (JPG/PNG/WebP); direct PDF/DOC/DOCX extraction remains unimplemented. PDF output is browser print/save-as-PDF; tabular download is CSV, not native XLSX. Real email delivery remains unconfigured; notification rows are in-app/queued records, not proof of an email being sent.
- Multi-school switching for one identity is not implemented; invitation acceptance rejects a user already attached to a different primary school. The requested "Master Key" is intentionally not a universal bypass credential; an actual recovery-key setup/rotation UI remains unimplemented.
- Migration-source parity is still being backfilled: the latest assessment and private-upload SQL is checked into `supabase/migrations/`, but the first live schema migrations still need their exact source bodies mirrored before a fresh-project bootstrap is reproducible. See `supabase/migrations/README.md` and the non-destructive rollback guidance.

**Status: implemented foundation, not final production acceptance.** Never treat generated notes as approved until a teacher reviews them; never treat an unreported class as zero teaching activity or syllabus percentage as proof of student learning.
