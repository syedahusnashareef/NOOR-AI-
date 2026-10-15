# NOOR AI Task 2 — Classroom QA checklist

**Status:** prepared for execution. This checklist has not yet been run against a dedicated live NOOR AI Supabase project.

## Setup / role boundaries

- [ ] Run migrations `001_initial_schema.sql`, then `002_teacher_classroom.sql` against a dedicated NOOR AI project.
- [ ] Create school A and school B, one Principal on each, one least-privileged Manager, and two teacher Auth accounts.
- [ ] Create active Teacher A profile and link its `user_id` to Teacher A's Auth UUID. Assign Teacher A to Class 8-A and English only.
- [ ] Sign in as Teacher A: only assigned school, Class 8-A, English subject and authorized class work/tests appear.
- [ ] Attempt to open an unassigned class by guessing its UUID, using `/api/teacher/attendance`, `/api/teacher/progress` and `/api/teacher/students`. Expected: 403/404, no rows disclosed.
- [ ] Attempt to request a student or class from school B. Expected: no data, even with a valid UUID.
- [ ] Revoke Teacher A’s class assignment while Teacher A remains signed in. Re-attempt API access without refreshing auth. Expected: denied immediately.
- [ ] Confirm a Manager without `manage_students` cannot create/update/transfer/deactivate students, and without `manage_school_settings` cannot change the calendar/enrollment policy.

## Assignment persistence and dashboard

- [ ] Assign Teacher A as class teacher of Class 8-A. Verify the “My Class” tile appears after sign in.
- [ ] Sign out and sign in again. Verify the same class appears from persisted DB assignment without selecting it manually.
- [ ] Assign Teacher A a second class. Verify both classes are available by one tap.
- [ ] Assign a second subject only in one class. Verify academic rows outside that class/subject are not disclosed.
- [ ] Add a teacher profile photo and username; verify profile displays correctly.

## Attendance

- [ ] Add students with roll numbers `01`, `02`, `10`; verify numeric-aware order is `01`, `02`, `10`.
- [ ] Open a fresh date. Confirm all rows start **unmarked**, never automatically present.
- [ ] Mark a subset and Save. Confirm totals match the submitted marks and remaining rows stay unmarked after a refresh.
- [ ] Mark the remaining rows and save. Sign out/in; verify attendance persists.
- [ ] Change an existing status and save. Verify one attendance row remains per student/date and an audit row records old and new status/actor.
- [ ] Submit the same student twice in one payload and attempt to insert a duplicate student/date directly. Expected: rejected or atomically prevented; never two records.
- [ ] Attempt to save a future date or a date set as `is_school_day = false`. Expected: rejected in the database RPC.
- [ ] Approve leave for a student, then mark `excused`; confirm it works only with approved leave for that date/class.
- [ ] Attempt `excused` without approved leave. Expected: rejected by database, not only the UI.
- [ ] Edit unsaved statuses then try to refresh, change date, go back, sign out, or close tab. Expected: unsaved-change warning.

## Enrollment and historical data

- [ ] Leave direct teacher enrollment disabled. Teacher submits an enrollment request; confirm no student record is created before management approval.
- [ ] Approve request as management; confirm exactly one student record is created, profile photo (if given) is retained, and enrollment history appears.
- [ ] Submit a duplicate admission/roll number. Expected: unique-constraint rejection.
- [ ] Enable direct teacher enrollment by school policy; teacher can add a student only to an assigned class. Revoke assignment and confirm this is denied.
- [ ] Edit student details and profile photo. Confirm changes persist.
- [ ] Transfer a student to another active class. Confirm past attendance/marks stay attached to the student and old/new enrollment dates are recorded.
- [ ] Attempt to transfer to an inactive or another-school class. Expected: rejected.
- [ ] Deactivate a student. Confirm it disappears from active attendance roster but old marks, attendance and history remain available to authorized management.

## Student progress / actual data only

- [ ] Add a real assessment and result through an authorized data-entry workflow. Confirm subject, test date, marks/max marks and feedback appear in View Progress.
- [ ] Confirm attendance percentage uses recorded present + late over present + late + absent, excluding approved excused leave.
- [ ] With no attendance/marks, confirm UI says no data rather than showing fake 0% or placeholder marks.
- [ ] Confirm a teacher can view progress only for active students in their assigned class and only authorized subject assessments.

## Final acceptance

- [ ] All database operations persist after page reload and re-login.
- [ ] RLS/security advisor issues are reviewed and fixed.
- [ ] Migration application, Next production build, browser flow, RLS boundary test and audit-trail check are documented before any real student PII is entered.