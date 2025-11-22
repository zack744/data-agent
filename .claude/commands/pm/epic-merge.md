---
allowed-tools: Bash, Read, Write
---

# Epic Merge

Merge completed epic from worktree back to main branch.

## Usage
```
/pm:epic-merge <epic_name>
```

## Quick Check

1. **Verify worktree exists:**
   ```bash
   git worktree list | grep "epic-$ARGUMENTS" || echo "❌ No worktree for epic: $ARGUMENTS"
   ```

2. **Check for active agents:**
   Read `.claude/epics/$ARGUMENTS/execution-status.md`
   If active agents exist: "⚠️ Active agents detected. Stop them first with: /pm:epic-stop $ARGUMENTS"

## Instructions

### 0. Repository Protection Check

Follow `/rules/github-operations.md` to ensure we're not merging epics in the CCPM template:

```bash
# Check if remote origin is the CCPM template repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"zack744/CCPM-DIY"* ]] || [[ "$remote_url" == *"zack744/CCPM-DIY.git"* ]]; then
  echo "❌ ERROR: You're trying to merge epics in the CCPM DIY template repository!"
  echo ""
  echo "This repository (zack744/CCPM-DIY) is a template for others to use."
  echo "You should NOT merge epics here."
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

### 1. Pre-Merge Validation

#### 1.1 Check Epic Verification Status (MANDATORY)

```bash
# Check if epic has been verified
if [ ! -f ".claude/epics/$ARGUMENTS/verification-report.md" ]; then
  echo "❌ Epic not verified. Quality gates must pass before merge."
  echo ""
  echo "Required: Run epic verification first:"
  echo "  /pm:epic-verify $ARGUMENTS"
  echo ""
  echo "This ensures:"
  echo "  - All tests pass with adequate coverage"
  echo "  - Code quality standards met"
  echo "  - Security checks completed"
  echo "  - Manual verification completed"
  exit 1
fi

# Check verification recency (within 24 hours)
VERIFICATION_FILE=".claude/epics/$ARGUMENTS/verification-report.md"
if [ -f "$VERIFICATION_FILE" ]; then
  VERIFICATION_DATE=$(grep "verified_at:" "$VERIFICATION_FILE" | cut -d' ' -f2-)
  echo "✅ Epic verified at: $VERIFICATION_DATE"
  
  # Optional: Check if verification is recent (can be configured)
  # Uncomment below to enforce 24-hour verification window
  # if [[ $(date -d "$VERIFICATION_DATE" +%s) -lt $(date -d "24 hours ago" +%s) 2>/dev/null ]]; then
  #   echo "⚠️ Verification is older than 24 hours"
  #   echo "Consider re-running: /pm:epic-verify $ARGUMENTS"
  # fi
else
  echo "❌ Verification report not found"
  exit 1
fi
```

#### 1.2 Worktree Status Check

Navigate to worktree and check status:
```bash
cd ../epic-$ARGUMENTS

# Check for uncommitted changes
if [[ $(git status --porcelain) ]]; then
  echo "⚠️ Uncommitted changes in worktree:"
  git status --short
  echo "Commit or stash changes before merging"
  exit 1
fi

# Check branch status
git fetch origin
git status -sb
```

### 2. Final Quality Confirmation

Since epic verification is mandatory, testing has already been completed.
This section confirms the verification status:

```bash
# Display verification summary
echo "📊 Quality Gate Summary:"
echo "========================"
if [ -f ".claude/epics/$ARGUMENTS/verification-report.md" ]; then
  grep -A 10 "Quality Gates Status" ".claude/epics/$ARGUMENTS/verification-report.md" || echo "Verification report available"
else
  echo "❌ No verification report found"
fi

echo ""
echo "✅ All quality gates passed - proceeding with merge"
```

### 3. Update Epic Documentation

Get current datetime: `TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00"`

Update `.claude/epics/$ARGUMENTS/epic.md`:
- Set status to "completed"
- Update completion date
- Add final summary

### 4. Attempt Merge

```bash
# Return to main repository
cd {main-repo-path}

# Ensure main is up to date
git checkout main
git pull origin main

# Attempt merge
echo "Merging epic/$ARGUMENTS to main..."
git merge epic/$ARGUMENTS --no-ff -m "Merge epic: $ARGUMENTS

Completed features:
$(cd .claude/epics/$ARGUMENTS && ls *.md | grep -E '^[0-9]+' | while read f; do
  echo "- $(grep '^name:' $f | cut -d: -f2)"
done)

Closes epic #$(grep 'github:' .claude/epics/$ARGUMENTS/epic.md | grep -oE '#[0-9]+')"
```

### 5. Handle Merge Conflicts

If merge fails with conflicts:
```bash
# Check conflict status
git status

echo "
❌ Merge conflicts detected!

Conflicts in:
$(git diff --name-only --diff-filter=U)

Options:
1. Resolve manually:
   - Edit conflicted files
   - git add {files}
   - git commit
   
2. Abort merge:
   git merge --abort
   
3. Get help:
   /pm:epic-resolve $ARGUMENTS

Worktree preserved at: ../epic-$ARGUMENTS
"
exit 1
```

### 6. Post-Merge Cleanup

If merge succeeds:
```bash
# Push to remote
git push origin main

# Clean up worktree
git worktree remove ../epic-$ARGUMENTS
echo "✅ Worktree removed: ../epic-$ARGUMENTS"

# Delete branch
git branch -d epic/$ARGUMENTS
git push origin --delete epic/$ARGUMENTS 2>/dev/null || true

# Archive epic locally
mkdir -p .claude/epics/archived/
mv .claude/epics/$ARGUMENTS .claude/epics/archived/
echo "✅ Epic archived: .claude/epics/archived/$ARGUMENTS"
```

### 7. Update GitHub Issues

Close related issues:
```bash
# Get issue numbers from epic
epic_issue=$(grep 'github:' .claude/epics/archived/$ARGUMENTS/epic.md | grep -oE '[0-9]+$')

# Close epic issue
gh issue close $epic_issue -c "Epic completed and merged to main"

# Close task issues
for task_file in .claude/epics/archived/$ARGUMENTS/[0-9]*.md; do
  issue_num=$(grep 'github:' $task_file | grep -oE '[0-9]+$')
  if [ ! -z "$issue_num" ]; then
    gh issue close $issue_num -c "Completed in epic merge"
  fi
done
```

### 8. Final Output

```
✅ Epic Merged Successfully: $ARGUMENTS

Summary:
  Branch: epic/$ARGUMENTS → main
  Commits merged: {count}
  Files changed: {count}
  Issues closed: {count}
  
Cleanup completed:
  ✓ Worktree removed
  ✓ Branch deleted
  ✓ Epic archived
  ✓ GitHub issues closed
  
Next steps:
  - Deploy changes if needed
  - Start new epic: /pm:prd-new {feature}
  - View completed work: git log --oneline -20
```

## Conflict Resolution Help

If conflicts need resolution:
```
The epic branch has conflicts with main.

This typically happens when:
- Main has changed since epic started
- Multiple epics modified same files
- Dependencies were updated

To resolve:
1. Open conflicted files
2. Look for <<<<<<< markers
3. Choose correct version or combine
4. Remove conflict markers
5. git add {resolved files}
6. git commit
7. git push

Or abort and try later:
  git merge --abort
```

## Important Notes

- Always check for uncommitted changes first
- Run tests before merging when possible
- Use --no-ff to preserve epic history
- Archive epic data instead of deleting
- Close GitHub issues to maintain sync