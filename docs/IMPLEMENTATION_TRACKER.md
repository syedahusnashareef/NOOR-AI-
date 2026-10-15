# NOOR AI Implementation Tracker

Last updated: 2026-10-16

This tracker separates live database work from frontend features that are still prototypes or awaiting end-to-end tests.

## Dedicated project
- [x] Created and verified the separate Supabase project NOOR-AI (npzedchxfurcphvpjock) in the Mumbai region.
- [x] Confirmed project state ACTIVE_HEALTHY.
- [x] Connected the unified frontend to the project using a browser-safe publishable key.
- [x] Confirmed there are no Supabase security-advisor findings after the current migrations.
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
