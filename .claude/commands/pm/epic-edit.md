---
allowed-tools: Read, Write, LS
---

# Epic Edit

Edit epic details after creation.

## Usage
```
/pm:epic-edit <epic_name>
```

## Instructions

### 0. Repository Protection Check

Follow `/rules/github-operations.md` to ensure we're not editing epics in the CCPM template:

```bash
# Check if remote origin is the CCPM template repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"zack744/CCPM-DIY"* ]] || [[ "$remote_url" == *"zack744/CCPM-DIY.git"* ]]; then
  echo "❌ ERROR: You're trying to edit epics in the CCPM DIY template repository!"
  echo ""
  echo "This repository (zack744/CCPM-DIY) is a template for others to use."
  echo "You should NOT edit epics here."
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

### 1. Read Current Epic

Read `.claude/epics/$ARGUMENTS/epic.md`:
- Parse frontmatter
- Read content sections

### 2. Interactive Edit

Ask user what to edit:
- Name/Title
- Description/Overview
- Architecture decisions
- Technical approach
- Dependencies
- Success criteria

### 3. Update Epic File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update epic.md:
- Preserve all frontmatter except `updated`
- Apply user's edits to content
- Update `updated` field with current datetime

### 4. Option to Update GitHub

If epic has GitHub URL in frontmatter:
Ask: "Update GitHub issue? (yes/no)"

If yes:
```bash
gh issue edit {issue_number} --body-file .claude/epics/$ARGUMENTS/epic.md
```

### 5. Output

```
✅ Updated epic: $ARGUMENTS
  Changes made to: {sections_edited}
  
{If GitHub updated}: GitHub issue updated ✅

View epic: /pm:epic-show $ARGUMENTS
```

## Important Notes

Preserve frontmatter history (created, github URL, etc.).
Don't change task files when editing epic.
Follow `/rules/frontmatter-operations.md`.