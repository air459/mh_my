#!/bin/bash

# 获取项目根目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 提示用户输入字符串 a
echo "请输入一个字符串（用于备份系统 rm 命令）："
read -r backup_name

# 确认输入
echo "请再次输入相同的字符串进行确认："
read -r confirm_name

if [ "$backup_name" != "$confirm_name" ]; then
    echo "错误：两次输入的字符串不匹配！"
    exit 1
fi

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此安装脚本"
    exit 1
fi

# 备份系统 rm 命令
if [ -f "/bin/rm" ]; then
    echo "正在备份系统 rm 命令..."
    mv "/bin/rm" "/bin/$backup_name"
    echo "系统 rm 命令已备份为: /bin/$backup_name"
else
    echo "警告：/bin/rm 不存在，跳过备份步骤"
fi

# 移动 rm.sh 到 /bin/ 并重命名为 rm
echo "正在安装自定义 rm 命令..."
cp "$PROJECT_DIR/rm.sh" "/bin/rm"
chmod +x "/bin/rm"

# 在 /bin/rm 中设置项目路径
sed -i "2i PROJECT_DIR=\"$PROJECT_DIR\"" "/bin/rm"

echo "安装完成！"
echo "自定义 rm 命令已安装到 /bin/rm"
echo "项目目录: $PROJECT_DIR"