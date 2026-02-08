'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { AttendanceFeedItem } from '@/types/attendance'

interface AttendanceFeedProps {
  filters?: {
    startDate?: string
    endDate?: string
    classroomId?: string
    status?: 'PRESENT' | 'REJECTED' | 'ALL'
  }
}

export default function AttendanceFeed({ filters }: AttendanceFeedProps) {
  const [attendanceRecords, setAttendanceRecords] = useState<
    AttendanceFeedItem[]
  >([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchAttendance()
    subscribeToAttendance()
  }, [filters])

  const fetchAttendance = async () => {
    setLoading(true)
    try {
      let query = supabase
        .from('attendance_logs')
        .select(
          `
          id,
          timestamp,
          status,
          rejection_reason,
          profiles!attendance_logs_student_id_fkey (
            full_name
          ),
          classrooms!attendance_logs_classroom_id_fkey (
            name,
            building
          )
        `
        )
        .order('timestamp', { ascending: false })
        .limit(50)

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

      const { data, error } = await query

      if (error) throw error

      const formattedData: AttendanceFeedItem[] = (data || []).map(
        (record: any) => ({
          id: record.id,
          timestamp: record.timestamp,
          status: record.status,
          student_name: record.profiles?.full_name || 'Unknown',
          classroom_name: record.classrooms?.name || 'Unknown',
          building: record.classrooms?.building || 'Unknown',
          rejection_reason: record.rejection_reason,
        })
      )

      setAttendanceRecords(formattedData)
    } catch (error) {
      console.error('Error fetching attendance:', error)
    } finally {
      setLoading(false)
    }
  }

  const subscribeToAttendance = () => {
    const channel = supabase
      .channel('attendance_changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'attendance_logs',
        },
        async (payload) => {
          // Fetch the complete record with joined data
          const { data } = await supabase
            .from('attendance_logs')
            .select(
              `
              id,
              timestamp,
              status,
              rejection_reason,
              profiles!attendance_logs_student_id_fkey (
                full_name
              ),
              classrooms!attendance_logs_classroom_id_fkey (
                name,
                building
              )
            `
            )
            .eq('id', payload.new.id)
            .single()

          if (data) {
            const newRecord: AttendanceFeedItem = {
              id: data.id,
              timestamp: data.timestamp,
              status: data.status,
              student_name: (data.profiles as any)?.full_name || 'Unknown',
              classroom_name: (data.classrooms as any)?.name || 'Unknown',
              building: (data.classrooms as any)?.building || 'Unknown',
              rejection_reason: data.rejection_reason,
            }

            setAttendanceRecords((prev) => [newRecord, ...prev].slice(0, 50))
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp)
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  return (
    <div className="bg-white rounded-lg shadow">
      <div className="p-4 border-b">
        <h2 className="text-lg font-semibold">Recent Attendance</h2>
      </div>
      <div className="divide-y max-h-[600px] overflow-y-auto">
        {attendanceRecords.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            No attendance records found
          </div>
        ) : (
          attendanceRecords.map((record) => (
            <div
              key={record.id}
              className={`p-4 hover:bg-gray-50 transition-colors ${
                record.status === 'PRESENT'
                  ? 'border-l-4 border-green-500'
                  : 'border-l-4 border-red-500'
              }`}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span
                      className={`inline-block w-2 h-2 rounded-full ${
                        record.status === 'PRESENT'
                          ? 'bg-green-500'
                          : 'bg-red-500'
                      }`}
                    ></span>
                    <span className="font-medium">{record.student_name}</span>
                  </div>
                  <div className="mt-1 text-sm text-gray-600">
                    {record.classroom_name} • {record.building}
                  </div>
                  {record.rejection_reason && (
                    <div className="mt-1 text-sm text-red-600">
                      Rejected: {record.rejection_reason.replace(/_/g, ' ')}
                    </div>
                  )}
                </div>
                <div className="text-sm text-gray-500">
                  {formatTimestamp(record.timestamp)}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
