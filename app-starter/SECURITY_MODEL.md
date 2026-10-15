# NOOR AI — Security model and data-integrity review

## Authentication and roles

- **Creator** is a platform-level role granted only through a trusted administrative action. Public sign-up cannot select it.
- **Principal** can manage the school according to the school-membership policy.
- **Manager** receives explicit per-school permission flags; missing permissions default to false.
- **Teacher** is an authenticated adult linked to one active `teachers` row by `teachers.user_id`. The linked profile is not allowed to grant itself class or subject assignments.
- **Students are records, not login users** in this MVP. Student data is accessible only to school management with permissions or to a teacher in currently assigned class/subject boundaries.

The prior requested school secret key, if added later, must be an extra gate only. A shared key cannot reliably identify a specific adult or provide per-person revocation. Store only a salted, modern password hash; rate-limit attempts; rotate and audit the key; never retrieve plaintext or hardcode the key in frontend code.

## Teacher and classroom boundaries

- Classes, teacher assignments, subject assignments and school calendar all carry a school ID and are validated at database boundaries.
- Teacher visibility depends on persisted active class assignments and subject assignments. Removing an assignment must immediately deny subsequent requests; hiding a link is not authorization.
- RLS restricts students and attendance to the teacher’s assigned classes. Academic assessment/marks access also checks the teacher’s subject assignment.
- Attendance saves use a database RPC, reject duplicate students in a payload, rely on a unique student/date constraint, and write audit events for creation/correction/removal.
- Students are deactivated/transferred rather than destructively deleted. Enrollment history retains the class/date interval used to validate historical attendance.
- New enrollments/transfers must target active classes. Approved leave is an explicit record and is required before `excused` attendance can be saved.
- School timezone drives local dates. Future dates and dates explicitly marked as non-school days are rejected. Each school should record holidays and special non-school days in the calendar.
- No API handler uses a Supabase service-role key. Browser clients use only the project publishable key.

## Manager permission examples

Use the smallest necessary permission set:

- `view_students`, `manage_students`
- `view_teachers`, `manage_teachers`
- `view_attendance`, `manage_attendance`
- `view_academics`, `manage_academics`
- `view_fees`, `manage_fees`
- `view_analytics`, `manage_analytics`
- `manage_classes`, `manage_school_settings`, `manage_access`, `view_audit_logs`

## Must-pass checks before real student data

- Apply both migrations to a dedicated NOOR AI database and confirm that the second migration completes without SQL errors.
- Test an authenticated Creator, Principal, Manager with least-privilege permissions, assigned teacher, another-school user, and anonymous request.
- Confirm that a teacher cannot load another school's students or an unassigned class by guessing UUIDs or calling API routes directly.
- Remove a class/subject assignment and retry API reads and writes without signing out. The request must be denied.
- Confirm duplicate attendance for one student/date cannot be created, direct updates are audited, future/holiday dates are denied, and unmarked students are not made present automatically.
- Confirm transfer/deactivation preserves historical attendance/results and that date-of-enrollment history is honored.
- Turn on MFA for Creator and Principal, secure account invitation/revocation, session expiry, rate limits, database backups and restore drills, data retention, incident response, privacy notice and audited exports.

## Analytics integrity

- Attendance rate uses present + late as attended and excludes approved excused leave from the denominator. “No data” is not 0%.
- Subject progress is calculated from saved marks divided by recorded maximum marks; it is not invented or predictive.
- Every school-level growth KPI must document formula, inclusion rule, denominator, cohort and reporting period before use.
- Never use one opaque score alone to make high-stakes decisions about a child.

## Verification status

A static source review and TypeScript syntax scan are run when packaging. A full dependency install, Next.js build, SQL migration execution, RLS integration test and persistence test require network access and a dedicated NOOR AI Supabase project; those steps are not claimed as passed in this package.