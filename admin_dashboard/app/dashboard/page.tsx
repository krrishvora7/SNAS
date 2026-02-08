'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/lib/auth-context'
import FilterControls from '@/components/filter-controls'
import AnalyticsSummary from '@/components/analytics-summary'
import AttendanceFeed from '@/components/attendance-feed'
import AttendanceMap from '@/components/attendance-map'

export default function DashboardPage() {
  const { user, loading, signOut } = useAuth()
  const router = useRouter()
  const [filters, setFilters] = useState<{
    startDate?: string
    endDate?: string
    classroomId?: string
    status?: 'PRESENT' | 'REJECTED' | 'ALL'
  }>({})

  useEffect(() => {
    if (!loading && !user) {
      router.push('/login')
    }
  }, [user, loading, router])

  const handleSignOut = async () => {
    try {
      await signOut()
      router.push('/login')
    } catch (error) {
      console.error('Error signing out:', error)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    )
  }

  if (!user) {
    return null
  }

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                SNAS Admin Dashboard
              </h1>
              <p className="text-sm text-gray-600">
                Smart NFC Attendance System
              </p>
            </div>
            <div className="flex items-center gap-4">
              <span className="text-sm text-gray-600">{user.email}</span>
              <button
                onClick={handleSignOut}
                className="px-4 py-2 text-sm bg-gray-200 hover:bg-gray-300 rounded-md transition-colors"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="space-y-6">
          {/* Filters */}
          <FilterControls onFilterChange={setFilters} />

          {/* Analytics Summary */}
          <AnalyticsSummary filters={filters} />

          {/* Map and Feed Grid */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Map - Takes 2 columns */}
            <div className="lg:col-span-2">
              <AttendanceMap filters={filters} />
            </div>

            {/* Feed - Takes 1 column */}
            <div className="lg:col-span-1">
              <AttendanceFeed filters={filters} />
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
