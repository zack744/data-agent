#!/bin/bash

# ============================================================================
# CCPM Testing Run Preprocessor Script
# 根据 .claude/commands/testing/run.md 实现
# 
# 功能：测试预处理 - 环境检查、配置读取、命令构建
# 输出：结构化JSON信息供Claude调用test-runner代理使用
# 作者：CCPM Enhanced Project
# ============================================================================

# 全局变量
TEST_TARGET=""
TEST_COMMAND=""
TEST_FRAMEWORK=""
CONFIG_FILE=".claude/testing-config.md"
ERROR_COUNT=0
OUTPUT_MODE="human"  # json|human

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
    ((ERROR_COUNT++))
}

log_debug() {
    echo -e "${BLUE}🔍${NC} $1"
}

log_progress() {
    echo -e "${BLUE}🚀${NC} $1"
}

# ============================================================================
# 输出控制函数
# ============================================================================

silent_log_info() {
    if [[ "$OUTPUT_MODE" == "human" ]]; then
        log_info "$1"
    fi
}

silent_log_error() {
    if [[ "$OUTPUT_MODE" == "human" ]]; then
        log_error "$1"
    else
        ((ERROR_COUNT++))
    fi
}

silent_log_debug() {
    if [[ "$OUTPUT_MODE" == "human" ]]; then
        log_debug "$1"
    fi
}

# ============================================================================
# 帮助和使用说明
# ============================================================================

show_usage() {
    echo "CCPM Testing Run Preprocessor Script"
    echo "用法: $0 [OPTIONS] [test_target]"
    echo ""
    echo "选项:"
    echo "  --json       输出JSON格式（供Claude使用）"
    echo "  --human      输出人类可读格式（默认）"
    echo "  -h, --help   显示帮助信息"
    echo ""
    echo "参数说明:"
    echo "  test_target  可选参数，可以是:"
    echo "               - 空值: 运行所有测试"
    echo "               - 测试文件路径: 运行特定文件"
    echo "               - 测试模式: 运行匹配的测试"
    echo "               - 测试套件名: 运行特定套件"
    echo ""
    echo "示例:"
    echo "  $0 --json                    # JSON格式，运行所有测试"
    echo "  $0 --human src/test/app.test.js   # 人类格式，运行特定文件"
}

# ============================================================================
# 参数解析函数
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                OUTPUT_MODE="json"
                shift
                ;;
            --human)
                OUTPUT_MODE="human"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                silent_log_error "未知选项: $1"
                return 1
                ;;
            *)
                TEST_TARGET="$1"
                shift
                ;;
        esac
    done
    
    return 0
}

# ============================================================================
# 环境检查函数
# ============================================================================

check_testing_config() {
    silent_log_debug "检查测试配置文件..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        silent_log_error "测试配置文件不存在: $CONFIG_FILE"
        silent_log_error "请先运行 /testing:prime 来初始化测试环境"
        return 1
    fi
    
    silent_log_info "找到测试配置文件: $CONFIG_FILE"
    return 0
}

check_test_target() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        silent_log_info "将运行所有测试"
        return 0
    fi
    
    silent_log_debug "检查测试目标: $target"
    
    # 如果是文件路径，检查文件是否存在
    if [[ -f "$target" ]]; then
        silent_log_info "找到测试文件: $target"
        return 0
    fi
    
    # 如果包含通配符，认为是模式匹配
    if [[ "$target" == *"*"* ]] || [[ "$target" == *"?"* ]]; then
        silent_log_info "使用测试模式: $target"
        return 0
    fi
    
    # 检查是否为目录
    if [[ -d "$target" ]]; then
        silent_log_info "测试目录: $target"
        return 0
    fi
    
    if [[ "$OUTPUT_MODE" == "human" ]]; then
        log_warning "测试目标可能不存在: $target"
        log_warning "将尝试作为测试套件名或模式处理"
    fi
    return 0
}

# ============================================================================
# 配置读取函数
# ============================================================================

read_testing_config() {
    silent_log_debug "读取测试配置..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        silent_log_error "无法读取配置文件: $CONFIG_FILE"
        return 1
    fi
    
    # 解析YAML frontmatter中的test_framework
    TEST_FRAMEWORK=$(grep "test_framework:" "$CONFIG_FILE" | sed 's/.*test_framework: *\(.*\)/\1/' | tr -d '"' | tr -d "'")
    
    if [[ -z "$TEST_FRAMEWORK" ]]; then
        silent_log_error "无法从配置文件读取测试框架信息"
        return 1
    fi
    
    silent_log_info "检测到测试框架: $TEST_FRAMEWORK"
    return 0
}

# ============================================================================
# 测试命令构建函数
# ============================================================================

build_test_command() {
    local target="$1"
    local base_command=""
    
    silent_log_debug "构建测试命令，框架: $TEST_FRAMEWORK，目标: ${target:-'全部'}"
    
    case "$TEST_FRAMEWORK" in
        "Jest")
            base_command="npm test"
            if [[ -n "$target" ]]; then
                # Jest支持文件路径和模式匹配
                base_command="$base_command -- \"$target\""
            fi
            base_command="$base_command --verbose --no-cache"
            ;;
        "Mocha")
            base_command="npm test"
            if [[ -n "$target" ]]; then
                if [[ -f "$target" ]]; then
                    base_command="npx mocha \"$target\""
                else
                    base_command="npx mocha --grep \"$target\""
                fi
            fi
            base_command="$base_command --reporter spec"
            ;;
        "Pytest")
            base_command="pytest"
            if [[ -n "$target" ]]; then
                base_command="$base_command \"$target\""
            fi
            base_command="$base_command -v --tb=short"
            ;;
        "Cargo")
            base_command="cargo test"
            if [[ -n "$target" ]]; then
                base_command="$base_command \"$target\""
            fi
            base_command="$base_command --verbose"
            ;;
        "Go")
            base_command="go test"
            if [[ -n "$target" ]]; then
                if [[ -f "$target" ]]; then
                    # Go测试需要包路径
                    local package_path=$(dirname "$target")
                    base_command="$base_command ./$package_path -run $(basename \"$target\" .go)"
                else
                    base_command="$base_command -run \"$target\""
                fi
            else
                base_command="$base_command ./..."
            fi
            base_command="$base_command -v"
            ;;
        *)
            silent_log_error "不支持的测试框架: $TEST_FRAMEWORK"
            return 1
            ;;
    esac
    
    TEST_COMMAND="$base_command"
    silent_log_info "构建的测试命令: $TEST_COMMAND"
    return 0
}

# ============================================================================
# JSON输出函数
# ============================================================================

output_json_config() {
    local target="$1"
    local timestamp=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
    
    cat << EOF
{
  "status": "ready",
  "timestamp": "$timestamp",
  "test_target": "${target:-all}",
  "test_framework": "$TEST_FRAMEWORK",
  "test_command": "$TEST_COMMAND",
  "config_file": "$CONFIG_FILE",
  "working_directory": "$(pwd)",
  "error_count": $ERROR_COUNT,
  "agent_prompt": "Execute tests for: ${target:-all}\\n\\nRequirements:\\n- Run with verbose output for debugging\\n- No mocks - use real services\\n- Capture full output including stack traces\\n- If test fails, check test structure before assuming code issue\\n\\nTest command to execute: $TEST_COMMAND\\n\\nPlease execute this test command and provide:\\n1. Complete stdout and stderr output\\n2. Test execution results (passed/failed/skipped counts)\\n3. Detailed failure analysis if any tests fail\\n4. Performance timing information\\n5. Any recommendations for fixing failures"
}
EOF
}

output_json_error() {
    local error_message="$1"
    local timestamp=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
    
    cat << EOF
{
  "status": "error",
  "timestamp": "$timestamp",
  "error_message": "$error_message",
  "error_count": $ERROR_COUNT
}
EOF
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    # 解析参数
    if ! parse_arguments "$@"; then
        if [[ "$OUTPUT_MODE" == "json" ]]; then
            output_json_error "参数解析失败"
        fi
        exit 1
    fi
    
    # 人类模式显示头部信息
    if [[ "$OUTPUT_MODE" == "human" ]]; then
        echo "🧪 CCPM Testing Run Preprocessor"
        echo "================================"
        echo ""
    fi
    
    # 1. 环境检查
    silent_log_debug "Step 1: 环境检查"
    if ! check_testing_config; then
        if [[ "$OUTPUT_MODE" == "json" ]]; then
            output_json_error "测试配置文件不存在，请先运行 /testing:prime"
        fi
        exit 1
    fi
    
    if ! check_test_target "$TEST_TARGET"; then
        if [[ "$OUTPUT_MODE" == "json" ]]; then
            output_json_error "测试目标验证失败: $TEST_TARGET"
        fi
        exit 1
    fi
    
    # 2. 读取配置
    silent_log_debug "Step 2: 读取测试配置"
    if ! read_testing_config; then
        if [[ "$OUTPUT_MODE" == "json" ]]; then
            output_json_error "读取测试配置失败"
        fi
        exit 1
    fi
    
    # 3. 构建测试命令
    silent_log_debug "Step 3: 构建测试命令"
    if ! build_test_command "$TEST_TARGET"; then
        if [[ "$OUTPUT_MODE" == "json" ]]; then
            output_json_error "构建测试命令失败: 不支持的测试框架 $TEST_FRAMEWORK"
        fi
        exit 1
    fi
    
    # 4. 输出结果
    if [[ "$OUTPUT_MODE" == "json" ]]; then
        output_json_config "$TEST_TARGET"
    else
        echo ""
        log_info "✅ 预处理完成！"
        echo ""
        echo "📋 测试配置:"
        echo "   框架: $TEST_FRAMEWORK"
        echo "   目标: ${TEST_TARGET:-all}"
        echo "   命令: $TEST_COMMAND"
        echo ""
        echo "🤖 下一步: Claude将调用test-runner代理执行测试"
    fi
    
    exit 0
}

# ============================================================================
# 脚本入口
# ============================================================================

# 检查是否在交互式终端中运行
if [[ ! -t 0 ]] && [[ "$OUTPUT_MODE" == "human" ]]; then
    echo "⚠️ 检测到非交互式环境"
    echo "该脚本最好在交互式终端中运行以获得最佳体验"
    echo "如果在CI/CD环境中，请确保测试框架已正确配置"
    echo ""
fi

# 执行主函数
main "$@"