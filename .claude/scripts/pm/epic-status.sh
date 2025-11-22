#!/bin/bash

# ============================================================================
# CCPM Epic Status Script
# 根据 .claude/commands/pm/epic-status.md 实现
# 
# 功能：显示指定Epic的详细状态信息，包括任务分析、进度追踪和GitHub同步状态
# 作者：CCPM Enhanced Project
# ============================================================================

# 全局变量
EPIC_NAME=""
ERROR_COUNT=0
WARNING_COUNT=0
OUTPUT_MODE="human"
SHOW_DETAILS=false
REAL_DATETIME=""

# 颜色定义（跨平台兼容）
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows环境，使用简单输出
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    PURPLE=""
    NC=""
else
    # Unix环境，使用颜色
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
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
    ((WARNING_COUNT++))
}

log_error() {
    echo -e "${RED}❌${NC} $1"
    ((ERROR_COUNT++))
}

log_step() {
    echo -e "${BLUE}🔍${NC} $1"
}

log_success() {
    echo -e "${GREEN}🎉${NC} $1"
}

log_stat() {
    echo -e "${CYAN}📊${NC} $1"
}

log_epic() {
    echo -e "${PURPLE}📚${NC} $1"
}

# ============================================================================
# 参数处理函数
# ============================================================================

show_usage() {
    echo "CCPM Epic Status"
    echo "用法: $0 [OPTIONS] <epic-name>"
    echo ""
    echo "参数:"
    echo "  epic-name    要查看的Epic名称"
    echo ""
    echo "选项:"
    echo "  --json       输出JSON格式"
    echo "  --human      输出人类可读格式（默认）"
    echo "  --details    显示详细任务信息"
    echo "  -h, --help   显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 user-auth"
    echo "  $0 --json user-auth"
    echo "  $0 --details user-auth"
}

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
            --details)
                SHOW_DETAILS=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$EPIC_NAME" ]; then
                    EPIC_NAME="$1"
                else
                    log_error "多余的参数: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 检查必需参数
    if [ -z "$EPIC_NAME" ]; then
        log_error "请指定Epic名称"
        show_usage
        exit 1
    fi
}

# ============================================================================
# 工具函数
# ============================================================================

list_available_epics() {
    echo "Available epics:"
    if [ -d ".claude/epics" ]; then
        local found=false
        for dir in .claude/epics/*/; do
            if [ -d "$dir" ] && [ -f "$dir/epic.md" ]; then
                echo "  • $(basename "$dir")"
                found=true
            fi
        done
        [ "$found" = false ] && echo "  (none found)"
    else
        echo "  (no .claude/epics directory)"
    fi
}

# ============================================================================
# 核心分析函数
# ============================================================================

validate_epic() {
    [ "$OUTPUT_MODE" = "human" ] && log_step "验证Epic存在性..."
    
    local epic_dir=".claude/epics/$EPIC_NAME"
    local epic_file="$epic_dir/epic.md"
    
    # 检查目录结构
    [ ! -d ".claude" ] && log_error "缺少 .claude 目录" && return 1
    [ ! -d ".claude/epics" ] && log_error "缺少 .claude/epics 目录" && return 1
    
    # 检查Epic存在性
    if [ ! -d "$epic_dir" ]; then
        log_error "Epic目录不存在: $EPIC_NAME"
        [ "$OUTPUT_MODE" = "human" ] && echo "" && list_available_epics
        return 1
    fi
    
    if [ ! -f "$epic_file" ]; then
        log_error "Epic文件不存在: $epic_file"
        [ "$OUTPUT_MODE" = "human" ] && echo "" && list_available_epics
        return 1
    fi
    
    return 0
}

analyze_epic_metadata() {
    local epic_file=".claude/epics/$EPIC_NAME/epic.md"
    
    # 提取基本信息，使用管道分隔符避免冒号冲突
    local name=$(grep "^name:" "$epic_file" 2>/dev/null | head -1 | sed 's/^name: *//' || echo "$EPIC_NAME")
    local status=$(grep "^status:" "$epic_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "planning")
    local priority=$(grep "^priority:" "$epic_file" 2>/dev/null | head -1 | sed 's/^priority: *//' || echo "medium")
    local created=$(grep "^created:" "$epic_file" 2>/dev/null | head -1 | sed 's/^created: *//' || echo "")
    local updated=$(grep "^updated:" "$epic_file" 2>/dev/null | head -1 | sed 's/^updated: *//' || echo "")
    local github=$(grep "^github:" "$epic_file" 2>/dev/null | head -1 | sed 's/^github: *//' || echo "")
    local progress=$(grep "^progress:" "$epic_file" 2>/dev/null | head -1 | sed 's/^progress: *//' || echo "0%")
    
    echo "$name|$status|$priority|$created|$updated|$github|$progress"
}

analyze_epic_tasks() {
    local epic_dir=".claude/epics/$EPIC_NAME"
    
    local total=0
    local open=0
    local in_progress=0
    local blocked=0
    local closed=0
    local parallel=0
    local has_dependencies=0
    
    # 分析所有任务文件
    for task_file in "$epic_dir"/[0-9]*.md; do
        [ -f "$task_file" ] || continue
        ((total++))
        
        local task_status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
        local deps=$(grep "^depends_on:" "$task_file" 2>/dev/null | head -1 | sed 's/^depends_on: *\[//' | sed 's/\]//' || echo "")
        local parallel_flag=$(grep "^parallel:" "$task_file" 2>/dev/null | head -1 | sed 's/^parallel: *//' || echo "false")
        
        # 统计并行任务
        [ "$parallel_flag" = "true" ] && ((parallel++))
        
        # 统计有依赖的任务
        [ -n "$deps" ] && [ "$deps" != "depends_on:" ] && ((has_dependencies++))
        
        # 分类任务状态
        case "$task_status" in
            closed|completed|done)
                ((closed++))
                ;;
            in-progress|active|started)
                ((in_progress++))
                ;;
            open)
                if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
                    # 检查依赖是否完成
                    local is_blocked=false
                    for dep in $(echo "$deps" | tr ',' ' '); do
                        local dep_file="$epic_dir/${dep}.md"
                        if [ -f "$dep_file" ]; then
                            local dep_status=$(grep "^status:" "$dep_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
                            if [ "$dep_status" != "closed" ] && [ "$dep_status" != "completed" ] && [ "$dep_status" != "done" ]; then
                                is_blocked=true
                                break
                            fi
                        else
                            is_blocked=true
                            break
                        fi
                    done
                    
                    if [ "$is_blocked" = true ]; then
                        ((blocked++))
                    else
                        ((open++))
                    fi
                else
                    ((open++))
                fi
                ;;
            *)
                ((open++))
                ;;
        esac
    done
    
    echo "$total:$open:$in_progress:$blocked:$closed:$parallel:$has_dependencies"
}

get_task_details() {
    local epic_dir=".claude/epics/$EPIC_NAME"
    local details=""
    
    for task_file in "$epic_dir"/[0-9]*.md; do
        [ -f "$task_file" ] || continue
        
        local task_num=$(basename "$task_file" .md)
        local task_name=$(grep "^name:" "$task_file" 2>/dev/null | head -1 | sed 's/^name: *//' || echo "Task $task_num")
        local task_status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
        local parallel_flag=$(grep "^parallel:" "$task_file" 2>/dev/null | head -1 | sed 's/^parallel: *//' || echo "false")
        local deps=$(grep "^depends_on:" "$task_file" 2>/dev/null | head -1 | sed 's/^depends_on: *\[//' | sed 's/\]//' || echo "")
        
        details="${details}${task_num}:${task_name}:${task_status}:${parallel_flag}:${deps}|"
    done
    
    echo "$details"
}

generate_recommendations() {
    local epic_data="$1"
    local task_data="$2"
    
    IFS='|' read -r name status priority created updated github progress <<< "$epic_data"
    IFS=':' read -r total open in_progress blocked closed parallel has_dependencies <<< "$task_data"
    
    local recommendations=""
    
    # 基于状态生成建议
    if [ $total -eq 0 ]; then
        recommendations="${recommendations}decompose:"
    elif [ -z "$github" ]; then
        recommendations="${recommendations}sync:"
    elif [ $open -gt 0 ] && [ $blocked -eq 0 ]; then
        recommendations="${recommendations}start:"
    elif [ $blocked -gt 0 ]; then
        recommendations="${recommendations}unblock:"
    elif [ $in_progress -gt 0 ]; then
        recommendations="${recommendations}continue:"
    elif [ $closed -eq $total ]; then
        recommendations="${recommendations}complete:"
    fi
    
    echo "$recommendations"
}

# ============================================================================
# 输出函数
# ============================================================================

output_human() {
    # 生成实时时间戳
    REAL_DATETIME=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
    
    # 获取Epic数据
    local epic_data=$(analyze_epic_metadata)
    local task_data=$(analyze_epic_tasks)
    local recommendations=$(generate_recommendations "$epic_data" "$task_data")
    
    IFS='|' read -r name status priority created updated github progress <<< "$epic_data"
    IFS=':' read -r total open in_progress blocked closed parallel has_dependencies <<< "$task_data"
    
    echo "📚 Epic Status: $name"
    echo "=================================="
    echo "⏰ Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Epic基本信息
    echo "📋 Epic Information:"
    echo "  📛 Name: $name"
    echo "  📊 Status: $status"
    echo "  🎯 Priority: $priority"
    [ -n "$created" ] && echo "  📅 Created: $created"
    [ -n "$updated" ] && echo "  📝 Updated: $updated"
    [ -n "$github" ] && echo "  🔗 GitHub: $github"
    echo ""
    
    # 任务统计
    echo "📝 Task Analysis:"
    if [ $total -eq 0 ]; then
        echo "  📝 No tasks found. Decompose epic with: /pm:epic-decompose $EPIC_NAME"
    else
        echo "  📊 Total Tasks: $total"
        echo "  🔄 Available: $open"
        echo "  🚀 In Progress: $in_progress"
        echo "  ⏸️ Blocked: $blocked"
        echo "  ✅ Completed: $closed"
        echo "  ⚡ Parallel Enabled: $parallel"
        echo "  🔗 With Dependencies: $has_dependencies"
        
        # 进度条
        if [ $total -gt 0 ]; then
            local percent=$((closed * 100 / total))
            local filled=$((percent * 20 / 100))
            local empty=$((20 - filled))
            
            echo -n "  📈 Progress: ["
            [ $filled -gt 0 ] && printf '%0.s█' $(seq 1 $filled)
            [ $empty -gt 0 ] && printf '%0.s░' $(seq 1 $empty)
            echo "] $percent% ($closed/$total completed)"
        fi
    fi
    echo ""
    
    # 详细任务列表（如果启用）
    if [ "$SHOW_DETAILS" = true ] && [ $total -gt 0 ]; then
        echo "📋 Task Details:"
        local task_details=$(get_task_details)
        IFS='|' read -ra TASKS <<< "$task_details"
        
        for task in "${TASKS[@]}"; do
            [ -z "$task" ] && continue
            IFS=':' read -r task_num task_name task_status parallel_flag deps <<< "$task"
            
            # 状态图标
            local status_icon=""
            case "$task_status" in
                closed|completed|done) status_icon="✅" ;;
                in-progress|active|started) status_icon="🚀" ;;
                open) 
                    if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
                        status_icon="⏸️"
                    else
                        status_icon="🔄"
                    fi ;;
                *) status_icon="❓" ;;
            esac
            
            echo "  $status_icon #$task_num - $task_name"
            [ "$parallel_flag" = "true" ] && echo "    ⚡ Parallel execution enabled"
            [ -n "$deps" ] && [ "$deps" != "depends_on:" ] && echo "    🔗 Depends on: [$deps]"
        done
        echo ""
    fi
    
    # 智能建议
    echo "🎯 Recommendations:"
    if [[ "$recommendations" == *"decompose:"* ]]; then
        echo "  📝 Decompose epic into tasks: /pm:epic-decompose $EPIC_NAME"
    elif [[ "$recommendations" == *"sync:"* ]]; then
        echo "  🔗 Sync to GitHub: /pm:epic-sync $EPIC_NAME"
    elif [[ "$recommendations" == *"start:"* ]]; then
        echo "  🚀 Start development: /pm:issue-start <task-number>"
        echo "  🔄 Check next available: /pm:next"
    elif [[ "$recommendations" == *"unblock:"* ]]; then
        echo "  ⏸️ Check blocked tasks: /pm:blocked"
        echo "  🔗 Review dependencies and complete prerequisite tasks"
    elif [[ "$recommendations" == *"continue:"* ]]; then
        echo "  🚀 Continue work in progress: /pm:in-progress"
        echo "  📊 Sync progress updates: /pm:issue-sync <task-number>"
    elif [[ "$recommendations" == *"complete:"* ]]; then
        echo "  🎉 All tasks completed! Consider closing epic: /pm:epic-close $EPIC_NAME"
    else
        echo "  📊 Epic status looks good. Check overall progress: /pm:status"
    fi
    
    # 健康检查
    if [ $ERROR_COUNT -gt 0 ] || [ $WARNING_COUNT -gt 0 ]; then
        echo ""
        echo "🏥 Health Check:"
        [ $ERROR_COUNT -gt 0 ] && echo "  🔴 Errors: $ERROR_COUNT"
        [ $WARNING_COUNT -gt 0 ] && echo "  🟡 Warnings: $WARNING_COUNT"
    fi
}

output_json() {
    # 生成实时时间戳
    REAL_DATETIME=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
    
    # 获取数据
    local epic_data=$(analyze_epic_metadata)
    local task_data=$(analyze_epic_tasks)
    local recommendations=$(generate_recommendations "$epic_data" "$task_data")
    
    IFS='|' read -r name status priority created updated github progress <<< "$epic_data"
    IFS=':' read -r total open in_progress blocked closed parallel has_dependencies <<< "$task_data"
    
    # 构建任务详情JSON（如果启用）
    local tasks_json="[]"
    if [ "$SHOW_DETAILS" = true ] && [ $total -gt 0 ]; then
        local task_details=$(get_task_details)
        IFS='|' read -ra TASKS <<< "$task_details"
        
        tasks_json="["
        local first=true
        for task in "${TASKS[@]}"; do
            [ -z "$task" ] && continue
            IFS=':' read -r task_num task_name task_status parallel_flag deps <<< "$task"
            
            [ "$first" = false ] && tasks_json="$tasks_json,"
            tasks_json="$tasks_json{\"number\":\"$task_num\",\"name\":\"$task_name\",\"status\":\"$task_status\",\"parallel\":$([[ \"$parallel_flag\" == \"true\" ]] && echo true || echo false),\"dependencies\":\"$deps\"}"
            first=false
        done
        tasks_json="$tasks_json]"
    fi
    
    cat << EOF
{
  "timestamp": "$REAL_DATETIME",
  "epic": {
    "name": "$name",
    "status": "$status",
    "progress": "$progress",
    "priority": "$priority",
    "created": "$created",
    "updated": "$updated",
    "github": "$github"
  },
  "tasks": {
    "total": $total,
    "open": $open,
    "in_progress": $in_progress,
    "blocked": $blocked,
    "closed": $closed,
    "parallel_enabled": $parallel,
    "with_dependencies": $has_dependencies,
    "completion_percentage": $((total > 0 ? closed * 100 / total : 0)),
    "details": $tasks_json
  },
  "recommendations": "$recommendations",
  "health": {
    "errors": $ERROR_COUNT,
    "warnings": $WARNING_COUNT
  }
}
EOF
}

# ============================================================================
# 主程序
# ============================================================================

main() {
    # 解析参数
    parse_arguments "$@"
    
    # 验证Epic存在性
    if ! validate_epic; then
        if [ "$OUTPUT_MODE" = "json" ]; then
            echo '{"error": "Epic not found: '"$EPIC_NAME"'", "timestamp": "'$(TZ='Asia/Shanghai' date +'%Y-%m-%dT%H:%M:%S+08:00')'"}'
        fi
        exit 1
    fi
    
    # 输出结果
    if [ "$OUTPUT_MODE" = "json" ]; then
        output_json
    else
        output_human
    fi
    
    # 退出码
    [ $ERROR_COUNT -gt 0 ] && exit 1
    exit 0
}

# 执行主程序
main "$@"