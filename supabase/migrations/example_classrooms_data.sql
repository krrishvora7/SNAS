-- Example data for classrooms table
-- This file demonstrates how to insert classroom records with geographic locations

-- Note: These are example coordinates. Replace with actual classroom locations.

-- Example 1: Engineering Building, Room 301
-- Location: San Francisco, CA (example coordinates)
INSERT INTO classrooms (name, building, location, nfc_secret)
VALUES (
  'Room 301',
  'Engineering Building',
  ST_GeogFromText('POINT(-122.4194 37.7749)'),
  'eng301_secret_a1b2c3d4e5f6'
);

-- Example 2: Science Building, Lab 205
-- Location: Nearby location (50 meters away for testing)
INSERT INTO classrooms (name, building, location, nfc_secret)
VALUES (
  'Lab 205',
  'Science Building',
  ST_GeogFromText('POINT(-122.4190 37.7750)'),
  'sci205_secret_g7h8i9j0k1l2'
);

-- Example 3: Library, Study Room A
-- Location: Another nearby location
INSERT INTO classrooms (name, building, location, nfc_secret)
VALUES (
  'Study Room A',
  'Library',
  ST_GeogFromText('POINT(-122.4200 37.7745)'),
  'lib_studyA_secret_m3n4o5p6'
);

-- Query to verify the inserted data
SELECT 
  id,
  name,
  building,
  ST_AsText(location::geometry) AS location_text,
  ST_Y(location::geometry) AS latitude,
  ST_X(location::geometry) AS longitude,
  nfc_secret,
  created_at
FROM classrooms
ORDER BY created_at DESC;

-- Query to calculate distances between classrooms
SELECT 
  c1.name AS classroom1,
  c2.name AS classroom2,
  ROUND(ST_Distance(c1.location, c2.location)::numeric, 2) AS distance_meters
FROM classrooms c1
CROSS JOIN classrooms c2
WHERE c1.id < c2.id
ORDER BY distance_meters;
