'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

interface AnalyticsSummaryProps {
  filters?: {
    startDate?: string
    endDate?: string
    classroomId?: string
    status?: 'PRESENT' | 'REJECTED' | 'ALL'
  }
}

interface Statistics {
  totalAttempts: number
  presentCount: number
  rejectedCount: number
  rejectionRate: number
}

export default function AnalyticsSummary({ filters }: AnalyticsSummaryProps) {
  const [stats, setStats] = useState<Statistics>({
    totalAttempts: 0,
    presentCount: 0,
    rejectedCount: 0,
    rejectionRate: 0,
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchStatistics()
  }, [filters])

  const fetchStatistics = async () => {
    setLoading(true)
    try {
      let query = supabase.from('attendance_logs').select('status', { count: 'exact' })

      // Apply filters
      if (filters?.startDate) {
        query = query.gte('timestamp', filters.startDate)
      }
      if (filters?.endDate) {
        query = query.lte('timestamp', filters.endDate)
      }
      if (filters?.classroomId) {
        query = query.eq('classroom_id', filters.classroomId)
      }
      if (filters?.status && filters.status !== 'ALL') {
        query = query.eq('status', filters.status)
      }

      const { data, count, error } = await query

      if (error) throw error

      const totalAttempts = count || 0
      const presentCount =
        data?.filter((record) => record.status === 'PRESENT').length || 0
      const rejectedCount =
        data?.filter((record) => record.status === 'REJECTED').length || 0
      const rejectionRate =
        totalAttempts > 0 ? (rejectedCount / totalAttempts) * 100 : 0

      setStats({
        totalAttempts,
        presentCount,
        rejectedCount,
        rejectionRate,
      })
    } catch (error) {
      console.error('Error fetching statistics:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className="bg-white rounded-lg shadow p-6 animate-pulse"
          >
            <div className="h-4 bg-gray-200 rounded w-1/2 mb-2"></div>
            <div className="h-8 bg-gray-200 rounded w-3/4"></div>
          </div>
        ))}
      </div>
    )
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
      {/* Total Attempts */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="text-sm text-gray-600 mb-1">Total Attempts</div>
        <div className="text-3xl font-bold text-gray-900">
          {stats.totalAttempts}
        </div>
      </div>

      {/* Present Count */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="text-sm text-gray-600 mb-1">Present</div>
        <div className="text-3xl font-bold text-green-600">
          {stats.presentCount}
        </div>
      </div>

      {/* Rejected Count */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="text-sm text-gray-600 mb-1">Rejected</div>
        <div className="text-3xl font-bold text-red-600">
          {stats.rejectedCount}
        </div>
      </div>

      {/* Rejection Rate */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="text-sm text-gray-600 mb-1">Rejection Rate</div>
        <div className="text-3xl font-bold text-orange-600">
          {stats.rejectionRate.toFixed(1)}%
        </div>
      </div>
    </div>
  )
}
