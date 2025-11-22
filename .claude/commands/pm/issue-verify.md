---
allowed-tools: Bash, Read, Write, LS, Task
---

# Issue Verify

Execute targeted verification for individual issue completion before marking as ready for epic merge.

## Usage
```
/pm:issue-verify <issue_number>
```

## Purpose

Verify that a specific issue implementation meets quality standards and acceptance criteria before considering it complete within the epic.

## Instructions

### 1. Locate Issue Context

Find the issue task file:
```bash
# Look for task file by issue number
TASK_FILE=$(find .claude/epics -name "*$ARGUMENTS.md" -type f | head -1)

if [ -z "$TASK_FILE" ]; then
  echo "❌ Task file not found for issue #$ARGUMENTS"
  echo "This issue may not be part of the CCPM system"
  exit 1
fi

# Extract epic name from path
EPIC_NAME=$(echo "$TASK_FILE" | sed 's|.claude/epics/||' | sed 's|/.*||')
echo "📁 Epic: $EPIC_NAME"
echo "📋 Task: $TASK_FILE"
```

### 2. Verify Worktree Exists

```bash
# Check if epic worktree exists
if ! git worktree list | grep -q "epic-$EPIC_NAME"; then
  echo "❌ No worktree found for epic: $EPIC_NAME"
  echo "Run: /pm:epic-start $EPIC_NAME"
  exit 1
fi

cd ../epic-$EPIC_NAME
```

### 3. Check Implementation Status

```bash
echo "🔍 Checking issue implementation status..."

# Check if there are related commits
COMMIT_COUNT=$(git log --oneline | grep -c "Issue #$ARGUMENTS" || echo "0")
echo "📊 Commits for this issue: $COMMIT_COUNT"

if [ "$COMMIT_COUNT" -eq 0 ]; then
  echo "⚠️ No commits found for Issue #$ARGUMENTS"
  echo "Has the implementation started?"
  exit 1
fi

echo "📝 Recent commits for this issue:"
git log --oneline | grep "Issue #$ARGUMENTS" | head -5
```

### 4. Extract Acceptance Criteria

```bash
echo "📋 Checking acceptance criteria..."

cd {main-repo-path}

# Read acceptance criteria from task file
if grep -q "acceptance_criteria" "$TASK_FILE"; then
  echo ""
  echo "Acceptance Criteria for Issue #$ARGUMENTS:"
  echo "=========================================="
  sed -n '/acceptance_criteria:/,/^[^-\s]/p' "$TASK_FILE" | head -n -1 | tail -n +2
  echo ""
else
  echo "⚠️ No formal acceptance criteria found in task file"
fi
```

### 5. Targeted Testing

Launch focused test execution:
```yaml
Task:
  description: "Issue Verification: #$ARGUMENTS"
  subagent_type: "test-runner"
  prompt: |
    Verify implementation for Issue #$ARGUMENTS in worktree: ../epic-$EPIC_NAME
    
    Focus Areas:
    1. Run tests related to this specific issue
    2. Verify modified files work correctly
    3. Check integration with existing code
    4. Validate error handling for this feature
    
    Test Strategy:
    - Identify files modified for this issue (git log analysis)
    - Run unit tests for modified components
    - Execute integration tests if applicable
    - Verify no regressions in related functionality
    
    Quality Checks:
    - All issue-related tests pass
    - No new test failures introduced
    - Code coverage maintained or improved
    - Performance impact acceptable
    
    Return:
    - Test results for issue-specific functionality
    - Any regressions detected
    - Coverage impact
    - Recommendation: READY or NEEDS_WORK
    
    Focus on quality over speed - this issue needs to be solid before epic merge.
```

### 6. Manual Verification Prompt

```bash
echo "🎯 Manual Verification Required"
echo "=============================="
echo ""
echo "Please test the following in worktree: ../epic-$EPIC_NAME"
echo ""

# Generate specific verification steps based on issue type
if grep -qi "UI\|interface\|component\|frontend" "$TASK_FILE"; then
  echo "🖥️ UI/Frontend Verification:"
  echo "□ Visual elements render correctly"
  echo "□ User interactions work as expected" 
  echo "□ Responsive design functions properly"
  echo "□ Error states display appropriately"
  echo ""
fi

if grep -qi "API\|endpoint\|backend\|server" "$TASK_FILE"; then
  echo "🔌 API/Backend Verification:"
  echo "□ API endpoints respond correctly"
  echo "□ Data validation works"
  echo "□ Error handling is appropriate"
  echo "□ Performance is acceptable"
  echo ""
fi

if grep -qi "database\|data\|model" "$TASK_FILE"; then
  echo "🗄️ Database/Data Verification:"
  echo "□ Data operations work correctly"
  echo "□ Data integrity maintained"
  echo "□ Migration scripts function"
  echo "□ No data loss or corruption"
  echo ""
fi

echo "General Verification:"
echo "□ Core functionality works as specified"
echo "□ Edge cases handled appropriately"
echo "□ Integration with existing features works"
echo "□ No obvious performance degradation"
echo "□ Documentation updated if needed"
echo ""

read -p "Has manual verification been completed successfully? [y/N]: " manual_ok
if [[ ! "$manual_ok" =~ ^[Yy]$ ]]; then
  echo "❌ Manual verification incomplete"
  echo "Please complete verification before marking issue as ready"
  exit 1
fi
```

### 7. Update Issue Status

Get current datetime: `TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00"`

```bash
VERIFICATION_DATE=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")

# Update task file frontmatter
cd {main-repo-path}

# Add verification status to frontmatter
if ! grep -q "verified:" "$TASK_FILE"; then
  # Add verification field to frontmatter
  sed -i '/^---$/i verified: true\nverified_at: '"$VERIFICATION_DATE" "$TASK_FILE"
else
  # Update existing verification
  sed -i 's/verified: .*/verified: true/' "$TASK_FILE"
  sed -i 's/verified_at: .*/verified_at: '"$VERIFICATION_DATE"'/' "$TASK_FILE"
fi

# Update status if not already done
sed -i 's/status: in-progress/status: verified/' "$TASK_FILE"
sed -i 's/status: open/status: verified/' "$TASK_FILE"
```

### 8. Create Issue Verification Record

```bash
# Create verification record in updates directory
mkdir -p .claude/epics/$EPIC_NAME/updates/$ARGUMENTS

cat > .claude/epics/$EPIC_NAME/updates/$ARGUMENTS/verification.md << EOF
---
issue: $ARGUMENTS
verified_at: $VERIFICATION_DATE
status: verified
epic: $EPIC_NAME
---

# Issue Verification: #$ARGUMENTS

## Implementation Summary
- Commits: $COMMIT_COUNT
- Files Modified: [List from git log]
- Testing: PASSED
- Manual Verification: COMPLETED

## Acceptance Criteria Status
$(if grep -q "acceptance_criteria" "$TASK_FILE"; then
  sed -n '/acceptance_criteria:/,/^[^-\s]/p' "$TASK_FILE" | head -n -1 | tail -n +2 | sed 's/^- /✅ /'
else
  echo "No formal criteria specified"
fi)

## Quality Checks
✅ Tests passing
✅ No regressions detected  
✅ Manual verification completed
✅ Ready for epic merge

## Next Steps
This issue is verified and ready. When all epic issues are verified, run:
\`/pm:epic-verify $EPIC_NAME\`

Verified: $VERIFICATION_DATE
EOF

echo "✅ Issue verification record created"
```

### 9. Sync to GitHub

```bash
# Update GitHub issue with verification status
gh issue comment $ARGUMENTS --body "## ✅ Issue Verified

This issue has been verified and meets acceptance criteria.

**Verification Details:**
- Implementation: Complete
- Testing: Passed
- Manual Verification: ✅ Completed
- Quality Gates: ✅ Passed

**Status:** Ready for epic merge

*Verified: $VERIFICATION_DATE*"

echo "✅ GitHub issue updated with verification status"
```

### 10. Output Summary

```bash
echo ""
echo "✅ Issue Verification Complete: #$ARGUMENTS"
echo ""
echo "Status: VERIFIED"
echo "Epic: $EPIC_NAME" 
echo "Commits: $COMMIT_COUNT"
echo "Verified: $VERIFICATION_DATE"
echo ""
echo "Next Steps:"
echo "- Issue is ready for epic merge"
echo "- Verify other epic issues: /pm:epic-show $EPIC_NAME"
echo "- When all issues verified: /pm:epic-verify $EPIC_NAME"
echo ""
```

## Error Handling

If verification fails:
```
❌ Issue Verification Failed: #$ARGUMENTS

Issues Found:
- [Specific problems]

Required Actions:
1. Fix identified issues
2. Re-run tests
3. Complete manual verification
4. Re-run: /pm:issue-verify $ARGUMENTS
```

## Integration Notes

This command provides issue-level verification that feeds into epic-level verification:
- Individual issues verified with `/pm:issue-verify`
- Epic overall verified with `/pm:epic-verify` 
- Epic merged with `/pm:epic-merge` (only if verified)

This creates a comprehensive quality gate system at both issue and epic levels.