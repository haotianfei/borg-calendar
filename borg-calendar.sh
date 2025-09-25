#!/bin/bash

# Borg Backup 日历查看器
# Author: haotianfei
# GitHub: https://github.com/haotianfei/borg-calendar
# 显示备份日历，有备份的日期用反转色高亮
# 基于归档的实际创建时间（{start}），不依赖归档名

# 仓库路径（优先使用环境变量 BORG_REPO，如未设置则使用当前路径）
BORG_REPO="${BORG_REPO:-.}"

# 自动确认访问未知未加密仓库
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

# ANSI 颜色定义
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
INVERT='\033[7m'    # 反转色（背景变白，文字变黑）
NO_INVERT='\033[27m' # 关闭反转
NC='\033[0m'        # 重置颜色

# 全局缓存：存储所有备份数据 key=YYYY-MM, value="7 15 23"（天数）
declare -A BACKUP_DATES_MAP

# 全局缓存：存储 borg list 命令的输出结果
declare BORG_LIST_OUTPUT=""

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] [年份] [月份]

显示 Borg 备份日历，有备份的日期会以反转色高亮。

参数:
    年份        要显示的年份（如 2025）
    月份        要显示的月份（1-12）

选项:
    --borg-repo PATH   指定 Borg 仓库路径（优先级最高）

环境变量:
    BORG_REPO   指定 Borg 仓库路径（优先级中等，默认是当前目录）

示例:
    $0                              # 显示从最早到最晚的所有备份月份
    $0 --borg-repo /path/to/repo    # 使用指定的仓库路径
    $0 2025                         # 显示 2025 年全年日历
    $0 2025 7                       # 显示 2025 年 7 月
    $0 7                            # 显示今年 7 月

注意：
    归档是否存在的判断基于 {start} 时间字段，与归档名无关。
    仓库路径优先级：命令行参数 > 环境变量 BORG_REPO > 当前路径
EOF
}

# 检查 borg 命令是否存在
check_borg() {
    if ! command -v borg &> /dev/null; then
        echo "错误: 'borg' 命令未找到，请先安装 BorgBackup。" >&2
        exit 1
    fi
}

# 处理密码输入
handle_password() {
    # 如果已经有 BORG_PASSPHRASE 环境变量，则直接使用
    if [[ -n "$BORG_PASSPHRASE" ]]; then
        return
    fi

    # 如果已经有缓存的列表输出，说明已经验证过仓库访问，不需要再次检查
    if [[ -n "$BORG_LIST_OUTPUT" ]]; then
        return
    fi

    # 尝试不使用密码访问仓库并缓存结果
    local temp_output
    temp_output=$(BORG_PASSPHRASE="" borg list --format '{start}{NL}' "$BORG_REPO" 2>/dev/null || true)
    
    # 如果成功获取到输出，说明仓库不需要密码
    if [[ -n "$temp_output" ]]; then
        BORG_LIST_OUTPUT="$temp_output"
        return
    fi

    # 检查仓库访问错误是否与密码相关
    local error_output
    error_output=$(BORG_PASSPHRASE="" borg list --format '{start}{NL}' "$BORG_REPO" 2>&1 || true)
    
    # 检查错误信息是否与密码相关
    if echo "$error_output" | grep -q -E "(Passphrase|password|encryption)" || 
       echo "$error_output" | grep -q "Password:" ||
       echo "$error_output" | grep -qi "passphrase"; then
        # 如果没有 BORG_PASSPHRASE，则提示用户输入
        read -s -p "请输入仓库密码: " BORG_PASSPHRASE
        echo  # 输出一个换行符
        export BORG_PASSPHRASE
    fi
}

# 加载所有备份的 start 时间并缓存
load_all_backups() {
    # 如果解析器缓存已存在，直接返回
    if [[ ${#BACKUP_DATES_MAP[@]} -gt 0 ]]; then
        return
    fi

    # 清空旧的解析缓存
    unset BACKUP_DATES_MAP
    declare -g -A BACKUP_DATES_MAP

    # 如果 handle_password 已经缓存了输出，则直接使用
    # 否则，执行一次 borg list 命令来获取数据
    if [[ -z "$BORG_LIST_OUTPUT" ]]; then
        local output
        output=$(BORG_PASSPHRASE="$BORG_PASSPHRASE" borg list --format '{start}{NL}' "$BORG_REPO" 2>&1)
        local ret=$?
        
        # 检查命令是否执行成功
        if [[ $ret -ne 0 ]]; then
            echo "错误: 执行 'borg list' 失败 (退出码: $ret):" >&2
            echo "$output" >&2
            exit 1
        fi
        
        BORG_LIST_OUTPUT="$output"
    fi

    # 解析缓存的输出结果
    while IFS= read -r line; do
        # 提取 YYYY-MM-DD 格式的日期
        date_part=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        if [ -n "$date_part" ]; then
            IFS='-' read -r year month day <<< "$date_part"
            month_padded=$(printf "%02d" "$((10#$month))")
            day_nozero=$((10#$day)) # 去前导零
            key="$year-$month_padded"
            BACKUP_DATES_MAP["$key"]+="$day_nozero "
        fi
    done <<< "$BORG_LIST_OUTPUT"

    # 对每个 key 的值进行去重和排序
    for key in "${!BACKUP_DATES_MAP[@]}"; do
        BACKUP_DATES_MAP["$key"]=$(echo "${BACKUP_DATES_MAP[$key]}" | tr ' ' '\n' | sort -nu | tr '\n' ' ')
    done
}

# 获取指定年月的天数
days_in_month() {
    local y=$1 m=$2
    case $m in
        1|3|5|7|8|10|12) echo 31 ;;
        4|6|9|11) echo 30 ;;
        2)
            if (( y % 400 == 0 || (y % 4 == 0 && y % 100 != 0) )); then
                echo 29
            else
                echo 28
            fi
            ;;
        *) echo 30 ;;
    esac
}

# 计算某天是星期几 (0=Sunday, ..., 6=Saturday)
day_of_week() {
    local y=$1 m=$2 d=$3
    (( m < 3 )) && { m=$((m + 12)); y=$((y - 1)); }
    local h=$(( (d + (13 * (m + 1)) / 5 + y + y/4 - y/100 + y/400) % 7 ))
    echo $(((h + 5) % 7))
}

# 获取指定年月的备份日期列表（空格分隔）
get_backup_dates() {
    local year=$1
    local month=$(printf "%02d" $((10#$2)))
    local key="$year-$month"
    echo "${BACKUP_DATES_MAP[$key]}"
}

# 显示单个月份日历
show_calendar() {
    local year=$1
    local month=$2
    local month_num=$((10#$month))
    local month_name_arr=("January" "February" "March" "April" "May" "June"
                          "July" "August" "September" "October" "November" "December")
    local month_name="${month_name_arr[month_num-1]}"

    # 居中显示月份和年份（21字符宽）
    printf "${YELLOW}%21s${NC}\n" "$month_name $year"
    # 显示星期标题（21字符宽）
    printf "${GREEN}%21s${NC}\n" "Su Mo Tu We Th Fr Sa"

    local first_dow=$(day_of_week "$year" "$month_num" 1)
    local days=$(days_in_month "$year" "$month_num")
    local backup_days=$(get_backup_dates "$year" "$month")

    # 打印前导空格
    for (( i=0; i<first_dow; i++ )); do
        printf "   "
    done

    # 打印日期
    for day in $(seq 1 $days); do
        dow=$(( (first_dow + day - 1) % 7 ))

        if echo "$backup_days" | grep -qw "$day"; then
            printf " ${INVERT}%2d${NO_INVERT}" "$day"
        else
            printf " %2d" "$day"
        fi

        if [ $dow -eq 6 ]; then
            printf "\n"
        fi
    done

    if [ $(( (first_dow + days - 1) % 7 )) -ne 6 ]; then
        printf "\n"
    fi
}

# 获取最早的和最晚的备份日期
get_backup_range() {
    local all_dates=()
    for key in "${!BACKUP_DATES_MAP[@]}"; do
        for day in ${BACKUP_DATES_MAP[$key]}; do
            all_dates+=("$key-$day")
        done
    done

    if [ ${#all_dates[@]} -eq 0 ]; then
        echo "error||"
        return 1
    fi

    IFS=$'\n' sorted=($(sort <<<"${all_dates[*]}"))
    unset IFS

    local earliest=${sorted[0]%-*}
    local latest=${sorted[-1]%-*}

    echo "$earliest|$latest"
}

# 显示从最早到最晚之间的所有月份
show_backup_history() {
    local range=$(get_backup_range)
    if [[ "$range" == error* ]]; then
        echo "未找到任何备份记录。"
        return 1
    fi

    local earliest_date=$(echo "$range" | cut -d'|' -f1)
    local latest_date=$(echo "$range" | cut -d'|' -f2)
    IFS='-' read -r ey em _ <<< "$earliest_date"
    IFS='-' read -r ly lm _ <<< "$latest_date"

    echo "📅 备份历史: $earliest_date 到 $latest_date"
    echo "========================================"
    
    # 按年显示备份历史
    for (( year = ey; year <= ly; year++ )); do
        show_year_calendar "$year"
        echo
    done
}

# 显示一整年的日历（3x4 格式）
show_year_calendar() {
    local year=$1
    local months=("January" "February" "March" "April" "May" "June"
                 "July" "August" "September" "October" "November" "December")

    # 年份标题居中（21*3 + 2*2 = 67 字符宽度）
    printf "\n${YELLOW}%34s${NC}\n\n" "$year"

    for row in {0..3}; do
        # 月份标题行 (每个21字符宽 + 2个空格分隔)
        for col in {0..2}; do
            idx=$((row * 3 + col))
            printf "${YELLOW}%21s${NC}" "${months[idx]} "
            if [ $col -lt 2 ]; then
                printf "|"
            fi
        done
        printf "\n"

        # 星期标题行 (每个21字符宽 + 2个空格分隔)
        for col in {0..2}; do
            printf "${GREEN}%20s${NC}" "Su Mo Tu We Th Fr Sa"
            if [ $col -lt 2 ]; then
                printf " |"
            fi
        done
        printf "\n"

        # 预计算每列的信息
        declare -a fdow_list
        declare -a days_list
        declare -a backups_list
        for col in {0..2}; do
            local m=$((row * 3 + col + 1))
            local padded_m=$(printf "%02d" "$m")
            fdow_list[col]=$(day_of_week "$year" "$m" 1)
            days_list[col]=$(days_in_month "$year" "$m")
            backups_list[col]=$(get_backup_dates "$year" "$padded_m")
        done

        # 计算最大周数
        max_weeks=0
        for col in {0..2}; do
            weeks=$(( (fdow_list[col] + days_list[col] + 6) / 7 ))
            (( weeks > max_weeks )) && max_weeks=$weeks
        done

        # 打印每周
        for (( w = 0; w < max_weeks; w++ )); do
            for col in {0..2}; do
                for d in {0..6}; do
                    current_day=$((w * 7 + d - fdow_list[col] + 1))
                    if (( current_day >= 1 && current_day <= days_list[col] )); then
                        if echo "${backups_list[col]}" | grep -qw "$current_day"; then
                            printf "${INVERT}%2d${NO_INVERT} " "$current_day"
                        else
                            printf "%2d " "$current_day"
                        fi
                    else
                        printf "   "
                    fi
                done
                
                # 每个月份后添加分隔符
                if [ $col -lt 2 ]; then
                    printf "|"
                fi
            done
            printf "\n"
        done

    done
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --borg-repo)
                BORG_REPO="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "未知选项: $1" >&2
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    check_borg
    
    # 处理密码输入
    handle_password
    
    # 设置脚本退出时清除密码
    trap 'unset BORG_PASSPHRASE' EXIT
    
    load_all_backups

    case "$#" in
        0)
            show_backup_history
            ;;
        1)
            if [[ "$1" =~ ^[0-9]{4}$ ]]; then
                show_year_calendar "$1"
            elif [[ "$1" =~ ^[0-9]{1,2}$ ]] && (( 1 <= 10#$1 && 10#$1 <= 12 )); then
                show_calendar "$(date +%Y)" "$(printf "%02d" $((10#$1)))"
            else
                show_help
                exit 1
            fi
            ;;
        2)
            if [[ "$1" =~ ^[0-9]{4}$ ]] && [[ "$2" =~ ^[0-9]{1,2}$ ]] && (( 1 <= 10#$2 && 10#$2 <= 12 )); then
                show_calendar "$1" "$(printf "%02d" $((10#$2)))"
            else
                show_help
                exit 1
            fi
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@"