#!/bin/bash

# ============================================================================
# CCPM Daily Standup Script
# 根据 .claude/commands/pm/standup.md 实现
# 
# 功能：生成日常站会报告，包括今日活动、进行中工作、下一步行动和团队统计
# 作者：CCPM Enhanced Project
# ============================================================================

# 全局变量
ERROR_COUNT=0
WARNING_COUNT=0
OUTPUT_MODE="human"
SHOW_DETAILS=false
REAL_DATETIME=""
TODAY_DATE=""
ACTIVITY_THRESHOLD=1

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

# ============================================================================
# 参数处理函数
# ============================================================================

show_usage() {
    echo "CCPM Daily Standup Report"
    echo "用法: $0 [OPTIONS]"
    echo ""
    echo "选项:"
    echo "  --json       输出JSON格式"
    echo "  --human      输出人类可读格式（默认）"
    echo "  --details    显示详细活动信息"
    echo "  --days N     显示过去N天的活动（默认：1天）"
    echo "  -h, --help   显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                # 标准日报"
    echo "  $0 --details      # 详细日报"
    echo "  $0 --days 3       # 过去3天活动"
    echo "  $0 --json         # JSON格式输出"
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
            --days)
                if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    ACTIVITY_THRESHOLD="$2"
                    shift 2
                else
                    log_error "无效的天数: $2"
                    show_usage
                    exit 1
                fi
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
                log_error "不期望的参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# 核心分析函数
# ============================================================================

validate_structure() {
    [ "$OUTPUT_MODE" = "human" ] && log_step "检查项目结构..."
    
    [ ! -d ".claude" ] && log_error "缺少 .claude 目录" && return 1
    [ ! -d ".claude/epics" ] && [ "$OUTPUT_MODE" = "human" ] && log_warning "缺少 .claude/epics 目录"
    [ ! -d ".claude/prds" ] && [ "$OUTPUT_MODE" = "human" ] && log_warning "缺少 .claude/prds 目录"
    
    return 0
}

analyze_recent_activity() {
    local threshold="$1"
    
    # 查找最近修改的文件
    local recent_files
    if command -v find >/dev/null 2>&1; then
        recent_files=$(find .claude -name "*.md" -mtime -${threshold} 2>/dev/null | grep -v ".git")
    else
        # Windows fallback
        recent_files=$(ls -la .claude/**/*.md 2>/dev/null | awk '{print $NF}')
    fi
    
    local prd_count=0
    local epic_count=0
    local task_count=0
    local update_count=0
    local total_files=0
    
    if [ -n "$recent_files" ]; then
        prd_count=$(echo "$recent_files" | grep -c "/prds/" 2>/dev/null || echo 0)
        epic_count=$(echo "$recent_files" | grep -c "/epic.md" 2>/dev/null || echo 0)
        task_count=$(echo "$recent_files" | grep -cE "/[0-9]+\.md" 2>/dev/null || echo 0)
        update_count=$(echo "$recent_files" | grep -c "/updates/" 2>/dev/null || echo 0)
        total_files=$(echo "$recent_files" | wc -l | tr -d ' ')
    fi
    
    echo "$total_files|$prd_count|$epic_count|$task_count|$update_count"
}

analyze_active_work() {
    local active_tasks=""
    local active_count=0
    
    # 查找进行中的任务
    if [ -d ".claude/epics" ]; then
        for epic_dir in .claude/epics/*/; do
            [ -d "$epic_dir" ] || continue
            local epic_name=$(basename "$epic_dir")
            
            for task_file in "$epic_dir"[0-9]*.md; do
                [ -f "$task_file" ] || continue
                
                local status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "")
                if [[ "$status" =~ ^(in-progress|active|started)$ ]]; then
                    local task_num=$(basename "$task_file" .md)
                    local task_name=$(grep "^name:" "$task_file" 2>/dev/null | head -1 | sed 's/^name: *//' || echo "Task $task_num")
                    local github=$(grep "^github:" "$task_file" 2>/dev/null | head -1 | sed 's/^github: *//' || echo "")
                    
                    active_tasks="${active_tasks}${task_num}:${task_name}:${epic_name}:${github}|"
                    ((active_count++))
                fi
            done
        done
    fi
    
    echo "$active_count|$active_tasks"
}

analyze_next_tasks() {
    local next_tasks=""
    local next_count=0
    local max_tasks=5
    
    if [ -d ".claude/epics" ]; then
        for epic_dir in .claude/epics/*/; do
            [ -d "$epic_dir" ] || continue
            [ $next_count -ge $max_tasks ] && break
            
            local epic_name=$(basename "$epic_dir")
            
            for task_file in "$epic_dir"[0-9]*.md; do
                [ -f "$task_file" ] || continue
                [ $next_count -ge $max_tasks ] && break
                
                local status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
                [ "$status" != "open" ] && continue
                
                # 检查依赖
                local deps=$(grep "^depends_on:" "$task_file" 2>/dev/null | head -1 | sed 's/^depends_on: *\[//' | sed 's/\]//' || echo "")
                local is_ready=true
                
                if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
                    # 检查依赖是否完成
                    for dep in $(echo "$deps" | tr ',' ' '); do
                        local dep_file="$epic_dir/${dep}.md"
                        if [ -f "$dep_file" ]; then
                            local dep_status=$(grep "^status:" "$dep_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
                            if [ "$dep_status" != "closed" ] && [ "$dep_status" != "completed" ] && [ "$dep_status" != "done" ]; then
                                is_ready=false
                                break
                            fi
                        else
                            is_ready=false
                            break
                        fi
                    done
                fi
                
                if [ "$is_ready" = true ]; then
                    local task_num=$(basename "$task_file" .md)
                    local task_name=$(grep "^name:" "$task_file" 2>/dev/null | head -1 | sed 's/^name: *//' || echo "Task $task_num")
                    local parallel=$(grep "^parallel:" "$task_file" 2>/dev/null | head -1 | sed 's/^parallel: *//' || echo "false")
                    
                    next_tasks="${next_tasks}${task_num}:${task_name}:${epic_name}:${parallel}|"
                    ((next_count++))
                fi
            done
        done
    fi
    
    echo "$next_count|$next_tasks"
}

analyze_project_stats() {
    local total_epics=0
    local active_epics=0
    local total_tasks=0
    local open_tasks=0
    local active_tasks=0
    local closed_tasks=0
    local blocked_tasks=0
    
    if [ -d ".claude/epics" ]; then
        # 统计Epic
        for epic_dir in .claude/epics/*/; do
            [ -d "$epic_dir" ] || continue
            [ -f "$epic_dir/epic.md" ] || continue
            ((total_epics++))
            
            local epic_status=$(grep "^status:" "$epic_dir/epic.md" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "planning")
            [[ "$epic_status" =~ ^(in-progress|active|started)$ ]] && ((active_epics++))
        done
        
        # 统计任务
        for task_file in .claude/epics/*/[0-9]*.md; do
            [ -f "$task_file" ] || continue
            ((total_tasks++))
            
            local status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
            local deps=$(grep "^depends_on:" "$task_file" 2>/dev/null | head -1 | sed 's/^depends_on: *\[//' | sed 's/\]//' || echo "")
            
            case "$status" in
                closed|completed|done)
                    ((closed_tasks++))
                    ;;
                in-progress|active|started)
                    ((active_tasks++))
                    ;;
                open)
                    if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
                        ((blocked_tasks++))
                    else
                        ((open_tasks++))
                    fi
                    ;;
                *)
                    ((open_tasks++))
                    ;;
            esac
        done
    fi
    
    echo "$total_epics:$active_epics:$total_tasks:$open_tasks:$active_tasks:$closed_tasks:$blocked_tasks"
}

generate_team_insights() {
    local activity_data="$1"
    local stats_data="$2"
    
    IFS='|' read -r total_files prd_count epic_count task_count update_count <<< "$activity_data"
    IFS=':' read -r total_epics active_epics total_tasks open_tasks active_tasks closed_tasks blocked_tasks <<< "$stats_data"
    
    local insights=""
    
    # 活动水平分析
    if [ $total_files -eq 0 ]; then
        insights="${insights}low_activity:"
    elif [ $total_files -ge 10 ]; then
        insights="${insights}high_activity:"
    else
        insights="${insights}moderate_activity:"
    fi
    
    # 进度分析
    if [ $total_tasks -gt 0 ]; then
        local completion_rate=$((closed_tasks * 100 / total_tasks))
        if [ $completion_rate -ge 80 ]; then
            insights="${insights}high_completion:"
        elif [ $completion_rate -le 20 ]; then
            insights="${insights}low_completion:"
        fi
    fi
    
    # 阻塞分析
    if [ $blocked_tasks -gt 0 ] && [ $total_tasks -gt 0 ]; then
        local blocked_rate=$((blocked_tasks * 100 / total_tasks))
        [ $blocked_rate -ge 30 ] && insights="${insights}high_blocking:"
    fi
    
    # 并行度分析
    if [ $active_tasks -ge 3 ]; then
        insights="${insights}parallel_execution:"
    elif [ $open_tasks -gt 0 ] && [ $active_tasks -eq 0 ]; then
        insights="${insights}ready_to_start:"
    fi
    
    echo "$insights"
}

# ============================================================================
# 输出函数
# ============================================================================

output_human() {
    # 生成实时时间戳
    REAL_DATETIME=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
    TODAY_DATE=$(date '+%Y-%m-%d')
    
    echo "📅 Daily Standup Report"
    echo "==========================="
    echo "📍 Date: $TODAY_DATE"
    echo "⏰ Generated: $(date '+%H:%M:%S')"
    echo ""
    
    # 分析数据
    local activity_data=$(analyze_recent_activity $ACTIVITY_THRESHOLD)
    local active_data=$(analyze_active_work)
    local next_data=$(analyze_next_tasks)
    local stats_data=$(analyze_project_stats)
    local insights=$(generate_team_insights "$activity_data" "$stats_data")
    
    IFS='|' read -r total_files prd_count epic_count task_count update_count <<< "$activity_data"
    IFS='|' read -r active_count active_tasks <<< "$active_data"
    IFS='|' read -r next_count next_tasks <<< "$next_data"
    IFS=':' read -r total_epics active_epics total_tasks open_tasks active_tasks_count closed_tasks blocked_tasks <<< "$stats_data"
    
    # 今日活动报告
    echo "📝 Recent Activity (Past ${ACTIVITY_THRESHOLD} day(s)):"
    if [ $total_files -eq 0 ]; then
        echo "  📋 No recent file changes detected"
        [ $ACTIVITY_THRESHOLD -eq 1 ] && echo "  💡 Try increasing scope with: --days 3"
    else
        echo "  📊 Total Changes: $total_files file(s)"
        [ $prd_count -gt 0 ] && echo "  📄 PRDs Modified: $prd_count"
        [ $epic_count -gt 0 ] && echo "  📚 Epics Updated: $epic_count"
        [ $task_count -gt 0 ] && echo "  📝 Tasks Modified: $task_count"
        [ $update_count -gt 0 ] && echo "  📊 Progress Updates: $update_count"
    fi
    echo ""
    
    # 进行中的工作
    echo "🚀 Currently In Progress:"
    if [ $active_count -eq 0 ]; then
        echo "  💤 No tasks currently in progress"
        [ $open_tasks -gt 0 ] && echo "  💡 Ready to start: /pm:next"
    else
        echo "  📊 Active Tasks: $active_count"
        
        if [ "$SHOW_DETAILS" = true ]; then
            IFS='|' read -ra ACTIVE <<< "$active_tasks"
            for task in "${ACTIVE[@]}"; do
                [ -z "$task" ] && continue
                IFS=':' read -r task_num task_name epic_name github <<< "$task"
                echo "  🚀 #$task_num - $task_name ($epic_name)"
                [ -n "$github" ] && echo "    🔗 $github"
            done
        else
            IFS='|' read -ra ACTIVE <<< "$active_tasks"
            local shown=0
            for task in "${ACTIVE[@]}"; do
                [ -z "$task" ] && continue
                [ $shown -ge 3 ] && break
                IFS=':' read -r task_num task_name epic_name github <<< "$task"
                echo "  🚀 #$task_num - $task_name ($epic_name)"
                ((shown++))
            done
            [ $active_count -gt 3 ] && echo "  📋 ... and $((active_count - 3)) more (use --details to see all)"
        fi
    fi
    echo ""
    
    # 下一步可执行的任务
    echo "⏭️ Next Available Tasks:"
    if [ $next_count -eq 0 ]; then
        if [ $blocked_tasks -gt 0 ]; then
            echo "  ⏸️ All ready tasks are blocked by dependencies"
            echo "  💡 Check blocked tasks: /pm:blocked"
        elif [ $open_tasks -eq 0 ]; then
            echo "  ✨ All tasks completed! Time to plan new work"
            echo "  💡 Create new Epic: /pm:prd-new <feature-name>"
        else
            echo "  🔍 No immediately available tasks found"
        fi
    else
        echo "  📊 Ready Tasks: $next_count"
        
        IFS='|' read -ra NEXT <<< "$next_tasks"
        local shown=0
        for task in "${NEXT[@]}"; do
            [ -z "$task" ] && continue
            [ $shown -ge 3 ] && [ "$SHOW_DETAILS" != true ] && break
            IFS=':' read -r task_num task_name epic_name parallel <<< "$task"
            
            local parallel_icon=""
            [ "$parallel" = "true" ] && parallel_icon=" ⚡"
            
            echo "  🔄 #$task_num - $task_name ($epic_name)$parallel_icon"
            ((shown++))
        done
        
        if [ $next_count -gt 3 ] && [ "$SHOW_DETAILS" != true ]; then
            echo "  📋 ... and $((next_count - 3)) more (use --details to see all)"
        fi
        
        echo ""
        echo "  💡 Start next task: /pm:issue-start <task-number>"
    fi
    echo ""
    
    # 项目统计
    echo "📊 Project Statistics:"
    echo "  📚 Epics: $active_epics active, $total_epics total"
    echo "  📝 Tasks: $active_tasks_count in progress, $open_tasks ready, $closed_tasks completed"
    [ $blocked_tasks -gt 0 ] && echo "  ⏸️ Blocked: $blocked_tasks tasks waiting for dependencies"
    
    # 计算完成率
    if [ $total_tasks -gt 0 ]; then
        local completion_rate=$((closed_tasks * 100 / total_tasks))
        echo "  📈 Completion: $completion_rate% ($closed_tasks/$total_tasks)"
    fi
    echo ""
    
    # 智能洞察
    echo "🧠 Team Insights:"
    if [[ "$insights" == *"high_activity:"* ]]; then
        echo "  🔥 High activity level - great momentum!"
    elif [[ "$insights" == *"low_activity:"* ]]; then
        echo "  📉 Low recent activity - consider daily check-ins"
    fi
    
    if [[ "$insights" == *"high_completion:"* ]]; then
        echo "  🎯 Excellent completion rate - team is delivering well"
    elif [[ "$insights" == *"low_completion:"* ]]; then
        echo "  📋 Many tasks in progress - focus on completion"
    fi
    
    if [[ "$insights" == *"high_blocking:"* ]]; then
        echo "  🚫 High blocking rate - review task dependencies"
    fi
    
    if [[ "$insights" == *"parallel_execution:"* ]]; then
        echo "  ⚡ Good parallel execution - multiple streams active"
    elif [[ "$insights" == *"ready_to_start:"* ]]; then
        echo "  🚀 Ready to start new work - pick up available tasks"
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
    TODAY_DATE=$(date '+%Y-%m-%d')
    
    # 分析数据
    local activity_data=$(analyze_recent_activity $ACTIVITY_THRESHOLD)
    local active_data=$(analyze_active_work)
    local next_data=$(analyze_next_tasks)
    local stats_data=$(analyze_project_stats)
    local insights=$(generate_team_insights "$activity_data" "$stats_data")
    
    IFS='|' read -r total_files prd_count epic_count task_count update_count <<< "$activity_data"
    IFS='|' read -r active_count active_tasks <<< "$active_data"
    IFS='|' read -r next_count next_tasks <<< "$next_data"
    IFS=':' read -r total_epics active_epics total_tasks open_tasks active_tasks_count closed_tasks blocked_tasks <<< "$stats_data"
    
    # 构建活动任务JSON
    local active_json="[]"
    if [ $active_count -gt 0 ]; then
        IFS='|' read -ra ACTIVE <<< "$active_tasks"
        active_json="["
        local first=true
        for task in "${ACTIVE[@]}"; do
            [ -z "$task" ] && continue
            IFS=':' read -r task_num task_name epic_name github <<< "$task"
            
            [ "$first" = false ] && active_json="$active_json,"
            active_json="$active_json{\"number\":\"$task_num\",\"name\":\"$task_name\",\"epic\":\"$epic_name\",\"github\":\"$github\"}"
            first=false
        done
        active_json="$active_json]"
    fi
    
    # 构建下一步任务JSON
    local next_json="[]"
    if [ $next_count -gt 0 ]; then
        IFS='|' read -ra NEXT <<< "$next_tasks"
        next_json="["
        local first=true
        for task in "${NEXT[@]}"; do
            [ -z "$task" ] && continue
            IFS=':' read -r task_num task_name epic_name parallel <<< "$task"
            
            [ "$first" = false ] && next_json="$next_json,"
            next_json="$next_json{\"number\":\"$task_num\",\"name\":\"$task_name\",\"epic\":\"$epic_name\",\"parallel\":$([[ "$parallel" == "true" ]] && echo true || echo false)}"
            first=false
        done
        next_json="$next_json]"
    fi
    
    cat << EOF
{
  "timestamp": "$REAL_DATETIME",
  "date": "$TODAY_DATE",
  "activity_period_days": $ACTIVITY_THRESHOLD,
  "recent_activity": {
    "total_files": $total_files,
    "prds_modified": $prd_count,
    "epics_updated": $epic_count,
    "tasks_modified": $task_count,
    "progress_updates": $update_count
  },
  "current_work": {
    "active_count": $active_count,
    "tasks": $active_json
  },
  "next_tasks": {
    "available_count": $next_count,
    "tasks": $next_json
  },
  "project_stats": {
    "epics": {
      "total": $total_epics,
      "active": $active_epics
    },
    "tasks": {
      "total": $total_tasks,
      "open": $open_tasks,
      "in_progress": $active_tasks_count,
      "completed": $closed_tasks,
      "blocked": $blocked_tasks,
      "completion_percentage": $((total_tasks > 0 ? closed_tasks * 100 / total_tasks : 0))
    }
  },
  "insights": "$insights",
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
    
    # 验证项目结构
    if ! validate_structure; then
        if [ "$OUTPUT_MODE" = "json" ]; then
            echo '{"error": "Invalid CCPM directory structure", "timestamp": "'$(TZ='Asia/Shanghai' date +'%Y-%m-%dT%H:%M:%S+08:00')'"}' 
        else
            log_error "无效的CCPM目录结构"
            echo ""
            echo "💡 初始化项目: /pm:init"
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