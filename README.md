# NOOR AI — School Operations Workspace

NOOR AI is a school operations workspace for school leadership, teachers and students. The current website is hosted on GitHub Pages, with Supabase providing authentication, PostgreSQL data, Row-Level Security (RLS), private file storage and server-side Edge Functions.

- **Website:** https://syedahusnashareef.github.io/NOOR-AI-/
- **Main frontend:** `index.html`
- **Account appearance:** `theme-system.js` and `theme-system.css`
- **School operations:** `academic.js`, `academic-extras.js`, `command-centre.js`
- **Sound engine:** `sounds/sound-manager.js`, `sounds/sound-settings.js`
- **Server-side workflows:** `supabase/functions/`
- **Security model and QA notes:** `app-starter/SECURITY_MODEL.md`, `app-starter/QA_CHECKLIST.md`
- **Latest focused audit:** `docs/APP_AUDIT_2026-10-18.md`

## Current capabilities

- Sign-in, account recovery, school onboarding and role-aware workspace routing.
- Separate school leadership, teacher and student views, with school-scoped database policies.
- Class/section and staff management, attendance, assessments, marks, syllabus progress, teaching plans, daily teaching reports and teacher-reviewed Smart Notes.
- School notices and meeting invitations. Notices are published to the selected audience's in-app board; this action does **not** automatically email every recipient.
- School Command Centre with movable/resizable dashboard widgets, tasks, calendar, notification/email status and data-backed school insights.
- **Appearance Studio** with eight personal themes: Rose Gold, Pearl Ivory, Ocean Blue, Sage Garden, Lavender Mist, Teal Glass, Sandstone and Midnight Luxe. Theme, text-size and reduced-motion preferences are saved to the signed-in account when the database is available.
- Central Sound & Feel controls with an account preference record, volume control, previewable sound categories, a mute switch and haptic/voice options where supported.

## Security and deployment

Only the Supabase URL and publishable browser key belong in `config.js`. Service-role keys, database passwords and AI/email provider secrets must remain server-side in Supabase Edge Function secrets.

The deploy workflow copies an explicit allow-list of public website assets to GitHub Pages. It runs headless Playwright smoke checks for the Appearance Studio and sound engine after deployment. A passing smoke test checks that the public page/assets and selected client behaviour work; it is **not** a substitute for authenticated, multi-school access testing.

## Before using real student records

The app should not be treated as fully production-accepted until these items are complete:

1. Verify and activate the first school, then test separate school-owner/principal, manager with restricted permissions, teacher and student/guardian accounts.
2. Execute positive and negative access tests across at least two schools, including attempts to access an unassigned class and notice, mark or attendance record.
3. Reconcile live Supabase migrations with version-controlled SQL. The live database contains applied migration entries whose exact source SQL files are missing from the repository, so a clean-project bootstrap is not yet reproducible.
4. Enable Supabase Auth leaked-password protection and address the current database security/performance advisor findings documented in the audit.
5. Configure and test the approved email provider/sender before relying on guardian email or automated notices.

Do not load production student/guardian personal data until the acceptance checklist is completed. See the audit document for the latest verified state, scope, findings and limitations.
