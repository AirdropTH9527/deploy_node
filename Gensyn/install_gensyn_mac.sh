#!/bin/bash

set -e
set -o pipefail

# ----------- 检测操作系统 -----------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ 此脚本仅支持 macOS 系统。"
  exit 1
fi

curl -s https://raw.githubusercontent.com/AirdropTH9527/deploy_node/refs/heads/main/logo.sh | bash
sleep 4

# ----------- 安装依赖 -----------
echo "🍺 Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "📥 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "✅ Homebrew 已安装"
fi

# 配置 Brew 环境变量
BREW_ENV='eval "$(/opt/homebrew/bin/brew shellenv)"'                                                                            
if ! grep -q "$BREW_ENV" ~/.zshrc; then
  echo "$BREW_ENV" >> ~/.zshrc
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# 安装核心依赖
echo "📦 Installing dependencies..."
brew install node python@3.10 curl screen git yarn

# 配置 Python 别名
PYTHON_ALIAS="# Python3.10 Environment Setup"
if ! grep -q "$PYTHON_ALIAS" ~/.zshrc; then
  cat << 'EOF' >> ~/.zshrc

# Python3.10 Environment Setup
if [[ $- == *i* ]]; then
  alias python="/opt/homebrew/bin/python3.10"
  alias python3="/opt/homebrew/bin/python3.10"
  alias pip="/opt/homebrew/bin/pip3.10"
  alias pip3="/opt/homebrew/bin/pip3.10"
fi
EOF
fi
source ~/.zshrc || true

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

# ----------- 生成桌面可双击运行的 .command 文件 -----------
echo "🖥️ 生成桌面执行文件..."
CURRENT_USER=$(whoami)
PROJECT_DIR="/Users/$CURRENT_USER/rl-swarm"
DESKTOP_DIR="/Users/$CURRENT_USER/Desktop"
mkdir -p "$DESKTOP_DIR"


script="run_rl_swarm.sh"
cmd_name="${script%.sh}.command"
cat > "$DESKTOP_DIR/$cmd_name" <<EOF
#!/bin/bash

# 设置错误处理
set -e

# 捕获中断信号
trap 'echo -e "\n\\033[33m⚠️ 脚本被中断，但终端将继续运行...\\033[0m"; exit 0' INT TERM

# 进入项目目录
cd "$PROJECT_DIR" || { echo "❌ 无法进入项目目录"; exit 1; }

# 切换到脚本所在目录
cd "$HOME/rl-swarm"

# ✅ 设置 MPS 环境（适用于 Mac M1/M2）
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
export PYTORCH_ENABLE_MPS_FALLBACK=1

# 激活虚拟环境并执行 run_rl_swarm.sh
if [ -d ".venv" ]; then
  echo "🔗 正在激活虚拟环境 .venv..."
  source .venv/bin/activate
else
  echo "⚠️ 未找到 .venv 虚拟环境，正在自动创建..."
  # 直接使用命令，避免变量作用域问题
  if command -v python3.10 >/dev/null 2>&1; then
    echo "🔍 使用 python3.10 创建虚拟环境..."
    python3.10 -m venv .venv
  elif command -v python3 >/dev/null 2>&1; then
    echo "🔍 使用 python3 创建虚拟环境..."
    python3 -m venv .venv
  elif command -v python >/dev/null 2>&1; then
    echo "🔍 使用 python 创建虚拟环境..."
    python -m venv .venv
  else
    echo "❌ 未找到 Python，请先安装。"
    exit 1
  fi
  
  if [ -d ".venv" ]; then
    echo "✅ 虚拟环境创建成功，正在激活..."
    source .venv/bin/activate
  else
    echo "❌ 虚拟环境创建失败，跳过激活。"
  fi
fi

# 执行脚本
echo "🚀 正在执行 $script..."
./$script

# 脚本执行完成后的提示
echo -e "\\n\\033[32m✅ $script 执行完成\\033[0m"
echo "按任意键关闭此窗口..."
read -n 1 -s
EOF
chmod +x "$DESKTOP_DIR/$cmd_name"
echo "✅ 已生成 $cmd_name"

echo "🎉 桌面执行文件生成完成！"