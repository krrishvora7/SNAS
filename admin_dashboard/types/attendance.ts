export interface AttendanceLog {
  id: string
  student_id: string
  classroom_id: string
  timestamp: string
  status: 'PRESENT' | 'REJECTED'
  student_location: {
    latitude: number
    longitude: number
  }
  rejection_reason: string | null
  student_name?: string
  classroom_name?: string
  building?: string
  classroom_location?: {
    latitude: number
    longitude: number
  }
}

export interface AttendanceFeedItem {
  id: string
  timestamp: string
  status: 'PRESENT' | 'REJECTED'
  student_name: string
  classroom_name: string
  building: string
  rejection_reason: string | null
}
