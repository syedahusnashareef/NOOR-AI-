# Noor – Teacher Dashboard (React + Vite + Tailwind + Supabase)

## 1. Add your component
Copy your `TeacherDashboard.jsx` to `src/components/TeacherDashboard.jsx`, then make these 6 small edits:

| # | Find | Replace / add |
|---|------|---------------|
| 1 | `import React, { useState } from 'react';` | add below it: `import { useTeacherDashboard } from '../hooks/useTeacherDashboard';` |
| 2 | `const [data, setData] = useState(initialData);` | `const [data, setData, api] = useTeacherDashboard(initialData);` |
| 3 | in `updateField`, just before `triggerToast("Saved change! Click Undo to revert.");` | add `api.save(path, value);` |
| 4 | in `handlePhotoUpload`, the whole `const reader = new FileReader(); … reader.readAsDataURL(file);` block | `api.uploadPhoto(file).then((url) => updateField("profile.photoUrl", url));` |
| 5 | Submit Attendance button `onClick`, before `setActiveModal(null);` | add `api.submitAttendance(data.students);` |
| 6 | in `handlePublishNotice`, right after the `setData((prev) => ({ ... }));` block | add `api.publishNotice(newNotice, noticeForm);` |

## 2. Supabase
1. Create a project at supabase.com.
2. SQL Editor → paste `supabase/migrations/20261022000000_teacher_dashboard.sql` → Run.
3. Authentication → Users → Add user (Auto Confirm ON). Then run `supabase/demo_data.sql` (edit the email first).
4. Project Settings → API → copy URL + publishable (anon) key into `.env` (see `.env.example`). Never use the service_role key in this app.

## 3. GitHub ↔ Supabase (auto-deploy migrations)
1. Push this folder to a GitHub repo (`main`).
2. Supabase Dashboard → Project → Integrations → GitHub → connect the repo, set the Supabase directory to `supabase`, production branch `main`, turn on deploy-to-production.
3. From now on, every new file in `supabase/migrations/` that you merge to `main` is applied to your database automatically.

## 4. Run
```
npm install
npm run dev
```
Without `.env` the app runs in demo mode (mock data). With `.env` it shows a login and uses live data + realtime.
Hosting (Vercel/Netlify): add the same two `VITE_` env vars there.
