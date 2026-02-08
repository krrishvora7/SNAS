# mark_attendance Validation Flow

This document illustrates the complete validation flow in the `mark_attendance` function after implementing Tasks 3.1, 3.2, and 3.3.

## Validation Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    mark_attendance()                         │
│  Parameters: classroom_id, secret_token, latitude, longitude │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              STEP 1: INPUT VALIDATION (Task 3.1)             │
├─────────────────────────────────────────────────────────────┤
│  ✓ Check all parameters are not NULL                        │
│  ✓ Check user is authenticated (auth.uid() exists)          │
│  ✓ Validate latitude range: -90 to 90                       │
│  ✓ Validate longitude range: -180 to 180                    │
│  ✓ Validate secret_token is not empty string                │
│  ✓ Create geography point from coordinates                  │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │  All Valid?   │
                    └───────┬───────┘
                            │ YES
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         STEP 2: DEVICE BINDING VERIFICATION (Task 3.2)       │
├─────────────────────────────────────────────────────────────┤
│  1. Query profiles table for user's stored device_id        │
│  2. Extract device_id from JWT claims                       │
│  3. Compare stored device_id with current device_id         │
│                                                              │
│  Rejection Reasons:                                          │
│    • profile_not_found: User profile doesn't exist          │
│    • device_mismatch: Device IDs don't match                │
│    • device_id_missing: No device_id in JWT                 │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │  Device OK?   │
                    └───────┬───────┘
                            │ YES
                            ▼
┌─────────────────────────────────────────────────────────────┐
│          STEP 3: SECRET TOKEN VALIDATION (Task 3.3) ✅       │
├─────────────────────────────────────────────────────────────┤
│  1. Query classrooms table for classroom_id                 │
│  2. Retrieve stored nfc_secret                              │
│  3. Compare provided secret_token with nfc_secret           │
│                                                              │
│  Rejection Reasons:                                          │
│    • classroom_not_found: Classroom doesn't exist           │
│    • invalid_token: Secret tokens don't match               │
│                                                              │
│  Security Features:                                          │
│    ✓ Case-sensitive comparison                              │
│    ✓ Exact match required (no trimming)                     │
│    ✓ No token leakage in error messages                     │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │  Token OK?    │
                    └───────┬───────┘
                            │ YES
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         STEP 4: GEOFENCE VALIDATION (Task 3.4) 🔜           │
├─────────────────────────────────────────────────────────────┤
│  1. Calculate distance between student and classroom        │
│  2. Check if distance <= 50 meters                          │
│                                                              │
│  Rejection Reasons:                                          │
│    • outside_geofence: Distance > 50 meters                 │
│                                                              │
│  Status: TO BE IMPLEMENTED                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │ Within Range? │
                    └───────┬───────┘
                            │ YES
                            ▼
┌─────────────────────────────────────────────────────────────┐
│            STEP 5: ATTENDANCE LOGGING (Task 3.5)             │
├─────────────────────────────────────────────────────────────┤
│  1. Insert record into attendance_logs table                │
│  2. Set status: PRESENT or REJECTED                         │
│  3. Set rejection_reason if applicable                      │
│  4. Store student_location (geography point)                │
│  5. Record timestamp                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    RETURN JSON RESPONSE                      │
├─────────────────────────────────────────────────────────────┤
│  {                                                           │
│    "status": "PRESENT" | "REJECTED",                        │
│    "rejection_reason": null | "reason_code",                │
│    "timestamp": "2024-01-15T10:30:00Z"                      │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
```

## Validation Order Rationale

The validations are performed in a specific order for security and performance:

1. **Input Validation First**: Prevents invalid data from entering the system
2. **Device Binding Second**: Prevents unauthorized devices early (before database queries)
3. **Secret Token Third**: Validates NFC tag authenticity (requires classroom lookup)
4. **Geofence Last**: Most expensive operation (PostGIS distance calculation)

This ordering ensures:
- Fast rejection of obviously invalid requests
- Minimal database queries for unauthorized requests
- Expensive operations only for validated requests

## Rejection Reason Codes

| Code | Step | Description |
|------|------|-------------|
| `profile_not_found` | Device Binding | User profile doesn't exist in database |
| `device_mismatch` | Device Binding | Request from different device than bound |
| `device_id_missing` | Device Binding | No device_id in JWT claims |
| `classroom_not_found` | Secret Token | Classroom ID doesn't exist |
| `invalid_token` | Secret Token | Secret token doesn't match classroom |
| `outside_geofence` | Geofence | Student location > 50m from classroom |

## Example Scenarios

### Scenario 1: Successful Attendance
```
Input:
  classroom_id: valid UUID
  secret_token: correct token
  latitude: 37.7749 (within 50m of classroom)
  longitude: -122.4194

Flow:
  ✓ Input validation passes
  ✓ Device binding passes
  ✓ Secret token matches
  ✓ Within geofence (when implemented)

Result:
  {
    "status": "PRESENT",
    "rejection_reason": null,
    "timestamp": "2024-01-15T10:30:00Z"
  }
```

### Scenario 2: Invalid Secret Token
```
Input:
  classroom_id: valid UUID
  secret_token: wrong_token_123
  latitude: 37.7749
  longitude: -122.4194

Flow:
  ✓ Input validation passes
  ✓ Device binding passes
  ✗ Secret token doesn't match

Result:
  {
    "status": "REJECTED",
    "rejection_reason": "invalid_token",
    "timestamp": "2024-01-15T10:30:00Z"
  }
```

### Scenario 3: Device Mismatch (Early Rejection)
```
Input:
  classroom_id: valid UUID
  secret_token: correct token
  latitude: 37.7749
  longitude: -122.4194
  device_id: different_device

Flow:
  ✓ Input validation passes
  ✗ Device binding fails
  (Secret token validation skipped)
  (Geofence validation skipped)

Result:
  {
    "status": "REJECTED",
    "rejection_reason": "device_mismatch",
    "timestamp": "2024-01-15T10:30:00Z"
  }
```

### Scenario 4: Non-existent Classroom
```
Input:
  classroom_id: 99999999-9999-9999-9999-999999999999 (doesn't exist)
  secret_token: any_token
  latitude: 37.7749
  longitude: -122.4194

Flow:
  ✓ Input validation passes
  ✓ Device binding passes
  ✗ Classroom not found

Result:
  {
    "status": "REJECTED",
    "rejection_reason": "classroom_not_found",
    "timestamp": "2024-01-15T10:30:00Z"
  }
```

## Performance Characteristics

| Step | Operation | Estimated Time |
|------|-----------|----------------|
| Input Validation | In-memory checks | < 1ms |
| Device Binding | Single SELECT query | 5-10ms |
| Secret Token | Single SELECT query | 5-10ms |
| Geofence | PostGIS distance calc | 10-20ms |
| Logging | Single INSERT | 5-10ms |
| **Total** | | **< 50ms** |

Target: < 200ms (Requirement 5.5) ✅

## Security Features

1. **SECURITY DEFINER**: Function runs with elevated privileges to bypass RLS
2. **Parameterized Queries**: All queries use parameters (no SQL injection)
3. **No Token Leakage**: Error messages don't reveal correct tokens
4. **Validation Ordering**: Expensive operations only for authorized requests
5. **Immutable Logs**: All attempts logged (audit trail)
6. **Case-Sensitive Tokens**: Prevents case-variation attacks

## Next Steps

- [ ] Implement Task 3.4: Geofence validation with PostGIS
- [ ] Implement Task 3.5: Complete attendance logging logic
- [ ] Write property-based tests for all validation steps
- [ ] Performance testing with concurrent requests

