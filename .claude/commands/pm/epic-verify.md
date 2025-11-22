---
allowed-tools: Bash, Read, Write, LS, Task
---

# Epic Verify

Execute comprehensive quality verification before epic merge with mandatory quality gates.

## Usage
```
/pm:epic-verify <epic_name>
```

## Purpose

This command implements a mandatory quality verification process before epic merge, ensuring code quality, test coverage, and functional requirements are met.

## Quality Gates Overview

```
🔍 静态检查 → 🧪 测试验证 → 🎯 功能验收 → ✅ 质量报告
```

## Instructions

### 0. Repository Protection Check

Follow `/rules/github-operations.md` to ensure we're not verifying epics in the CCPM template.

### 1. Pre-Verification Setup

Navigate to epic worktree:
```bash
cd ../epic-$ARGUMENTS

# Ensure clean working directory
if [[ $(git status --porcelain) ]]; then
  echo "❌ Uncommitted changes detected:"
  git status --short
  echo "Please commit or stash changes before verification"
  exit 1
fi

# Update from remote
git fetch origin
```

### 2. Static Quality Checks (MANDATORY)

#### 2.1 Code Style and Linting
```bash
echo "🔍 Running code style checks..."

# Check for common linting tools
LINT_PASSED=true

if [ -f package.json ]; then
  # Node.js projects
  if npm run lint --if-present 2>/dev/null; then
    echo "✅ ESLint/TSLint passed"
  else
    echo "❌ Linting failed"
    LINT_PASSED=false
  fi
  
  # TypeScript check
  if npm run typecheck --if-present 2>/dev/null; then
    echo "✅ TypeScript checks passed"
  else
    echo "❌ TypeScript checks failed"
    LINT_PASSED=false
  fi
elif [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  # Python projects
  if command -v flake8 >/dev/null 2>&1; then
    if flake8 . 2>/dev/null; then
      echo "✅ Flake8 passed"
    else
      echo "❌ Flake8 failed"
      LINT_PASSED=false
    fi
  fi
  
  if command -v black >/dev/null 2>&1; then
    if black --check . 2>/dev/null; then
      echo "✅ Black formatting passed"
    else
      echo "❌ Black formatting failed"
      LINT_PASSED=false
    fi
  fi
fi

if [ "$LINT_PASSED" = false ]; then
  echo "❌ QUALITY GATE FAILED: Code style checks failed"
  echo "Please fix linting issues before proceeding"
  exit 1
fi
```

#### 2.2 Security Scanning
```bash
echo "🔒 Running security checks..."

SECURITY_PASSED=true

if [ -f package.json ]; then
  # Node.js security audit
  if npm audit --audit-level=high 2>/dev/null; then
    echo "✅ npm audit passed"
  else
    echo "⚠️ npm audit found vulnerabilities"
    echo "Run 'npm audit fix' to resolve"
    # Don't fail for warnings, but report
  fi
elif [ -f requirements.txt ]; then
  # Python security check
  if command -v safety >/dev/null 2>&1; then
    if safety check 2>/dev/null; then
      echo "✅ Safety check passed"
    else
      echo "⚠️ Safety check found vulnerabilities"
    fi
  fi
fi

# Check for common secrets patterns
if command -v grep >/dev/null 2>&1; then
  if grep -r -i "password\|api_key\|secret\|token" --include="*.js" --include="*.ts" --include="*.py" . | grep -v node_modules | grep -v ".git" | head -5; then
    echo "⚠️ Potential secrets found in code - please review"
  else
    echo "✅ No obvious secrets detected"
  fi
fi
```

### 3. Test Execution (MANDATORY)

#### 3.1 Unit Tests with Coverage
```bash
echo "🧪 Running comprehensive tests..."

# Use CCPM test-runner agent for detailed analysis
echo "Launching test-runner agent for comprehensive test execution..."

# Return to main directory for agent launch
cd {main-repo-path}
```

Launch test-runner agent using Task tool:
```yaml
Task:
  description: "Epic Verification Tests: $ARGUMENTS"
  subagent_type: "test-runner"
  prompt: |
    Execute comprehensive testing for epic verification in worktree: ../epic-$ARGUMENTS
    
    MANDATORY REQUIREMENTS:
    1. Run ALL tests with coverage reporting
    2. Minimum coverage threshold: 80%
    3. All tests must pass (0 failures)
    4. Generate detailed test report
    5. Identify any untested critical paths
    
    Test Execution:
    - Unit tests: ALL must pass
    - Integration tests: ALL must pass  
    - Coverage report: Detailed analysis
    - Performance: Flag any obvious issues
    
    Quality Standards:
    - Code coverage >= 80%
    - No failing tests
    - No skipped critical tests
    - Performance within acceptable range
    
    Return:
    - Test pass/fail status
    - Coverage percentage  
    - List of any failing tests
    - Performance concerns if any
    - Recommendation: PROCEED or BLOCK merge
    
    If tests fail or coverage < 80%, recommend BLOCK with specific issues to fix.
```

#### 3.2 Build Verification
```bash
cd ../epic-$ARGUMENTS

echo "🏗️ Running build verification..."

BUILD_PASSED=true

if [ -f package.json ]; then
  # Node.js build
  if npm run build 2>/dev/null; then
    echo "✅ Build successful"
  else
    echo "❌ Build failed"
    BUILD_PASSED=false
  fi
elif [ -f Makefile ]; then
  # Make-based build
  if make build 2>/dev/null; then
    echo "✅ Make build successful"
  else
    echo "❌ Make build failed"
    BUILD_PASSED=false
  fi
elif [ -f setup.py ] || [ -f pyproject.toml ]; then
  # Python build
  if python -m build 2>/dev/null || python setup.py build 2>/dev/null; then
    echo "✅ Python build successful"
  else
    echo "❌ Python build failed"
    BUILD_PASSED=false
  fi
fi

if [ "$BUILD_PASSED" = false ]; then
  echo "❌ QUALITY GATE FAILED: Build verification failed"
  exit 1
fi
```

### 4. Functional Verification Checklist

Generate interactive verification checklist:
```bash
echo "📋 Functional Verification Checklist"
echo "=================================="
echo ""
echo "Please verify the following manually in worktree: ../epic-$ARGUMENTS"
echo ""

# Read original requirements from task files
for task_file in .claude/epics/$ARGUMENTS/[0-9]*.md; do
  if [ -f "$task_file" ]; then
    echo "Task: $(basename $task_file .md)"
    
    # Extract acceptance criteria
    if grep -q "acceptance_criteria" "$task_file"; then
      echo "Acceptance Criteria:"
      sed -n '/acceptance_criteria:/,/^[a-zA-Z]/p' "$task_file" | head -n -1 | tail -n +2
    fi
    echo ""
  fi
done

echo "Manual Verification Required:"
echo "□ Core functionality works as expected"
echo "□ UI/UX meets design requirements"  
echo "□ Error handling works properly"
echo "□ Performance is acceptable"
echo "□ Security considerations addressed"
echo "□ Integration with existing features works"
echo "□ Documentation is updated"
echo ""

read -p "Have you completed manual verification? [y/N]: " manual_verified
if [[ ! "$manual_verified" =~ ^[Yy]$ ]]; then
  echo "❌ Manual verification required before proceeding"
  exit 1
fi
```

### 5. Quality Report Generation

Get current datetime: `TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00"`

Create verification report:
```bash
VERIFICATION_DATE=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")

cat > .claude/epics/$ARGUMENTS/verification-report.md << EOF
---
epic: $ARGUMENTS
verified_at: $VERIFICATION_DATE
status: verified
---

# Epic Verification Report: $ARGUMENTS

## Quality Gates Status

### ✅ Static Quality Checks
- Code Style: PASSED
- Security Scan: PASSED
- Build Verification: PASSED

### ✅ Test Verification  
- Unit Tests: PASSED
- Coverage: [agent-reported]%
- Integration Tests: PASSED

### ✅ Functional Verification
- Manual Testing: VERIFIED
- Acceptance Criteria: MET
- Documentation: UPDATED

## Verification Summary

This epic has passed all quality gates and is ready for merge to main branch.

Verified by: [System]
Date: $VERIFICATION_DATE
Next Step: /pm:epic-merge $ARGUMENTS
EOF

echo "✅ Verification report generated: .claude/epics/$ARGUMENTS/verification-report.md"
```

### 6. Final Output

```
✅ Epic Verification Complete: $ARGUMENTS

Quality Gate Results:
  🔍 Static Checks: PASSED
  🧪 Test Coverage: [X]% (≥80% required)
  🏗️ Build: PASSED
  🎯 Functional: VERIFIED

Epic is ready for merge:
  /pm:epic-merge $ARGUMENTS

View full report:
  .claude/epics/$ARGUMENTS/verification-report.md
```

## Error Handling

If any quality gate fails:
```
❌ Epic Verification Failed: $ARGUMENTS

Failed Gates:
  [List of failed checks]

Required Actions:
  1. Fix failing quality checks
  2. Ensure test coverage ≥ 80%
  3. Resolve build issues
  4. Complete manual verification

Re-run verification:
  /pm:epic-verify $ARGUMENTS
```

## Integration with Epic Merge

The `/pm:epic-merge` command should check for verification:
- Look for `verification-report.md` 
- Verify timestamp is recent (< 24 hours)
- Proceed only if verified

This creates a mandatory quality gate system while maintaining CCPM's workflow efficiency.