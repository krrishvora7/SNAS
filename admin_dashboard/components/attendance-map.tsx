'use client'

import { useEffect, useState } from 'react'
import dynamic from 'next/dynamic'
import { supabase } from '@/lib/supabase'
import { AttendanceLog } from '@/types/attendance'

// Dynamically import map components to avoid SSR issues
const MapContainer = dynamic(
  () => import('react-leaflet').then((mod) => mod.MapContainer),
  { ssr: false }
)
const TileLayer = dynamic(
  () => import('react-leaflet').then((mod) => mod.TileLayer),
  { ssr: false }
)
const Marker = dynamic(
  () => import('react-leaflet').then((mod) => mod.Marker),
  { ssr: false }
)
const Popup = dynamic(() => import('react-leaflet').then((mod) => mod.Popup), {
  ssr: false,
})
const Circle = dynamic(
  () => import('react-leaflet').then((mod) => mod.Circle),
  { ssr: false }
)

interface AttendanceMapProps {
  filters?: {
    startDate?: string
    endDate?: string
    classroomId?: string
    status?: 'PRESENT' | 'REJECTED' | 'ALL'
  }
}

interface Classroom {
  id: string
  name: string
  building: string
  latitude: number
  longitude: number
}

interface AttendancePoint {
  id: string
  student_name: string
  classroom_name: string
  timestamp: string
  status: 'PRESENT' | 'REJECTED'
  latitude: number
  longitude: number
  rejection_reason: string | null
}

export default function AttendanceMap({ filters }: AttendanceMapProps) {
  const [classrooms, setClassrooms] = useState<Classroom[]>([])
  const [attendancePoints, setAttendancePoints] = useState<AttendancePoint[]>(
    []
  )
  const [loading, setLoading] = useState(true)
  const [mapReady, setMapReady] = useState(false)

  useEffect(() => {
    // Ensure Leaflet CSS is loaded
    if (typeof window !== 'undefined') {
      import('leaflet/dist/leaflet.css')
      import('leaflet').then((L) => {
        // Fix default marker icon issue
        delete (L.Icon.Default.prototype as any)._getIconUrl
        L.Icon.Default.mergeOptions({
          iconRetinaUrl:
            'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
          iconUrl:
            'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
          shadowUrl:
            'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
        })
        setMapReady(true)
      })
    }
  }, [])

  useEffect(() => {
    if (mapReady) {
      fetchClassrooms()
      fetchAttendancePoints()
    }
  }, [mapReady, filters])

  const fetchClassrooms = async () => {
    try {
      const { data, error } = await supabase
        .from('classrooms')
        .select('id, name, building, location')

      if (error) throw error

      const formattedClassrooms: Classroom[] = (data || []).map(
        (classroom: any) => {
          // Parse PostGIS geography point
          const coords = parseGeography(classroom.location)
          return {
            id: classroom.id,
            name: classroom.name,
            building: classroom.building,
            latitude: coords.latitude,
            longitude: coords.longitude,
          }
        }
      )

      setClassrooms(formattedClassrooms)
    } catch (error) {
      console.error('Error fetching classrooms:', error)
    }
  }

  const fetchAttendancePoints = async () => {
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
          student_location,
          profiles!attendance_logs_student_id_fkey (
            full_name
          ),
          classrooms!attendance_logs_classroom_id_fkey (
            name
          )
        `
        )
        .order('timestamp', { ascending: false })
        .limit(100)

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

      const formattedPoints: AttendancePoint[] = (data || []).map(
        (record: any) => {
          const coords = parseGeography(record.student_location)
          return {
            id: record.id,
            student_name: record.profiles?.full_name || 'Unknown',
            classroom_name: record.classrooms?.name || 'Unknown',
            timestamp: record.timestamp,
            status: record.status,
            latitude: coords.latitude,
            longitude: coords.longitude,
            rejection_reason: record.rejection_reason,
          }
        }
      )

      setAttendancePoints(formattedPoints)
    } catch (error) {
      console.error('Error fetching attendance points:', error)
    } finally {
      setLoading(false)
    }
  }

  const parseGeography = (geography: any): { latitude: number; longitude: number } => {
    // PostGIS returns geography as GeoJSON or WKT
    // Handle both formats
    if (typeof geography === 'string') {
      // WKT format: "POINT(longitude latitude)"
      const match = geography.match(/POINT\(([^ ]+) ([^ ]+)\)/)
      if (match) {
        return {
          longitude: parseFloat(match[1]),
          latitude: parseFloat(match[2]),
        }
      }
    } else if (geography?.coordinates) {
      // GeoJSON format
      return {
        longitude: geography.coordinates[0],
        latitude: geography.coordinates[1],
      }
    }
    return { latitude: 0, longitude: 0 }
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

  if (!mapReady || loading) {
    return (
      <div className="bg-white rounded-lg shadow h-[600px] flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-2 text-gray-600">Loading map...</p>
        </div>
      </div>
    )
  }

  // Default center (use first classroom or default location)
  const center: [number, number] =
    classrooms.length > 0
      ? [classrooms[0].latitude, classrooms[0].longitude]
      : [0, 0]

  return (
    <div className="bg-white rounded-lg shadow h-[600px]">
      <div className="p-4 border-b">
        <h2 className="text-lg font-semibold">Attendance Map</h2>
      </div>
      <div className="h-[calc(100%-60px)]">
        <MapContainer
          center={center}
          zoom={15}
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />

          {/* Classroom markers with 50m radius circles */}
          {classrooms.map((classroom) => (
            <div key={classroom.id}>
              <Circle
                center={[classroom.latitude, classroom.longitude]}
                radius={50}
                pathOptions={{
                  color: 'blue',
                  fillColor: 'blue',
                  fillOpacity: 0.1,
                }}
              />
              <Marker position={[classroom.latitude, classroom.longitude]}>
                <Popup>
                  <div className="text-sm">
                    <div className="font-semibold">{classroom.name}</div>
                    <div className="text-gray-600">{classroom.building}</div>
                    <div className="text-xs text-gray-500 mt-1">
                      50m geofence radius
                    </div>
                  </div>
                </Popup>
              </Marker>
            </div>
          ))}

          {/* Student check-in points */}
          {attendancePoints.map((point) => (
            <Circle
              key={point.id}
              center={[point.latitude, point.longitude]}
              radius={5}
              pathOptions={{
                color: point.status === 'PRESENT' ? 'green' : 'red',
                fillColor: point.status === 'PRESENT' ? 'green' : 'red',
                fillOpacity: 0.6,
              }}
            >
              <Popup>
                <div className="text-sm">
                  <div className="font-semibold">{point.student_name}</div>
                  <div className="text-gray-600">{point.classroom_name}</div>
                  <div
                    className={`text-xs mt-1 ${
                      point.status === 'PRESENT'
                        ? 'text-green-600'
                        : 'text-red-600'
                    }`}
                  >
                    {point.status}
                  </div>
                  {point.rejection_reason && (
                    <div className="text-xs text-red-600">
                      {point.rejection_reason.replace(/_/g, ' ')}
                    </div>
                  )}
                  <div className="text-xs text-gray-500 mt-1">
                    {formatTimestamp(point.timestamp)}
                  </div>
                </div>
              </Popup>
            </Circle>
          ))}
        </MapContainer>
      </div>
    </div>
  )
}
