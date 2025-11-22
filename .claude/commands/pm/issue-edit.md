---
allowed-tools: Bash, Read, Write, LS
---

# Issue Edit

Edit issue details locally and on GitHub.

## Usage
```
/pm:issue-edit <issue_number>
```

## Instructions

### 0. Repository Protection Check

Follow `/rules/github-operations.md` to ensure we're not editing issues in the CCPM template:

```bash
# Check if remote origin is the CCPM template repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"zack744/CCPM-DIY"* ]] || [[ "$remote_url" == *"zack744/CCPM-DIY.git"* ]]; then
  echo "❌ ERROR: You're trying to edit issues in the CCPM DIY template repository!"
  echo ""
  echo "This repository (zack744/CCPM-DIY) is a template for others to use."
  echo "You should NOT edit issues here."
  echo ""
  echo "To fix this:"
  echo "1. Fork this repository to your own GitHub account"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Current remote: $remote_url"
  exit 1
fi
```

### 1. Get Current Issue State

```bash
# Get from GitHub
gh issue view $ARGUMENTS --json title,body,labels

# Find local task file
# Search for file with github:.*issues/$ARGUMENTS
```

### 2. Interactive Edit

Ask user what to edit:
- Title
- Description/Body
- Labels
- Acceptance criteria (local only)
- Priority/Size (local only)

### 3. Update Local File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file with changes:
- Update frontmatter `name` if title changed
- Update body content if description changed
- Update `updated` field with current datetime

### 4. Update GitHub

If title changed:
```bash
gh issue edit $ARGUMENTS --title "{new_title}"
```

If body changed:
```bash
gh issue edit $ARGUMENTS --body-file {updated_task_file}
```

If labels changed:
```bash
gh issue edit $ARGUMENTS --add-label "{new_labels}"
gh issue edit $ARGUMENTS --remove-label "{removed_labels}"
```

### 5. Output

```
✅ Updated issue #$ARGUMENTS
  Changes:
    {list_of_changes_made}
  
Synced to GitHub: ✅
```

## Important Notes

Always update local first, then GitHub.
Preserve frontmatter fields not being edited.
Follow `/rules/frontmatter-operations.md`.