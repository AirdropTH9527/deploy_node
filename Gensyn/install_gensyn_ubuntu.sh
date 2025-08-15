#!/bin/bash

set -e
set -o pipefail

# ----------- 检测操作系统 -----------
if [[ ! -f /etc/os-release ]] || ! grep -q "ubuntu" /etc/os-release; then
  echo "❌ 此脚本仅支持 Ubuntu 系统。"
  exit 1
fi

curl -s https://raw.githubusercontent.com/AirdropTH9527/deploy_node/refs/heads/main/logo.sh | bash
sleep 4

# ----------- 安装依赖 -----------
echo "📦 更新包管理器..."
sudo apt update

echo "📦 安装核心依赖..."
sudo apt install -y curl wget git

# 安装 Node.js (最新LTS版本)
echo "📦 安装 Node.js..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
  echo "✅ Node.js 安装完成"
else
  echo "✅ Node.js 已安装"
fi

# 安装 Python3
echo "📦 安装 Python3..."
sudo apt install -y python3 python3-venv python3-pip

# 安装 screen
echo "📦 安装 screen..."
sudo apt install -y screen

# 安装 yarn
echo "📦 安装 yarn..."
if ! command -v yarn &>/dev/null; then
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg
  echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  sudo apt update
  sudo apt install -y yarn
  echo "✅ yarn 安装完成"
else
  echo "✅ yarn 已安装"
fi

# 配置 Python 别名
PYTHON_ALIAS="# Python3 Environment Setup"
if ! grep -q "$PYTHON_ALIAS" ~/.bashrc; then
  cat << 'EOF' >> ~/.bashrc

# Python3 Environment Setup
if [[ $- == *i* ]]; then
  alias python="/usr/bin/python3"
  alias python3="/usr/bin/python3"
  alias pip="/usr/bin/pip3"
  alias pip3="/usr/bin/pip3"
fi
EOF
fi
source ~/.bashrc || true

# ----------- 克隆仓库 -----------
if [[ -d "rl-swarm" ]]; then
  echo "⚠️ 检测到已存在目录 'rl-swarm'"
  read -p "是否覆盖该目录？(y/n): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "🗑️ 删除旧目录..."
    rm -rf rl-swarm
  else
    echo "❌ 跳过克隆，继续后续流程"
  fi
fi

if [[ ! -d "rl-swarm" ]]; then
  echo "📥 克隆 rl-swarm 仓库..."
  git clone https://github.com/gensyn-ai/rl-swarm.git
fi

# ----------- 生成桌面可双击运行的 .desktop 文件 -----------
echo "🖥️ 生成桌面执行文件..."
CURRENT_USER=$(whoami)
PROJECT_DIR="/home/$CURRENT_USER/rl-swarm"
DESKTOP_DIR="/home/$CURRENT_USER/Desktop"
mkdir -p "$DESKTOP_DIR"

script="run_rl_swarm.sh"
desktop_name="run_rl_swarm.desktop"
cat > "$DESKTOP_DIR/$desktop_name" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=true
Exec=gnome-terminal --working-directory=$PROJECT_DIR -- bash -c "cd $PROJECT_DIR && ./$script; echo '按任意键关闭...'; read -n 1 -s"
Name=Run RL-Swarm
Comment=运行 RL-Swarm 脚本
Icon=terminal
Categories=Development;
EOF

chmod +x "$DESKTOP_DIR/$desktop_name"
echo "✅ 已生成 $desktop_name"

echo "🎉 桌面执行文件生成完成！"
echo "💡 注意：Ubuntu系统需要双击.desktop文件来运行" 