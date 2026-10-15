# NOOR AI — School Intelligence MVP + Task 2 Classroom Module

NOOR AI is a multi-school school-management SaaS starter with a premium, restrained visual system and a working classroom-management implementation in source code. The standalone brand mark is a designer-style **N** monogram.

> **Important status:** the screens, route handlers, and two SQL migrations are included in this package, but they have **not** been deployed or executed against a dedicated NOOR AI Supabase project in this environment. The main `/` page remains a labelled demo dashboard. Do not enter real student data until the migrations are reviewed/applied and the QA checklist below passes against the target project.

## Task 2 modules included

- **Teacher workspace** at `/teacher`: teacher profile/username/photo, assigned school, assigned class and section cards, class-teacher badge, assigned subjects, school-local date, today’s attendance summary, upcoming authorized tests and published classwork.
- **Roll-number-wise attendance**: roster ordered with numeric-aware roll-number sorting; Present, Absent, Late and management-approved leave; unmarked totals; explicit save; partial-save confirmation; warning before discarding unsaved changes; server-side date/calendar/class checks; database uniqueness per student/date; correction audit trail.
- **Student progress**: real saved attendance, test results, marks and feedback only. Missing academic data is shown as unavailable rather than fabricated.
- **Enrollment workflow**: direct teacher enrollment is off by default and is a school policy. When disabled, teachers submit a request; authorized school management approves/rejects it. Student detail edits, class transfers and deactivation preserve historical records.
- **School setup** at `/management/classrooms`: configurable classes/sections, academic years, subjects, teacher profiles, unique usernames, account linking, teacher/class/subject assignments, class-teacher designation, calendar exceptions, leave approval, student management and enrollment request review.
- **Security foundation**: server route handlers, authenticated Supabase SSR client, school/class/subject scoping in RLS, database validation triggers, and audited attendance updates. Revoking a class assignment affects subsequent requests immediately because authorization reads the persisted assignments.

Students do not need user accounts to appear in school records. A teacher who uses `/teacher` needs an individual Supabase Auth account linked to the teacher record by trusted management. Do not use a shared teacher login.

## Local setup (Windows 11)

1. Install Node.js 20.9 or newer and open this folder in VS Code.
2. Open the VS Code Terminal here and run `npm install`.
3. Copy `.env.example` to `.env.local` and fill in the **dedicated NOOR AI** Supabase project URL and publishable key.
4. Run `npm run dev` and open `http://localhost:3000`.
5. Sign-in is at `/login`; teacher workspace is at `/teacher`; management setup is at `/management/classrooms`.

`npm install` could not reach the npm registry in the build environment used to prepare this package (DNS `EAI_AGAIN`), so a dependency install and full Next.js production build could not be verified here. The Supabase packages are specified at reviewed versions; install with network access and commit the generated lockfile before a real deployment.

## Database installation

**Use a dedicated NOOR AI project. Do not run these migrations on Cozy & Co., your portfolio, or any unrelated database.**

Run in order using the SQL Editor or a migration workflow you control:

1. `supabase/migrations/001_initial_schema.sql`
2. `supabase/migrations/002_teacher_classroom.sql`

Migration 002 depends on the base schema in migration 001. Review both SQL files first. The package includes role- and school-scoped RLS policies, attendance RPCs, assignment and enrollment RPCs, triggers, and audit tables. Applying the SQL is **not** proof that the application is production-ready; run `QA_CHECKLIST.md` against the real project after migrations are applied.

## First account and teacher linking

1. Create the Creator login in Supabase Auth.
2. Using a trusted SQL Editor/administrative workflow, grant the Creator platform role for that exact Auth UUID. Never expose Creator as a public sign-up option.
3. Create a school and grant a Principal membership with appropriate permissions.
4. The Principal/Creator creates classes, academic years, subjects and teacher records.
5. If a teacher needs to sign in, create/invite that adult’s Auth account first, then paste the **Auth user UUID** into the teacher profile’s account-link field. Never enter the teacher’s password into classroom management.
6. Assign classes and subjects. The teacher dashboard then retrieves those assignments from the database on every request.

The school secret key requested earlier is not used as a replacement for personal sign-in. If it is introduced as an extra workspace gate, validate it server-side using a modern password hashing strategy, rate-limit attempts, rotate/revoke it, and never store its plaintext or embed it in browser code.

## Secrets

- Browser-safe: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
- Server only: Supabase service/secret key, any AI-provider API key, school-key hash/pepper.
- Put local credentials in `.env.local`; the file is ignored by Git. In deployment, use the host’s server-side environment secret settings or Supabase Edge Function secrets. Never paste secret API keys in ChatGPT, and never prefix a private secret with `NEXT_PUBLIC_`.

## Current implementation boundaries

- The demo home page is not a live analytics dashboard yet.
- The classroom module requires the two migrations and valid teacher/management account links before database-backed screens work.
- No migration has been applied to any connected database here. The existing connected Supabase projects were confirmed to be Cozy & Co. and a personal portfolio project, so they were deliberately left unchanged.
- External auth invitation flows, Creator bootstrap automation, MFA enforcement, billing, backups/restore rehearsal, privacy notices, and production deployment still require setup and end-to-end verification.