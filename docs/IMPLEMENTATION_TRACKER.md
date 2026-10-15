# NOOR AI Implementation Tracker

Last updated: 2026-10-15

This tracker deliberately separates prototype work from a working, database-connected implementation.

## Prompt 1 — Authentication, onboarding, role-based dashboards and task management

- [x] Consolidated specification stored in `docs/MASTER_PROMPT.md`.
- [x] Unified visual prototype at `index.html`.
- [ ] Production Supabase Auth, secure username lookup, school onboarding and email verification.
- [ ] Server-enforced Creator / Principal / Manager / Teacher / Student permissions.
- [ ] Working school tenancy and cross-school RLS isolation.
- [ ] Persisted task assignment, submission, review and audit workflow.
- [ ] Automated authorization tests.

**Status: visual prototype/specification available; production foundation is not complete.**

## Prompt 2 — Teacher dashboard and classroom management

- [x] Unified teacher view and standalone visual prototype at `preview/teacher-dashboard-preview.html`.
- [x] Next.js/Supabase starter ZIP generated in the conversation.
- [x] SQL schema migrations committed under `app-starter/supabase/migrations/`.
- [x] Setup, security and QA documentation committed.
- [ ] Commit the complete Next.js source tree and ZIP packages directly into this GitHub repository.
- [ ] Configure a dedicated NOOR AI Supabase project and environment secrets.
- [ ] Apply and review migrations against that project.
- [ ] Run build, attendance persistence, enrollment, assignment revocation and RLS isolation tests.

**Status: starter code and prototype exist; repository/database integration and live tests remain.**

## Prompt 3 — Student dashboard, progress reports and AI test paper generator

- [x] Student-facing visual view at `preview/student-dashboard-preview.html`.
- [x] Student view also included in the unified prototype `index.html`.
- [x] Consolidated implementation requirements in `docs/MASTER_PROMPT.md`.
- [ ] Production student APIs reading the authorized school records.
- [ ] Verified read-only permissions for official attendance and marks.
- [ ] Correct attendance and marks calculations against database records.
- [ ] Real downloadable school-branded progress PDF.
- [ ] Secure multi-file syllabus upload and OCR/document extraction.
- [ ] Review/correction of extracted text before generation.
- [ ] Real server-side AI provider integration and secrets configuration.
- [ ] Editable paper saving, PDF export and protected answer-key workflow.
- [ ] Automated tests for marks totals, student privacy and school boundaries.

**Status: visual preview/specification only for Task 3; production functionality is not complete.**

## Theme and preview

- [x] Common rose/burgundy + warm ivory + champagne accent theme in the unified preview.
- [x] Theme selector options in the prototype.
- [x] Student and teacher preview paths in the repository.

Preview interactions use local demo state only. A change in the preview does not write to Supabase. Do not enter real student data until the security and persistence tests pass.
