# NOOR AI rollback / recovery strategy

## Preferred rollback (non-destructive)

1. Revert the affected GitHub commit(s) to restore the previous `index.html`, `academic.css`, `academic.js` and `academic-extras.js`.
2. Keep the database tables and historical rows. Hiding/reverting UI does not require deleting student, teacher, attendance, report, review, note, assessment, or audit history.
3. If an AI endpoint is being misused, remove/rotate the provider secret in Supabase Edge Function Secrets and/or disable the function. Never put the key in the browser.
4. If a migration causes a permission issue, apply a reviewed forward migration that changes the relevant RLS policy/function. Do not blindly restore previously broad policies: several legacy Manager policies were intentionally narrowed.
5. After rollback, rerun Supabase Security and Performance advisors and verify school isolation with two separate school test accounts.

## Important

The changes are additive and retain existing academic history. There is intentionally no blanket `DROP TABLE` rollback because it could destroy reports, student results, audit rows or published notes. Exact migration-source parity for the earliest live migrations is still being backfilled in `supabase/migrations/README.md`; a fresh project must not use this folder as a one-click bootstrap until that parity work is complete.
