# NOOR AI — School workspace foundation

This repository contains the NOOR AI role-based school workspace. The deployed static entry point is `index.html`; the browser-safe Supabase configuration is `config.js`. The production backend schema is defined in `app-starter/supabase/migrations/003_student_admin_workspace.sql`.

**Status:** UI and schema are prepared; live database connection and multi-account acceptance tests are pending dedicated NOOR AI Supabase project setup. Do not describe the site as production-connected until setup checks pass. See [`docs/NOOR_AI_STUDENT_ADMIN_SETUP.md`](docs/NOOR_AI_STUDENT_ADMIN_SETUP.md).

Only the Supabase project URL and publishable key belong in `config.js`. Never commit service-role keys, database passwords or AI provider secrets.