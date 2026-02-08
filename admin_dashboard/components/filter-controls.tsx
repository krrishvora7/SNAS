'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

interface FilterControlsProps {
  onFilterChange: (filters: {
    startDate?: string
    endDate?: string
    classroomId?: string
    status?: 'PRESENT' | 'REJECTED' | 'ALL'
  }) => void
}

interface Classroom {
  id: string
  name: string
  building: string
}

export default function FilterControls({ onFilterChange }: FilterControlsProps) {
  const [classrooms, setClassrooms] = useState<Classroom[]>([])
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [classroomId, setClassroomId] = useState('')
  const [status, setStatus] = useState<'PRESENT' | 'REJECTED' | 'ALL'>('ALL')

  useEffect(() => {
    fetchClassrooms()
    // Set default date range to today
    const today = new Date().toISOString().split('T')[0]
    setStartDate(today)
    setEndDate(today)
  }, [])

  useEffect(() => {
    // Notify parent of filter changes
    onFilterChange({
      startDate: startDate ? `${startDate}T00:00:00Z` : undefined,
      endDate: endDate ? `${endDate}T23:59:59Z` : undefined,
      classroomId: classroomId || undefined,
      status,
    })
  }, [startDate, endDate, classroomId, status])

  const fetchClassrooms = async () => {
    try {
      const { data, error } = await supabase
        .from('classrooms')
        .select('id, name, building')
        .order('name')

      if (error) throw error
      setClassrooms(data || [])
    } catch (error) {
      console.error('Error fetching classrooms:', error)
    }
  }

  const handleReset = () => {
    const today = new Date().toISOString().split('T')[0]
    setStartDate(today)
    setEndDate(today)
    setClassroomId('')
    setStatus('ALL')
  }

  return (
    <div className="bg-white rounded-lg shadow p-4">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold">Filters</h2>
        <button
          onClick={handleReset}
          className="text-sm text-blue-600 hover:text-blue-700"
        >
          Reset
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Start Date */}
        <div>
          <label
            htmlFor="startDate"
            className="block text-sm font-medium mb-1"
          >
            Start Date
          </label>
          <input
            id="startDate"
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        {/* End Date */}
        <div>
          <label htmlFor="endDate" className="block text-sm font-medium mb-1">
            End Date
          </label>
          <input
            id="endDate"
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        {/* Classroom Filter */}
        <div>
          <label
            htmlFor="classroom"
            className="block text-sm font-medium mb-1"
          >
            Classroom
          </label>
          <select
            id="classroom"
            value={classroomId}
            onChange={(e) => setClassroomId(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">All Classrooms</option>
            {classrooms.map((classroom) => (
              <option key={classroom.id} value={classroom.id}>
                {classroom.name} - {classroom.building}
              </option>
            ))}
          </select>
        </div>

        {/* Status Filter */}
        <div>
          <label htmlFor="status" className="block text-sm font-medium mb-1">
            Status
          </label>
          <select
            id="status"
            value={status}
            onChange={(e) =>
              setStatus(e.target.value as 'PRESENT' | 'REJECTED' | 'ALL')
            }
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="ALL">All Status</option>
            <option value="PRESENT">Present</option>
            <option value="REJECTED">Rejected</option>
          </select>
        </div>
      </div>
    </div>
  )
}
