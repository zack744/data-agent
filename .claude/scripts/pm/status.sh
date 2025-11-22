#!/bin/bash

# ============================================================================
# CCPM Project Status Script
# 根据 .claude/commands/pm/status.md 实现
# 
# 功能：显示完整的项目状态概览，包括PRD、Epic、任务统计和健康检查
# 作者：CCPM Enhanced Project
# ============================================================================

# 全局变量
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
    NC=""
else
    # Unix环境，使用颜色
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
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
    echo "CCPM Project Status"
    echo "用法: $0 [OPTIONS]"
    echo ""
    echo "选项:"
    echo "  --json       输出JSON格式"
    echo "  --human      输出人类可读格式（默认）"
    echo "  --details    显示详细信息"
    echo "  -h, --help   显示帮助信息"
    echo ""
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

analyze_directory_structure() {
    [ "$OUTPUT_MODE" = "human" ] && log_step "检查目录结构..."
    
    # 必需目录检查
    [ ! -d ".claude" ] && log_error "缺少 .claude 目录" && return 1
    [ ! -d ".claude/prds" ] && [ "$OUTPUT_MODE" = "human" ] && log_warning "缺少 PRDs 目录"
    [ ! -d ".claude/epics" ] && [ "$OUTPUT_MODE" = "human" ] && log_warning "缺少 Epics 目录"
    
    return 0
}

analyze_prds() {
    local total=0
    local in_progress=0
    local completed=0
    
    if [ -d ".claude/prds" ]; then
        total=$(ls .claude/prds/*.md 2>/dev/null | wc -l)
        
        for prd_file in .claude/prds/*.md; do
            [ -f "$prd_file" ] || continue
            
            status=$(grep "^status:" "$prd_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "")
            case "$status" in
                completed|done)
                    ((completed++))
                    ;;
                in-progress|active)
                    ((in_progress++))
                    ;;
            esac
        done
    fi
    
    echo "$total:$in_progress:$completed"
}

analyze_epics() {
    local total=0
    local planning=0
    local in_progress=0
    local completed=0
    local synced=0
    
    if [ -d ".claude/epics" ]; then
        for epic_dir in .claude/epics/*/; do
            [ -d "$epic_dir" ] || continue
            [ -f "$epic_dir/epic.md" ] || continue
            
            ((total++))
            
            status=$(grep "^status:" "$epic_dir/epic.md" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "planning")
            github=$(grep "^github:" "$epic_dir/epic.md" 2>/dev/null | head -1 | sed 's/^github: *//' || echo "")
            
            [ -n "$github" ] && ((synced++))
            
            case "$status" in
                completed|done|closed)
                    ((completed++))
                    ;;
                in-progress|active|started)
                    ((in_progress++))
                    ;;
                *)
                    ((planning++))
                    ;;
            esac
        done
    fi
    
    echo "$total:$planning:$in_progress:$completed:$synced"
}

analyze_tasks() {
    local total=0
    local open=0
    local in_progress=0
    local blocked=0
    local closed=0
    local parallel=0
    
    if [ -d ".claude/epics" ]; then
        for task_file in .claude/epics/*/[0-9]*.md; do
            [ -f "$task_file" ] || continue
            ((total++))
            
            status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | sed 's/^status: *//' || echo "open")
            deps=$(grep "^depends_on:" "$task_file" 2>/dev/null | head -1 | sed 's/^depends_on: *\[//' | sed 's/\]//' || echo "")
            parallel_flag=$(grep "^parallel:" "$task_file" 2>/dev/null | head -1 | sed 's/^parallel: *//' || echo "false")
            
            [ "$parallel_flag" = "true" ] && ((parallel++))
            
            case "$status" in
                closed|completed|done)
                    ((closed++))
                    ;;
                in-progress|active|started)
                    ((in_progress++))
                    ;;
                open)
                    if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
                        ((blocked++))
                    else
                        ((open++))
                    fi
                    ;;
                *)
                    ((open++))
                    ;;
            esac
        done
    fi
    
    echo "$total:$open:$in_progress:$blocked:$closed:$parallel"
}

generate_health_score() {
    local score=100
    local issues=0
    
    # 检查基本结构
    [ ! -d ".claude" ] && ((issues+=20))
    [ ! -d ".claude/prds" ] && ((issues+=5))
    [ ! -d ".claude/epics" ] && ((issues+=5))
    
    # 检查数据完整性
    [ $ERROR_COUNT -gt 0 ] && ((issues+=ERROR_COUNT*10))
    [ $WARNING_COUNT -gt 0 ] && ((issues+=WARNING_COUNT*2))
    
    score=$((score - issues))
    [ $score -lt 0 ] && score=0
    
    echo $score
}

# ============================================================================
# 输出函数
# ============================================================================

output_human() {
    # 生成实时时间戳
    REAL_DATETIME=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
    
    echo "📊 Project Status Dashboard"
    echo "==========================="
    echo "⏰ Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # PRD分析
    prd_data=$(analyze_prds)
    IFS=':' read -r prd_total prd_progress prd_completed <<< "$prd_data"
    
    echo "📄 Product Requirements (PRDs):"
    if [ $prd_total -eq 0 ]; then
        echo "  📝 No PRDs found. Create your first with: /pm:prd-new <name>"
    else
        echo "  📊 Total: $prd_total"
        echo "  🚀 In Progress: $prd_progress"
        echo "  ✅ Completed: $prd_completed"
        echo "  📋 Planning: $((prd_total - prd_progress - prd_completed))"
    fi
    echo ""
    
    # Epic分析
    epic_data=$(analyze_epics)
    IFS=':' read -r epic_total epic_planning epic_progress epic_completed epic_synced <<< "$epic_data"
    
    echo "📚 Implementation Epics:"
    if [ $epic_total -eq 0 ]; then
        echo "  📝 No epics found. Parse a PRD with: /pm:prd-parse <name>"
    else
        echo "  📊 Total: $epic_total"
        echo "  📝 Planning: $epic_planning"
        echo "  🚀 In Progress: $epic_progress"
        echo "  ✅ Completed: $epic_completed"
        echo "  🔗 GitHub Synced: $epic_synced/$epic_total"
        
        # Progress bar for epics
        if [ $epic_total -gt 0 ]; then
            percent=$((epic_completed * 100 / epic_total))
            filled=$((percent * 20 / 100))
            empty=$((20 - filled))
            
            echo -n "  📈 Progress: ["
            [ $filled -gt 0 ] && printf '%0.s█' $(seq 1 $filled)
            [ $empty -gt 0 ] && printf '%0.s░' $(seq 1 $empty)
            echo "] $percent%"
        fi
    fi
    echo ""
    
    # Task分析
    task_data=$(analyze_tasks)
    IFS=':' read -r task_total task_open task_progress task_blocked task_closed task_parallel <<< "$task_data"
    
    echo "📝 Development Tasks:"
    if [ $task_total -eq 0 ]; then
        echo "  📝 No tasks found. Decompose an epic with: /pm:epic-decompose <name>"
    else
        echo "  📊 Total: $task_total"
        echo "  🔄 Available: $task_open"
        echo "  🚀 In Progress: $task_progress"
        echo "  ⏸️ Blocked: $task_blocked"
        echo "  ✅ Completed: $task_closed"
        echo "  ⚡ Parallel Enabled: $task_parallel"
        
        # Task completion bar
        if [ $task_total -gt 0 ]; then
            percent=$((task_closed * 100 / task_total))
            filled=$((percent * 20 / 100))
            empty=$((20 - filled))
            
            echo -n "  📈 Completion: ["
            [ $filled -gt 0 ] && printf '%0.s█' $(seq 1 $filled)
            [ $empty -gt 0 ] && printf '%0.s░' $(seq 1 $empty)
            echo "] $percent%"
        fi
    fi
    echo ""
    
    # 健康评分
    health_score=$(generate_health_score)
    echo "🏥 System Health:"
    if [ $health_score -ge 90 ]; then
        log_success "Score: $health_score/100 - Excellent"
    elif [ $health_score -ge 70 ]; then
        echo -e "${YELLOW}✨${NC} Score: $health_score/100 - Good"
    elif [ $health_score -ge 50 ]; then
        echo -e "${YELLOW}⚠️${NC} Score: $health_score/100 - Needs Attention"
    else
        log_error "Score: $health_score/100 - Critical Issues"
    fi
    
    [ $ERROR_COUNT -gt 0 ] && echo "  🔴 Errors: $ERROR_COUNT"
    [ $WARNING_COUNT -gt 0 ] && echo "  🟡 Warnings: $WARNING_COUNT"
    echo ""
    
    # 快速操作建议
    echo "🎯 Quick Actions:"
    if [ $prd_total -eq 0 ]; then
        echo "  📝 Start with: /pm:prd-new <feature-name>"
    elif [ $epic_total -eq 0 ]; then
        echo "  📚 Parse PRD: /pm:prd-parse <prd-name>"
    elif [ $task_total -eq 0 ]; then
        echo "  📝 Decompose Epic: /pm:epic-decompose <epic-name>"
    elif [ $epic_synced -lt $epic_total ]; then
        echo "  🔗 Sync to GitHub: /pm:epic-sync <epic-name>"
    elif [ $task_open -gt 0 ]; then
        echo "  🚀 Start Development: /pm:issue-start <task-number>"
    else
        echo "  🎉 System looks great! Check: /pm:next"
    fi
}

output_json() {
    # 生成实时时间戳
    REAL_DATETIME=$(TZ='Asia/Shanghai' date +"%Y-%m-%dT%H:%M:%S+08:00")
    
    prd_data=$(analyze_prds)
    IFS=':' read -r prd_total prd_progress prd_completed <<< "$prd_data"
    
    epic_data=$(analyze_epics)
    IFS=':' read -r epic_total epic_planning epic_progress epic_completed epic_synced <<< "$epic_data"
    
    task_data=$(analyze_tasks)
    IFS=':' read -r task_total task_open task_progress task_blocked task_closed task_parallel <<< "$task_data"
    
    health_score=$(generate_health_score)
    
    cat << EOF
{
  "timestamp": "$REAL_DATETIME",
  "prds": {
    "total": $prd_total,
    "in_progress": $prd_progress,
    "completed": $prd_completed,
    "planning": $((prd_total - prd_progress - prd_completed))
  },
  "epics": {
    "total": $epic_total,
    "planning": $epic_planning,
    "in_progress": $epic_progress,
    "completed": $epic_completed,
    "synced": $epic_synced,
    "completion_percentage": $((epic_total > 0 ? epic_completed * 100 / epic_total : 0))
  },
  "tasks": {
    "total": $task_total,
    "open": $task_open,
    "in_progress": $task_progress,
    "blocked": $task_blocked,
    "closed": $task_closed,
    "parallel_enabled": $task_parallel,
    "completion_percentage": $((task_total > 0 ? task_closed * 100 / task_total : 0))
  },
  "health": {
    "score": $health_score,
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
    
    # 检查基本结构
    if ! analyze_directory_structure; then
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