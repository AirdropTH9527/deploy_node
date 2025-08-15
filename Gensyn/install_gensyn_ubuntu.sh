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

# 切换到脚本所在目录
cd "$HOME/rl-swarm"

# 激活虚拟环境并执行 auto_run.sh
if [ -d ".venv" ]; then
  echo "🔗 正在激活虚拟环境 .venv..."
  source .venv/bin/activate
else
  echo "⚠️ 未找到 .venv 虚拟环境，正在自动创建..."
  if command -v python3.10 >/dev/null 2>&1; then
    PYTHON=python3.10
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
  else
    echo "❌ 未找到 Python 3.10 或 python3，请先安装。"
    exit 1
  fi
  $PYTHON -m venv .venv
  if [ -d ".venv" ]; then
    echo "✅ 虚拟环境创建成功，正在激活..."
    source .venv/bin/activate
    # 检查并安装web3
    if ! python -c "import web3" 2>/dev/null; then
      echo "⚙️ 正在为虚拟环境安装 web3..."
      pip install web3
    fi
  else
    echo "❌ 虚拟环境创建失败，跳过激活。"
  fi
fi

# 执行 run_rl_swarm.sh
if [ -f "./run_rl_swarm.sh" ]; then
  echo "🚀 执行 ./run_rl_swarm.sh ..."
  ./run_rl_swarm.sh
else
  echo "❌ 未找到 run_rl_swarm.sh，无法执行。"
fi