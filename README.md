# NOOR AI — School Management SaaS

This repository is the central home for the NOOR AI project.

## Project status (honest status)

- **Prompt 1 — Foundation and role-based product concept:** the prompt/specification and visual prototype are available. The production authentication, tenant isolation, and full task workflows still require integration and end-to-end testing.
- **Prompt 2 — Teacher dashboard/classroom management:** a Next.js/Supabase starter implementation and a separate interactive teacher preview are available. It has not yet been connected to a dedicated NOOR AI Supabase project or fully tested in a live deployment.
- **Prompt 3 — Student dashboard, progress PDFs, AI paper generator:** a student-facing visual view exists in the combined preview and the master prompt defines requirements. The production student module, report generation, OCR and real AI generation are **not yet complete**. Demo question generation is not real AI.

## Contents

- `preview/index.html` — combined visual prototype; open locally in a browser.
- `preview/teacher-dashboard-preview.html` — teacher/classroom standalone visual prototype.
- `docs/MASTER_PROMPT.md` — consolidated development specification for Prompts 1–3.
- `app-starter/` — Next.js/Supabase starter source and SQL migrations when added.
- `downloads/` — project ZIP packages.

## Important

The HTML previews are prototypes and use demo data. They do not establish working database persistence, login, server-side permissions, OCR, AI API access or PDF generation. Do not enter real student information until the backend is configured, tested and reviewed.

Never commit secrets. Keep Supabase service-role keys and AI provider keys in server-side environment variables or Supabase Edge Function secrets.