import React from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import AuthGate from './components/AuthGate'
import TeacherDashboard from './components/TeacherDashboard'

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <AuthGate>
      <TeacherDashboard />
    </AuthGate>
  </React.StrictMode>
)
