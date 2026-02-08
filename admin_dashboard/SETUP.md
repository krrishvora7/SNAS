# Admin Dashboard Setup Guide

## Prerequisites

- Node.js 18+ installed
- npm or yarn package manager
- Supabase project with the SNAS database schema

## Installation Steps

### 1. Install Dependencies

Navigate to the admin_dashboard directory and install dependencies:

```bash
cd admin_dashboard
npm install
```

### 2. Configure Environment Variables

Create a `.env.local` file in the admin_dashboard directory:

```bash
cp .env.local.example .env.local
```

Edit `.env.local` and add your Supabase credentials:

```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

You can find these values in your Supabase project settings under API.

### 3. Run Development Server

```bash
npm run dev
```

The dashboard will be available at [http://localhost:3000](http://localhost:3000)

### 4. Login

Use your Supabase admin credentials to log in to the dashboard.

## Features Implemented

### ✅ Task 13.1: Project Setup
- Next.js 14 with TypeScript
- Tailwind CSS for styling
- Supabase client library
- Authentication context for admin users
- Environment variable configuration

### ✅ Task 13.2: Real-time Attendance Feed
- Subscribes to attendance_logs table changes
- Displays recent check-ins in a list
- Color-coded by status (green for PRESENT, red for REJECTED)
- Shows student name, classroom, timestamp, and rejection reason

### ✅ Task 13.3: Map Visualization
- Leaflet integration for map rendering
- Displays classroom locations as markers
- Shows recent student check-in points
- Draws 50m radius circles around classrooms
- Tooltips with classroom and student information

### ✅ Task 13.4: Filter Controls and Analytics
- Date range picker (start and end date)
- Classroom dropdown filter
- Status filter (PRESENT/REJECTED/ALL)
- Summary statistics:
  - Total attendance attempts
  - Present count
  - Rejected count
  - Rejection rate percentage
- Real-time updates when filters change

## Project Structure

```
admin_dashboard/
├── app/                      # Next.js App Router pages
│   ├── dashboard/           # Main dashboard page
│   ├── login/               # Login page
│   ├── globals.css          # Global styles
│   ├── layout.tsx           # Root layout with AuthProvider
│   └── page.tsx             # Home page (redirects)
├── components/              # React components
│   ├── analytics-summary.tsx    # Statistics cards
│   ├── attendance-feed.tsx      # Real-time feed list
│   ├── attendance-map.tsx       # Leaflet map component
│   └── filter-controls.tsx      # Filter form
├── lib/                     # Utilities and configurations
│   ├── auth-context.tsx     # Authentication context
│   └── supabase.ts          # Supabase client
├── types/                   # TypeScript type definitions
│   └── attendance.ts        # Attendance data types
├── .env.local.example       # Environment variables template
├── package.json             # Dependencies
├── tsconfig.json            # TypeScript configuration
├── tailwind.config.ts       # Tailwind CSS configuration
└── next.config.js           # Next.js configuration
```

## Building for Production

```bash
npm run build
npm start
```

## Troubleshooting

### Map not displaying
- Ensure Leaflet CSS is loaded (already configured in the component)
- Check browser console for errors
- Verify classroom data has valid geography coordinates

### Real-time updates not working
- Verify Supabase Realtime is enabled for the attendance_logs table
- Check that RLS policies allow the admin user to read attendance data
- Ensure the Supabase connection is active

### Authentication issues
- Verify environment variables are set correctly
- Check that the admin user exists in Supabase Auth
- Ensure RLS policies allow authenticated users to access data

## Next Steps

To deploy the dashboard:

1. **Vercel** (recommended for Next.js):
   - Connect your repository to Vercel
   - Add environment variables in Vercel dashboard
   - Deploy automatically on push

2. **Other platforms**:
   - Build the project: `npm run build`
   - Deploy the `.next` folder and `package.json`
   - Set environment variables on the platform

## Requirements Validation

This implementation satisfies:
- **Requirement 8.1**: Web-based admin dashboard with authentication
- **Requirement 8.2**: Real-time attendance data display
- **Requirement 8.3**: Map visualization with classroom locations
- **Requirement 8.4**: Automatic updates when attendance is marked
- **Requirement 8.5**: Filtering by date, classroom, and status
