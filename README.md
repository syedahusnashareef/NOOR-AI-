# NOOR AI — School Management SaaS

This repository is the project home for the first three NOOR AI development prompts.

## Current status — please read before using real school data

- **Prompt 1 — Foundation and role-based workspace:** the combined product specification and visual prototype are present. The live authentication, onboarding, role provisioning, school tenancy and task workflows are **not yet fully implemented and end-to-end tested**.
- **Prompt 2 — Teacher dashboard and classroom management:** the teacher preview and Next.js/Supabase starter package are available as conversation downloads. The database migrations and setup/security/QA notes are in this repository. Live database integration and the complete acceptance tests remain pending.
- **Prompt 3 — Student dashboard, progress reports and AI paper generator:** a student-facing preview is present in `preview/student-dashboard-preview.html` and in the unified `index.html`. This is **a demo with sample data**, not a connected student account. Production student record APIs, downloadable PDF reports, syllabus OCR, a real server-side AI provider, answer-key controls and live security tests remain pending.

## Preview files

- `index.html` — combined NOOR AI prototype for the landing page and Creator/Principal/Manager/Teacher/Student views.
- `preview/student-dashboard-preview.html` — unified prototype initialized in the Student view.
- `preview/teacher-dashboard-preview.html` — standalone teacher/classroom prototype.

Open an HTML file locally in Chrome/Edge to explore it. The role switcher in the unified preview is only a demo convenience; it is not a real login system.

## Specifications and database files

- `docs/MASTER_PROMPT.md` — consolidated specification for Prompts 1–3.
- `docs/COMBINED_PREVIEW_README.md` — preview contents and limitations.
- `app-starter/README.md` — setup notes for the starter.
- `app-starter/SECURITY_MODEL.md` — intended access-control model.
- `app-starter/QA_CHECKLIST.md` — acceptance-test checklist.
- `app-starter/supabase/migrations/001_initial_schema.sql` — initial schema migration.
- `app-starter/supabase/migrations/002_teacher_classroom.sql` — teacher/classroom migration.

## Starter ZIP packages

The full starter code and ZIP packages were generated separately in this conversation. They are not yet committed as binary ZIP files in this repository. Check the available downloadable artifacts in the conversation for the original packages.

## Security and data

Do not enter real student information until authentication, row-level security, school-level isolation, backups, audit trails, retention rules and deployment settings have been configured and tested. Never commit secrets. Store AI provider keys and Supabase service-role credentials only in server-side environment variables or Supabase Edge Function secrets.

**No feature should be marked complete based only on a visual preview.**