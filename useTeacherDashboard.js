import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'

const day = () => new Date().toLocaleDateString('en-CA') // YYYY-MM-DD (local)
const to12 = (t) => {
  const [h, m] = t.split(':').map(Number)
  return `${String(((h + 11) % 12) + 1).padStart(2, '0')}:${String(m).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`
}
const clock = (iso) => new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
const ago = (iso) => {
  const m = Math.round((Date.now() - new Date(iso)) / 60000)
  if (m < 2) return 'Just now'
  if (m < 60) return `${m} mins ago`
  const h = Math.round(m / 60)
  if (h < 24) return `${h} hrs ago`
  return h < 48 ? 'Yesterday' : new Date(iso).toLocaleDateString([], { day: 'numeric', month: 'short' })
}
const periodStatus = (s, e) => {
  const now = new Date().toTimeString().slice(0, 8)
  return now < s ? 'Upcoming' : now <= e ? 'Ongoing' : 'Completed'
}
const parseClock = (txt) => {
  const m = /(\d{1,2}):(\d{2})\s*(AM|PM)?/i.exec(txt || '')
  if (!m) return null
  let h = +m[1]
  const ap = (m[3] || '').toUpperCase()
  if (ap === 'PM' && h < 12) h += 12
  if (ap === 'AM' && h === 12) h = 0
  const d = new Date()
  d.setHours(h, +m[2], 0, 0)
  return d.toISOString()
}
const isUuid = (v) => typeof v === 'string' && /^[0-9a-f-]{36}$/i.test(v)

/**
 * Drop-in replacement for useState(initialData).
 * Same data shape as the mock → UI stays identical. Without .env it just shows the demo data.
 * Returns [data, setData, api]
 */
export function useTeacherDashboard(initial) {
  const [data, setData] = useState(initial)
  const [meta, setMeta] = useState({ loading: !!supabase, error: null, schoolId: null })
  const ctx = useRef(null)
  const dataRef = useRef(data)
  dataRef.current = data
  const timers = useRef({})

  const load = useCallback(async () => {
    if (!supabase) return
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    const { data: me, error } = await supabase
      .from('staff').select('school_id, role, profile, schools(brand)').eq('id', user.id).maybeSingle()
    if (error || !me) {
      setMeta({ loading: false, schoolId: null, error: error?.message || 'No staff row for this user – run supabase/demo_data.sql' })
      return
    }
    const schoolId = me.school_id
    ctx.current = { uid: user.id, schoolId, role: me.role }
    const grade = me.profile?.assignedClass ?? initial.profile.assignedClass
    const section = me.profile?.assignedSection ?? initial.profile.assignedSection

    const [stu, att, chk, tt, nts, act, sc] = await Promise.all([
      supabase.from('students').select('id,name,roll').eq('school_id', schoolId).eq('grade', grade).eq('section', section).order('roll'),
      supabase.from('student_attendance').select('student_id,status,remarks').eq('school_id', schoolId).eq('date', day()),
      supabase.from('teacher_checkins').select('checked_in_at').eq('teacher_id', user.id).eq('date', day()).maybeSingle(),
      supabase.from('timetable').select('*').eq('teacher_id', user.id).order('position'),
      supabase.from('notices').select('*').eq('school_id', schoolId).eq('status', 'published').order('created_at', { ascending: false }).limit(10),
      supabase.from('activities').select('*').eq('school_id', schoolId).order('created_at', { ascending: false }).limit(10),
      supabase.from('subject_scores').select('*').eq('school_id', schoolId).eq('grade', grade).eq('section', section),
    ])
    const attBy = Object.fromEntries((att.data || []).map((a) => [a.student_id, a]))
    const grad = Object.fromEntries(initial.subjectsPerformance.map((s) => [s.name, s]))

    setData((prev) => ({
      ...prev,
      brand: { ...prev.brand, ...(me.schools?.brand || {}) },
      profile: { ...prev.profile, ...(me.profile || {}) },
      status: {
        ...prev.status,
        checkedInTime: chk.data ? clock(chk.data.checked_in_at) : '—',
        lastSynced: 'Just now',
      },
      students: (stu.data || []).map((s) => ({
        id: s.id, name: s.name, roll: s.roll,
        status: attBy[s.id]?.status || 'Present',
        remarks: attBy[s.id]?.remarks || '',
      })),
      timetable: (tt.data || []).map((r) => ({
        id: r.id, period: r.period, subject: r.subject, classSec: r.class_sec,
        time: `${to12(r.start_time)} – ${to12(r.end_time)}`,
        status: periodStatus(r.start_time, r.end_time),
        color: r.color || 'bg-pink-100 text-pink-600',
        _start: r.start_time, _end: r.end_time,
      })),
      notices: (nts.data || []).map((n) => ({ id: n.id, title: n.title, desc: n.body, category: n.category, date: ago(n.created_at) })),
      activities: (act.data || []).map((a) => ({ id: a.id, title: a.title, sub: a.sub, type: a.type, time: clock(a.created_at), rel: ago(a.created_at) })),
      subjectsPerformance: (sc.data || []).map((r) => ({
        name: r.subject, short: grad[r.subject]?.short || r.subject, score: r.score,
        gradient: grad[r.subject]?.gradient || 'from-pink-500 to-rose-400',
      })),
    }))
    setMeta({ loading: false, error: null, schoolId })
  }, [initial])

  useEffect(() => {
    if (!supabase) return
    load()
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => s && load())
    return () => sub.subscription.unsubscribe()
  }, [load])

  // Realtime: attendance / notices / activity changes show up instantly (RLS still applies)
  useEffect(() => {
    if (!supabase || !meta.schoolId) return
    let t
    const refresh = () => { clearTimeout(t); t = setTimeout(load, 400) }
    const ch = supabase.channel(`dash-${meta.schoolId}`)
    for (const table of ['student_attendance', 'notices', 'activities', 'teacher_checkins'])
      ch.on('postgres_changes', { event: '*', schema: 'public', table, filter: `school_id=eq.${meta.schoolId}` }, refresh)
    ch.subscribe()
    return () => { clearTimeout(t); supabase.removeChannel(ch) }
  }, [meta.schoolId, load])

  const api = useMemo(() => {
    const later = (key, fn, ms = 500) => { clearTimeout(timers.current[key]); timers.current[key] = setTimeout(fn, ms) }
    const log = (title, sub, type) =>
      supabase.from('activities').insert({ school_id: ctx.current.schoolId, teacher_id: ctx.current.uid, title, sub, type })

    return {
      ...meta,
      refresh: load,
      signOut: () => supabase?.auth.signOut(),

      // Called from updateField(path, value) – routes every inline edit to the right table
      async save(path, value) {
        if (!supabase || !ctx.current) return
        const { uid, schoolId } = ctx.current
        const [root, field] = path.split('.')
        const p = dataRef.current.profile
        if (root === 'profile') later('profile', () => supabase.from('staff').update({ profile: dataRef.current.profile }).eq('id', uid))
        else if (root === 'brand') later('brand', () => supabase.from('schools').update({ brand: dataRef.current.brand }).eq('id', schoolId))
        else if (root === 'status' && field === 'checkedInTime') {
          const iso = parseClock(value)
          if (iso) await supabase.from('teacher_checkins').upsert({ school_id: schoolId, teacher_id: uid, date: day(), checked_in_at: iso }, { onConflict: 'teacher_id,date' })
        } else if (root === 'timetable') {
          await supabase.from('timetable').upsert(value.filter((r) => typeof r.id === 'number').map((r, i) => ({
            id: r.id, school_id: schoolId, teacher_id: uid, position: i,
            period: r.period, subject: r.subject, class_sec: r.classSec, start_time: r._start, end_time: r._end,
          })))
        } else if (root === 'subjectsPerformance') {
          await supabase.from('subject_scores').upsert(
            value.map((s) => ({ school_id: schoolId, grade: p.assignedClass, section: p.assignedSection, subject: s.name, score: s.score })),
            { onConflict: 'school_id,grade,section,subject' })
        } else if (root === 'students') {
          const old = dataRef.current.students
          const renamed = value.filter((s) => isUuid(s.id) && old.find((o) => o.id === s.id)?.name !== s.name)
          if (renamed.length) await supabase.from('students').upsert(
            renamed.map((s) => ({ id: s.id, school_id: schoolId, grade: p.assignedClass, section: p.assignedSection, name: s.name, roll: s.roll })))
        }
      },

      async submitAttendance(students) {
        if (!supabase || !ctx.current) return
        const { uid, schoolId } = ctx.current
        const p = dataRef.current.profile
        await supabase.from('student_attendance').upsert(
          students.filter((s) => isUuid(s.id)).map((s) => ({
            school_id: schoolId, student_id: s.id, date: day(), status: s.status, remarks: s.remarks || '', marked_by: uid,
          })),
          { onConflict: 'student_id,date' })
        await log('You marked attendance', `Class ${p.assignedClass} – Section ${p.assignedSection}`, 'attendance')
      },

      async publishNotice(notice, form) {
        if (!supabase || !ctx.current) return
        const { uid, schoolId } = ctx.current
        await supabase.from('notices').insert({
          school_id: schoolId, author_id: uid, title: notice.title, body: notice.desc,
          audience: form.audience, category: form.category,
          requires_approval: !!form.requiresApproval, status: form.requiresApproval ? 'pending' : 'published',
        })
        await log('New notice published', `${notice.title} (${form.audience})`, 'notice')
      },

      async uploadPhoto(file) {
        if (!supabase || !ctx.current) {
          return new Promise((res) => { const r = new FileReader(); r.onload = () => res(r.result); r.readAsDataURL(file) })
        }
        const ext = (file.name.split('.').pop() || 'jpg').toLowerCase()
        const path = `${ctx.current.uid}/profile-${Date.now()}.${ext}`
        const { error } = await supabase.storage.from('avatars').upload(path, file, { contentType: file.type })
        if (error) throw error
        return supabase.storage.from('avatars').getPublicUrl(path).data.publicUrl
      },
    }
  }, [meta, load])

  return [data, setData, api]
}
