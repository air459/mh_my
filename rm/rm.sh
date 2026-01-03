#!/bin/bash

# 项目目录（由 install.sh 设置）
PROJECT_DIR="/opt/mh_my/rm"

# 记录文件路径
RECORD_FILE="$PROJECT_DIR/.rm_record"

# 删除文件存储目录
REMOVE_DIR="$PROJECT_DIR/remove"

# 日志目录
LOG_DIR="$PROJECT_DIR/log"

# 初始化
init() {
    # 确保目录存在
    mkdir -p "$REMOVE_DIR"
    mkdir -p "$LOG_DIR"
    
    # 确保记录文件存在
    touch "$RECORD_FILE"
}

# 生成随机字符串
generate_random_string() {
    openssl rand -hex 16
}

# 删除文件（移动到 remove 目录）
delete_file() {
    local file="$1"
    local force="$2"
    local recursive="$3"
    
    # 检查文件是否存在
    if [ ! -e "$file" ]; then
        echo "错误：文件或目录 '$file' 不存在"
        return 1
    fi
    
    # 如果是目录且没有递归标志
    if [ -d "$file" ] && [ "$recursive" = "false" ]; then
        echo "错误：'$file' 是一个目录，请使用 -r 参数"
        return 1
    fi
    
    # 获取绝对路径
    local abs_path
    abs_path=$(realpath "$file")
    
    # 获取文件名
    local filename
    filename=$(basename "$file")
    
    # 生成随机字符串
    local random_str
    random_str=$(generate_random_string)
    
    # 移动文件到 remove 目录
    if [ "$recursive" = "true" ]; then
        mv "$file" "$REMOVE_DIR/$random_str"
    else
        mv "$file" "$REMOVE_DIR/$random_str"
    fi
    
    # 记录信息
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$abs_path|$filename|$random_str" >> "$RECORD_FILE"
    
    echo "文件已安全删除: $file"
    echo "恢复ID: $random_str"
}

# 恢复所有文件
restore_all() {
    if [ ! -f "$RECORD_FILE" ] || [ ! -s "$RECORD_FILE" ]; then
        echo "没有可恢复的文件"
        return 0
    fi
    
    local count=0
    while IFS='|' read -r timestamp old_path old_name random_str; do
        if [ -z "$timestamp" ]; then
            continue
        fi
        
        local new_path="$REMOVE_DIR/$random_str"
        
        if [ -e "$new_path" ]; then
            # 恢复文件到原位置
            mkdir -p "$(dirname "$old_path")"
            mv "$new_path" "$old_path"
            echo "已恢复: $old_path"
            ((count++))
        fi
    done < "$RECORD_FILE"
    
    # 清空记录文件
    > "$RECORD_FILE"
    echo "共恢复了 $count 个文件"
}

# 恢复指定文件
restore_file() {
    local target="$1"
    local restore_path="$2"
    
    if [ ! -f "$RECORD_FILE" ] || [ ! -s "$RECORD_FILE" ]; then
        echo "没有可恢复的文件"
        return 0
    fi
    
    local found=false
    local temp_file=$(mktemp)
    local conflict_found=false
    local conflict_timestamp=""
    
    # 首先检查是否有重名冲突
    if [ -n "$restore_path" ]; then
        while IFS='|' read -r timestamp old_path old_name random_str; do
            if [ -z "$timestamp" ]; then
                continue
            fi
            
            if [ "$target" = "$old_name" ] || [ "$target" = "$random_str" ]; then
                local final_path="$restore_path/$old_name"
                if [ -e "$final_path" ]; then
                    conflict_found=true
                    conflict_timestamp="$timestamp"
                    break
                fi
            fi
        done < "$RECORD_FILE"
        
        # 如果有冲突，询问用户
        if [ "$conflict_found" = "true" ]; then
            echo "警告：目标位置已存在同名文件 '$target'"
            echo "该文件的删除日期: $conflict_timestamp"
            echo "是否覆盖？(y/n)"
            read -r answer
            if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
                echo "已取消恢复操作"
                return 0
            fi
        fi
    fi
    
    # 重新遍历记录文件进行恢复
    while IFS='|' read -r timestamp old_path old_name random_str; do
        if [ -z "$timestamp" ]; then
            echo "$timestamp|$old_path|$old_name|$random_str" >> "$temp_file"
            continue
        fi
        
        # 检查是否匹配（通过文件名或随机字符串）
        if [ "$target" = "$old_name" ] || [ "$target" = "$random_str" ]; then
            local new_path="$REMOVE_DIR/$random_str"
            
            if [ -e "$new_path" ]; then
                # 确定恢复路径
                local final_path
                if [ -n "$restore_path" ]; then
                    final_path="$restore_path/$old_name"
                else
                    final_path="$old_path"
                fi
                
                # 恢复文件
                mkdir -p "$(dirname "$final_path")"
                mv "$new_path" "$final_path"
                echo "已恢复: $final_path"
                found=true
            fi
        else
            # 保留未匹配的记录
            echo "$timestamp|$old_path|$old_name|$random_str" >> "$temp_file"
        fi
    done < "$RECORD_FILE"
    
    # 更新记录文件
    mv "$temp_file" "$RECORD_FILE"
    
    if [ "$found" = "false" ]; then
        echo "未找到匹配的文件: $target"
    fi
}

# 显示删除记录
list_deleted() {
    if [ ! -f "$RECORD_FILE" ] || [ ! -s "$RECORD_FILE" ]; then
        echo "没有删除记录"
        return 0
    fi
    
    echo "删除记录："
    echo "----------------------------------------"
    printf "%-20s %-50s %-20s %-20s\n" "时间" "原路径" "文件名" "恢复ID"
    echo "----------------------------------------"
    
    while IFS='|' read -r timestamp old_path old_name random_str; do
        if [ -z "$timestamp" ]; then
            continue
        fi
        printf "%-20s %-50s %-20s %-20s\n" "$timestamp" "$old_path" "$old_name" "$random_str"
    done < "$RECORD_FILE"
    
    echo "----------------------------------------"
}

# 显示帮助信息
show_help() {
    echo "安全删除和恢复工具"
    echo ""
    echo "用法："
    echo "  rm [选项] [文件]"
    echo ""
    echo "删除选项："
    echo "  -f          强制删除"
    echo "  -r, -R      递归删除目录"
    echo "  -rf         强制递归删除"
    echo ""
    echo "恢复选项："
    echo "  -m          恢复所有已删除的文件"
    echo "  -m <文件>   恢复指定文件（通过文件名或恢复ID）"
    echo "  -m <文件> <路径>  恢复文件到指定路径"
    echo ""
    echo "其他选项："
    echo "  -l          显示删除记录"
    echo "  -h, --help  显示帮助信息"
    echo ""
    echo "注意：此工具将文件移动到安全位置而不是永久删除"
}

# 主函数
main() {
    init
    
    # 解析参数
    local force=false
    local recursive=false
    local restore_mode=false
    local list_mode=false
    local target_file=""
    local restore_path=""
    local files=()
    
    # 检查是否有参数
    if [ $# -eq 0 ]; then
        show_help
        return 0
    fi
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -f)
                force=true
                shift
                ;;
            -r|-R)
                recursive=true
                shift
                ;;
            -rf)
                force=true
                recursive=true
                shift
                ;;
            -m)
                restore_mode=true
                shift
                if [ $# -gt 0 ] && [[ ! "$1" =~ ^- ]]; then
                    target_file="$1"
                    shift
                    if [ $# -gt 0 ] && [[ ! "$1" =~ ^- ]]; then
                        restore_path="$1"
                        shift
                    fi
                fi
                ;;
            -l)
                list_mode=true
                shift
                ;;
            -h|--help)
                show_help
                return 0
                ;;
            -*)
                echo "未知选项: $1"
                show_help
                return 1
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done
    
    # 执行相应操作
    if [ "$list_mode" = true ]; then
        list_deleted
    elif [ "$restore_mode" = true ]; then
        if [ -z "$target_file" ]; then
            restore_all
        else
            restore_file "$target_file" "$restore_path"
        fi
    elif [ ${#files[@]} -gt 0 ]; then
        for file in "${files[@]}"; do
            delete_file "$file" "$force" "$recursive"
        done
    else
        show_help
    fi
}

# 运行主函数
main "$@"