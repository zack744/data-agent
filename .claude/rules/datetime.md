# DateTime Rule

## Getting Current Date and Time

When any command requires the current date/time (for frontmatter, timestamps, or logs), you MUST obtain the REAL current date/time from the system rather than estimating or using placeholder values.

### How to Get Current DateTime

Use the `date` command to get the current ISO 8601 formatted datetime:

```bash
# Get current datetime in Beijing time (UTC+8)
TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00"

# Alternative for systems that support it
TZ='Asia/Shanghai' date --iso-8601=seconds

# For Windows (if using PowerShell) - Beijing time
(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss+08:00")
```

### Required Format

All dates in frontmatter MUST use ISO 8601 format with Beijing timezone:
- Format: `YYYY-MM-DDTHH:MM:SS+08:00`
- Example: `2024-01-15T22:30:45+08:00`

### Usage in Frontmatter

When creating or updating frontmatter in any file (PRD, Epic, Task, Progress), always use the real current datetime:

```yaml
---
name: feature-name
created: 2024-01-15T22:30:45+08:00  # Use actual output from date command
updated: 2024-01-15T22:30:45+08:00  # Use actual output from date command
---
```

### Implementation Instructions

1. **Before writing any file with frontmatter:**
   - Run: `TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00"`
   - Store the output
   - Use this exact value in the frontmatter

2. **For commands that create files:**
   - PRD creation: Use real date for `created` field
   - Epic creation: Use real date for `created` field
   - Task creation: Use real date for both `created` and `updated` fields
   - Progress tracking: Use real date for `started` and `last_sync` fields

3. **For commands that update files:**
   - Always update the `updated` field with current real datetime
   - Preserve the original `created` field
   - For sync operations, update `last_sync` with real datetime

### Examples

**Creating a new PRD:**
```bash
# First, get current datetime
CURRENT_DATE=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
# Output: 2024-01-15T22:30:45+08:00

# Then use in frontmatter:
---
name: user-authentication
description: User authentication and authorization system
status: backlog
created: 2024-01-15T22:30:45+08:00  # Use the actual $CURRENT_DATE value
---
```

**Updating an existing task:**
```bash
# Get current datetime for update
UPDATE_DATE=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")

# Update only the 'updated' field:
---
name: implement-login-api
status: in-progress
created: 2024-01-10T17:15:30+08:00  # Keep original
updated: 2024-01-15T22:30:45+08:00  # Use new $UPDATE_DATE value
---
```

### Important Notes

- **Never use placeholder dates** like `[Current ISO date/time]` or `YYYY-MM-DD`
- **Never estimate dates** - always get the actual system time
- **Always use Beijing time** (the `+08:00` suffix) for consistency across timezones
- **Preserve timezone consistency** - all dates in the system use Beijing time (UTC+8)

### Cross-Platform Compatibility

If you need to ensure compatibility across different systems:

```bash
# Try primary method first
TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00" 2>/dev/null || \
# Fallback for systems without TZ support
date +"%Y-%m-%dT%H:%M:%S+08:00" 2>/dev/null || \
# Last resort: use Python if available
python3 -c "from datetime import datetime, timezone, timedelta; print(datetime.now(timezone(timedelta(hours=8))).strftime('%Y-%m-%dT%H:%M:%S+08:00'))" 2>/dev/null || \
python -c "from datetime import datetime, timezone, timedelta; print(datetime.now(timezone(timedelta(hours=8))).strftime('%Y-%m-%dT%H:%M:%S+08:00'))" 2>/dev/null
```

## Rule Priority

This rule has **HIGHEST PRIORITY** and must be followed by all commands that:
- Create new files with frontmatter
- Update existing files with frontmatter
- Track timestamps or progress
- Log any time-based information

Commands affected: prd-new, prd-parse, epic-decompose, epic-sync, issue-start, issue-sync, and any other command that writes timestamps.