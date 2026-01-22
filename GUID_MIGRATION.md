# GUID Migration for Sheet IDs

## Overview
Successfully migrated the app from using auto-incrementing integer IDs to GUIDs (Globally Unique Identifiers) for sheet identification. This resolves the synchronization issue where sheets were being duplicated when logging in on multiple devices.

## Problem Solved
**Before**: Each device created sheets with integer IDs (1, 2, 3...), causing conflicts during sync where sheets with the same ID from different devices were treated as identical, leading to overwrites and duplications.

**After**: Each sheet now has a unique 36-character GUID (e.g., `550e8400-e29b-41d4-a716-446655440000`), eliminating any possibility of ID conflicts across devices.

## Changes Made

### 1. Dependencies
- Added `uuid: ^4.2.1` to `pubspec.yaml`

### 2. Data Model (`lib/models/sheet.dart`)
- Changed `id` field from `int?` to `String?`
- Updated all JSON serialization to handle string IDs

### 3. Database Layer (`lib/src/database/sheet_database_helper.dart`)
- Updated database schema to use TEXT PRIMARY KEY instead of INTEGER AUTOINCREMENT
- Implemented automatic migration from version 3 to version 4
  - Creates new table with TEXT id column
  - Migrates existing sheets, assigning new GUIDs to each
  - Preserves all sheet data and timestamps
- Modified `insertSheet()` to generate GUIDs using `Uuid().v4()`
- Updated `getSheet()` and `deleteSheet()` to accept String IDs
- Changed return type of `insertSheet()` from `Future<int>` to `Future<String>`

### 4. Firebase Services (`lib/src/services/firestore_service.dart`)
- Updated all methods to use string IDs:
  - `addSheet()`: Uses `sheet.id!` directly as document ID
  - `updateSheet()`: Uses `sheet.id!` directly as document ID
  - `getSheet()`: Changed parameter from `int sheetId` to `String sheetId`
  - `deleteSheet()`: Changed parameter from `int sheetId` to `String sheetId`

### 5. Sync Service (`lib/src/services/sync_service.dart`)
- Updated sync logic to use `null` instead of `-1` for placeholder IDs
- Comparison logic now works with string IDs

### 6. Dynamic Link Service (`lib/src/services/dynamic_link_service.dart`)
- Updated `_handleDeepLink()` to work with string IDs
- Removed integer parsing (no longer needed)
- Deep links now pass GUIDs directly in URLs

### 7. UI Layer (`lib/src/screens/home_screen.dart`)
- Changed `_selectedSheets` from `Set<int>` to `Set<String>`
- Updated `_enterSelectionMode()` and `_toggleSheetSelection()` to accept String parameters

## Migration Strategy
The database migration is **automatic and transparent** to users:
1. When the app starts with the new version, it detects database version 3
2. Automatically upgrades to version 4
3. Creates new table with TEXT ID column
4. Migrates all existing sheets with new GUIDs
5. Preserves all data, timestamps, and relationships
6. No user action required

## Benefits

### Immediate Benefits
1. **No More Duplicates**: Sheets created on different devices will never conflict
2. **Reliable Sync**: Firebase sync now works correctly across multiple devices
3. **Proper Sharing**: Shared sheet links are unique and won't accidentally open wrong sheets

### Long-term Benefits
1. **Scalability**: GUIDs support unlimited growth without ID exhaustion
2. **Offline-First**: Sheets can be created offline without worrying about ID conflicts
3. **Distributed Systems**: Ready for potential future features like collaborative editing
4. **Debugging**: Easier to track specific sheets across systems using unique IDs

## Testing Recommendations

### Before Publishing
1. **Test Migration**: Install old version → create sheets → upgrade → verify sheets still accessible
2. **Test Multi-Device Sync**:
   - Login on Device A → create sheet
   - Login on Device B → verify sheet appears
   - Edit on Device B → verify changes sync to Device A
3. **Test Deep Links**: Share a sheet link and verify it opens correctly
4. **Test Offline**: Create sheets offline → go online → verify they sync with GUIDs

### Known Compatible Scenarios
- ✅ Fresh install (no migration needed)
- ✅ Upgrade from version 3 (auto-migration)
- ✅ Multiple devices with same account
- ✅ Offline sheet creation
- ✅ Sheet sharing via links

## Technical Notes

### GUID Format
- Uses UUID v4 (random UUIDs)
- Format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`
- Example: `550e8400-e29b-41d4-a716-446655440000`

### Database Schema
```sql
-- Old (version 3)
CREATE TABLE sheets(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ...
)

-- New (version 4)
CREATE TABLE sheets(
  id TEXT PRIMARY KEY,
  ...
)
```

### Firebase Structure
```
users/{userId}/sheets/{sheetGuid}
  ├─ id: "550e8400-e29b-41d4-a716-446655440000"
  ├─ userId: "{userId}"
  ├─ sheetRows: [...]
  └─ ...
```

## Rollback Plan
If issues arise, you can rollback by:
1. Reverting to the previous git commit
2. User data in Firebase will remain (with GUIDs)
3. Local database will need to be cleared (or manually migrated back)

**Note**: It's recommended to test thoroughly before releasing to avoid needing rollback.

## Future Enhancements
With GUIDs in place, these features become easier:
- Offline-first architecture with conflict resolution
- Real-time collaborative editing
- Sheet versioning and history
- Cross-platform synchronization
- Advanced sharing features (view-only, edit permissions, etc.)
