# SNAS Admin Dashboard

Admin dashboard for the Smart NFC Attendance System (SNAS).

## Features

- Real-time attendance monitoring
- Map visualization of classroom locations and student check-ins
- Filtering by date, classroom, and status
- Summary statistics and analytics

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env.local` file with your Supabase credentials:
```
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
```

3. Run the development server:
```bash
npm run dev
```

4. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Authentication

Admin users must authenticate with their Supabase credentials to access the dashboard.

## Technology Stack

- **Next.js 14** - React framework with App Router
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **Supabase** - Backend and real-time subscriptions
- **Leaflet** - Map visualization
- **React Leaflet** - React bindings for Leaflet
