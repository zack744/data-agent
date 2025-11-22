#!/bin/bash

# ============================================================================
# CCPM Testing Environment Prime Script
# 根据 .claude/commands/testing/prime.md 实现
# 
# 功能：检测测试框架，验证依赖，配置测试环境
# 作者：CCPM Enhanced Project
# ============================================================================

# 全局变量
DETECTED_FRAMEWORK=""
TEST_COMMAND=""
TEST_DIRECTORY=""
CONFIG_FILE=""
FRAMEWORK_VERSION=""
TEST_COUNT=0
PROJECT_TYPE=""
ERROR_COUNT=0
REAL_DATETIME=""

# 颜色定义（跨平台兼容）
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows环境，使用简单输出
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    NC=""
else
    # Unix环境，使用颜色
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# ============================================================================
# 日志输出函数
# ============================================================================

log_info() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

log_step() {
    echo -e "${BLUE}🔍${NC} $1"
}

log_success() {
    echo -e "${GREEN}🎉${NC} $1"
}

# ============================================================================
# 初始化函数
# ============================================================================

init_script() {
    echo ""
    echo "🧪 测试环境准备中"
    echo "======================================"
    echo ""
    
    # 获取真实时间戳（按照指令要求）
    if command -v date >/dev/null 2>&1; then
        REAL_DATETIME=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00" 2>/dev/null)
        if [[ -z "$REAL_DATETIME" ]]; then
            # Windows兼容性
            REAL_DATETIME=$(date /t 2>/dev/null | tr -d '\r\n')
        fi
    else
        REAL_DATETIME="unknown"
    fi
    
    log_step "时间戳: $REAL_DATETIME"
}

# ============================================================================
# 框架检测函数
# ============================================================================

detect_javascript_framework() {
    log_step "检测 JavaScript/Node.js 测试框架..."
    
    # 检查 package.json 中的测试脚本
    if [[ -f "package.json" ]]; then
        log_info "找到 package.json 文件"
        
        # 检查测试相关的脚本和依赖
        if grep -E '"test"|"spec"|"jest"|"mocha"' package.json >/dev/null 2>&1; then
            log_info "在 package.json 中发现测试配置"
            
            # 具体检测 Jest
            if grep -E '"jest"' package.json >/dev/null 2>&1; then
                DETECTED_FRAMEWORK="jest"
                TEST_COMMAND="npm test"
                TEST_DIRECTORY="__tests__"
                CONFIG_FILE="jest.config.js"
                PROJECT_TYPE="JavaScript/Node.js"
                return 0
            fi
            
            # 检测 Mocha
            if grep -E '"mocha"' package.json >/dev/null 2>&1; then
                DETECTED_FRAMEWORK="mocha"
                TEST_COMMAND="npm test"
                TEST_DIRECTORY="test"
                CONFIG_FILE=".mocharc.js"
                PROJECT_TYPE="JavaScript/Node.js"
                return 0
            fi
            
            # 通用 npm test
            if grep -E '"test"' package.json >/dev/null 2>&1; then
                DETECTED_FRAMEWORK="npm"
                TEST_COMMAND="npm test"
                TEST_DIRECTORY="test"
                PROJECT_TYPE="JavaScript/Node.js"
                return 0
            fi
        fi
        
        # 检查测试配置文件
        for config in jest.config.js jest.config.json .mocharc.js .mocharc.json; do
            if [[ -f "$config" ]]; then
                log_info "找到测试配置文件: $config"
                if [[ "$config" == *"jest"* ]]; then
                    DETECTED_FRAMEWORK="jest"
                    CONFIG_FILE="$config"
                elif [[ "$config" == *"mocha"* ]]; then
                    DETECTED_FRAMEWORK="mocha"
                    CONFIG_FILE="$config"
                fi
                TEST_COMMAND="npm test"
                PROJECT_TYPE="JavaScript/Node.js"
                return 0
            fi
        done
        
        # 检查测试目录
        for testdir in __tests__ test tests spec; do
            if [[ -d "$testdir" ]]; then
                log_info "找到测试目录: $testdir"
                DETECTED_FRAMEWORK="generic-js"
                TEST_COMMAND="npm test"
                TEST_DIRECTORY="$testdir"
                PROJECT_TYPE="JavaScript/Node.js"
                return 0
            fi
        done
    fi
    
    return 1
}

detect_python_framework() {
    log_step "检测 Python 测试框架..."
    
    # 检查 pytest 相关文件
    if [[ -f "pytest.ini" ]] || [[ -f "conftest.py" ]] || [[ -f "setup.cfg" ]]; then
        log_info "发现 pytest 配置文件"
        DETECTED_FRAMEWORK="pytest"
        TEST_COMMAND="pytest"
        TEST_DIRECTORY="tests"
        CONFIG_FILE="pytest.ini"
        PROJECT_TYPE="Python"
        return 0
    fi
    
    # 检查 requirements.txt 中的测试库
    if [[ -f "requirements.txt" ]]; then
        if grep -E "pytest|unittest|nose" requirements.txt >/dev/null 2>&1; then
            log_info "在 requirements.txt 中发现测试依赖"
            DETECTED_FRAMEWORK="pytest"
            TEST_COMMAND="pytest"
            TEST_DIRECTORY="tests"
            PROJECT_TYPE="Python"
            return 0
        fi
    fi
    
    # 查找 test_*.py 文件
    if find . -maxdepth 3 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
        log_info "发现 Python 测试文件"
        DETECTED_FRAMEWORK="unittest"
        TEST_COMMAND="python -m pytest"
        TEST_DIRECTORY="."
        PROJECT_TYPE="Python"
        return 0
    fi
    
    return 1
}

detect_rust_framework() {
    log_step "检测 Rust 测试框架..."
    
    if [[ -f "Cargo.toml" ]]; then
        log_info "发现 Cargo.toml 文件"
        DETECTED_FRAMEWORK="cargo"
        TEST_COMMAND="cargo test"
        TEST_DIRECTORY="tests"
        CONFIG_FILE="Cargo.toml"
        PROJECT_TYPE="Rust"
        return 0
    fi
    
    return 1
}

detect_go_framework() {
    log_step "检测 Go 测试框架..."
    
    if [[ -f "go.mod" ]]; then
        log_info "发现 go.mod 文件"
        
        # 查找 *_test.go 文件
        if find . -maxdepth 3 -name "*_test.go" 2>/dev/null | head -1 | grep -q .; then
            log_info "发现 Go 测试文件"
            DETECTED_FRAMEWORK="go"
            TEST_COMMAND="go test"
            TEST_DIRECTORY="."
            CONFIG_FILE="go.mod"
            PROJECT_TYPE="Go"
            return 0
        fi
    fi
    
    return 1
}

# ============================================================================
# 主要检测流程
# ============================================================================

detect_all_frameworks() {
    log_step "开始检测测试框架..."
    
    # 按优先级检测
    if detect_javascript_framework; then
        log_success "检测到 $PROJECT_TYPE 项目，框架: $DETECTED_FRAMEWORK"
        return 0
    elif detect_python_framework; then
        log_success "检测到 $PROJECT_TYPE 项目，框架: $DETECTED_FRAMEWORK"
        return 0
    elif detect_rust_framework; then
        log_success "检测到 $PROJECT_TYPE 项目，框架: $DETECTED_FRAMEWORK"
        return 0
    elif detect_go_framework; then
        log_success "检测到 $PROJECT_TYPE 项目，框架: $DETECTED_FRAMEWORK"
        return 0
    else
        log_warning "未检测到测试框架"
        ask_user_for_test_command
        return $?
    fi
}

# ============================================================================
# 用户交互函数
# ============================================================================

ask_user_for_test_command() {
    echo ""
    log_warning "⚠️ 未检测到测试框架。请指定您的测试设置。"
    echo "您使用什么测试命令？(例如: npm test, pytest, cargo test)"
    
    # 检查是否为交互式终端
    if [[ -t 0 ]]; then
        read -r user_command
    else
        # 非交互式环境，提供默认建议
        log_warning "检测到非交互式环境"
        echo ""
        echo "💡 建议解决方案："
        echo "1. 在实际项目目录中运行此命令"
        echo "2. 确保项目包含以下文件之一："
        echo "   - package.json (Node.js项目)"
        echo "   - requirements.txt 或 pytest.ini (Python项目)"  
        echo "   - Cargo.toml (Rust项目)"
        echo "   - go.mod (Go项目)"
        echo "3. 或手动运行: echo 'npm test' | /testing:prime"
        echo ""
        return 1
    fi
    
    if [[ -n "$user_command" ]]; then
        DETECTED_FRAMEWORK="custom"
        TEST_COMMAND="$user_command"
        PROJECT_TYPE="Custom"
        log_info "用户指定的测试命令: $user_command"
        return 0
    else
        log_error "未提供测试命令"
        return 1
    fi
}

# ============================================================================
# 测试发现函数
# ============================================================================

discover_tests() {
    log_step "扫描测试文件..."
    
    case $DETECTED_FRAMEWORK in
        "jest"|"mocha"|"npm"|"generic-js")
            TEST_COUNT=$(find . -path "*/node_modules" -prune -o \( -name "*.test.js" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.spec.ts" \) -print 2>/dev/null | wc -l)
            ;;
        "pytest"|"unittest")
            TEST_COUNT=$(find . -name "test_*.py" -o -name "*_test.py" 2>/dev/null | wc -l)
            ;;
        "cargo")
            TEST_COUNT=$(find . -name "*.rs" -exec grep -l "#\[cfg(test)\]" {} \; 2>/dev/null | wc -l)
            ;;
        "go")
            TEST_COUNT=$(find . -name "*_test.go" 2>/dev/null | wc -l)
            ;;
        *)
            TEST_COUNT=0
            ;;
    esac
    
    log_info "发现 $TEST_COUNT 个测试文件"
}

# ============================================================================
# 配置文件生成
# ============================================================================

create_testing_config() {
    log_step "创建测试配置文件..."
    
    # 确保目录存在
    mkdir -p .claude
    
    # 生成配置文件
    cat > .claude/testing-config.md << EOF
---
framework: $DETECTED_FRAMEWORK
test_command: $TEST_COMMAND
created: $REAL_DATETIME
---

# Testing Configuration

## Framework
- Type: $DETECTED_FRAMEWORK
- Project: $PROJECT_TYPE
- Config File: $CONFIG_FILE

## Test Structure
- Test Directory: $TEST_DIRECTORY
- Test Files: $TEST_COUNT files found
- Test Command: \`$TEST_COMMAND\`

## Commands
- Run All Tests: \`$TEST_COMMAND\`
- Run Specific Test: \`$TEST_COMMAND {test_file}\`

## Environment
- Created: $REAL_DATETIME
- Framework Detected: $DETECTED_FRAMEWORK
- Project Type: $PROJECT_TYPE

## Test Runner Agent Configuration
- Use verbose output for debugging
- Run tests sequentially (no parallel)
- Capture full stack traces
- No mocking - use real implementations
- Wait for each test to complete
EOF

    if [[ -f ".claude/testing-config.md" ]]; then
        log_success "配置文件已创建: .claude/testing-config.md"
        return 0
    else
        log_error "配置文件创建失败"
        return 1
    fi
}

# ============================================================================
# 最终摘要
# ============================================================================

show_final_summary() {
    echo ""
    echo "🧪 测试环境准备完成"
    echo ""
    echo "🔍 检测结果:"
    echo "  ✅ 框架: $DETECTED_FRAMEWORK"
    if [[ -n "$PROJECT_TYPE" ]]; then
        echo "  ✅ 项目类型: $PROJECT_TYPE"
    fi
    echo "  ✅ 测试文件: $TEST_COUNT 个"
    if [[ -n "$CONFIG_FILE" ]]; then
        echo "  ✅ 配置文件: $CONFIG_FILE"
    fi
    echo ""
    echo "📋 测试结构:"
    echo "  - 测试目录: $TEST_DIRECTORY"
    echo "  - 测试命令: $TEST_COMMAND"
    echo ""
    echo "🤖 代理配置:"
    echo "  ✅ Test-runner 代理已配置"
    echo "  ✅ 详细输出已启用"
    echo "  ✅ 顺序执行已设置"
    echo ""
    echo "⚡ 可用命令:"
    echo "  - 运行所有测试: /testing:run"
    echo "  - 运行特定测试: /testing:run {test_file}"
    echo ""
    if [[ $ERROR_COUNT -eq 0 ]]; then
        echo "💡 状态: ✅ 准备就绪"
    else
        echo "💡 状态: ⚠️ 有 $ERROR_COUNT 个警告"
    fi
    echo ""
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    init_script
    
    # 1. 框架检测
    if ! detect_all_frameworks; then
        log_error "框架检测失败"
        exit 1
    fi
    
    # 2. 测试发现
    discover_tests
    
    # 3. 配置生成
    if ! create_testing_config; then
        log_error "配置创建失败"
        exit 1
    fi
    
    # 4. 显示摘要
    show_final_summary
    
    echo "✅ 初始化完成！使用 /testing:run 开始测试。"
    exit 0
}

# 执行主函数
main "$@"