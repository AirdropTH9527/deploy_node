#!/bin/bash

CYAN='\033[0;36m'
LIGHTBLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
PURPLE='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

curl -s https://raw.githubusercontent.com/zunxbt/logo/main/logo.sh | bash
sleep 3

echo -e "\n${CYAN}${BOLD}---- 检查Docker安装状态 ----${RESET}\n"
if ! command -v docker &> /dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}未找到Docker，正在安装Docker Desktop...${RESET}"
  echo -e "${LIGHTBLUE}${BOLD}请访问 https://www.docker.com/products/docker-desktop 下载并安装Docker Desktop${RESET}"
  echo -e "${LIGHTBLUE}${BOLD}安装完成后，请重新运行此脚本${RESET}"
  exit 1
fi

echo -e "${LIGHTBLUE}${BOLD}正在检查Docker运行状态...${RESET}"
if ! docker info &>/dev/null; then
  echo -e "${RED}${BOLD}Docker未运行，请启动Docker Desktop应用程序${RESET}"
  echo -e "${LIGHTBLUE}${BOLD}启动Docker Desktop后，请重新运行此脚本${RESET}"
  exit 1
else
  echo -e "${GREEN}${BOLD}Docker正在运行。${RESET}"
fi

echo -e "\n${CYAN}${BOLD}---- 安装依赖包 ----${RESET}\n"
if ! command -v brew &> /dev/null; then
  echo -e "${LIGHTBLUE}${BOLD}未找到Homebrew，正在安装...${RESET}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo -e "${GREEN}${BOLD}Homebrew安装成功！${RESET}"
fi

echo -e "${LIGHTBLUE}${BOLD}正在安装必要的依赖包...${RESET}"
brew install curl screen net-tools jq

[ -d /root/.aztec/alpha-testnet ] && rm -r /root/.aztec/alpha-testnet

AZTEC_PATH=$HOME/.aztec
BIN_PATH=$AZTEC_PATH/bin
mkdir -p $BIN_PATH

echo -e "\n${CYAN}${BOLD}---- 安装Aztec工具包 ----${RESET}\n"

curl -fsSL https://install.aztec.network | bash

if ! command -v aztec >/dev/null 2>&1; then
    echo -e "${LIGHTBLUE}${BOLD}Aztec CLI未在PATH中找到，正在为当前会话添加...${RESET}"
    export PATH="$PATH:$HOME/.aztec/bin"
    
    if ! grep -Fxq 'export PATH=$PATH:$HOME/.aztec/bin' "$HOME/.zshrc"; then
        echo 'export PATH=$PATH:$HOME/.aztec/bin' >> "$HOME/.zshrc"
        echo -e "${GREEN}${BOLD}已在.zshrc中添加Aztec到PATH${RESET}"
    fi
    
    if ! grep -Fxq 'export PATH=$PATH:$HOME/.aztec/bin' "$HOME/.bash_profile"; then
        echo 'export PATH=$PATH:$HOME/.aztec/bin' >> "$HOME/.bash_profile"
        echo -e "${GREEN}${BOLD}已在.bash_profile中添加Aztec到PATH${RESET}"
    fi
fi

if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
elif [ -f "$HOME/.bash_profile" ]; then
    source "$HOME/.bash_profile"
fi

export PATH="$PATH:$HOME/.aztec/bin"

if ! command -v aztec &> /dev/null; then
  echo -e "${RED}${BOLD}错误：Aztec安装失败，请检查上述日志。${RESET}"
  exit 1
fi

echo -e "\n${CYAN}${BOLD}---- 更新Aztec到alpha-testnet ----${RESET}\n"
aztec-up alpha-testnet

echo -e "\n${CYAN}${BOLD}---- 配置节点 ----${RESET}\n"
IP=$(curl -s https://api.ipify.org)
if [ -z "$IP" ]; then
    IP=$(curl -s http://checkip.amazonaws.com)
fi
if [ -z "$IP" ]; then
    IP=$(curl -s https://ifconfig.me)
fi
if [ -z "$IP" ]; then
    echo -e "${LIGHTBLUE}${BOLD}无法自动确定IP地址。${RESET}"
    read -p "请输入您的VPS/macOS IP地址: " IP
fi

echo -e "${LIGHTBLUE}${BOLD}请访问 ${PURPLE}https://dashboard.alchemy.com/apps${RESET}${LIGHTBLUE}${BOLD} 或 ${PURPLE}https://developer.metamask.io/register${RESET}${LIGHTBLUE}${BOLD} 创建账户并获取Sepolia RPC URL。${RESET}"
read -p "请输入您的Sepolia以太坊RPC URL: " L1_RPC_URL

echo -e "\n${LIGHTBLUE}${BOLD}请访问 ${PURPLE}https://chainstack.com/global-nodes${RESET}${LIGHTBLUE}${BOLD} 创建账户并获取beacon RPC URL。${RESET}"
read -p "请输入您的Sepolia以太坊BEACON URL: " L1_CONSENSUS_URL

echo -e "\n${LIGHTBLUE}${BOLD}请创建一个新的EVM钱包，使用Sepolia水龙头为其充值，然后提供私钥。${RESET}"
read -p "请输入您的新EVM钱包私钥（带0x前缀）: " VALIDATOR_PRIVATE_KEY
read -p "请输入与您刚才提供的私钥关联的钱包地址: " COINBASE_ADDRESS

echo -e "\n${CYAN}${BOLD}---- 检查端口可用性 ----${RESET}\n"
if lsof -i :8080 > /dev/null 2>&1; then
    echo -e "${LIGHTBLUE}${BOLD}端口8080正在使用中，正在尝试释放...${RESET}"
    lsof -ti:8080 | xargs kill -9
    sleep 2
    echo -e "${GREEN}${BOLD}端口8080已成功释放。${RESET}"
else
    echo -e "${GREEN}${BOLD}端口8080已经空闲可用。${RESET}"
fi

echo -e "\n${CYAN}${BOLD}---- 启动Aztec节点 ----${RESET}\n"
cat > $HOME/start_aztec_node.sh << EOL
#!/bin/bash
export PATH=\$PATH:\$HOME/.aztec/bin
aztec start --node --archiver --sequencer \\
  --network alpha-testnet \\
  --port 8080 \\
  --l1-rpc-urls $L1_RPC_URL \\
  --l1-consensus-host-urls $L1_CONSENSUS_URL \\
  --sequencer.validatorPrivateKey $VALIDATOR_PRIVATE_KEY \\
  --sequencer.coinbase $COINBASE_ADDRESS \\
  --p2p.p2pIp $IP \\
  --p2p.maxTxPoolSize 1000000000
EOL

chmod +x $HOME/start_aztec_node.sh
screen -dmS aztec $HOME/start_aztec_node.sh

echo -e "${GREEN}${BOLD}Aztec节点已在screen会话中成功启动。${RESET}\n"
echo -e "${LIGHTBLUE}${BOLD}使用 'screen -r aztec' 命令查看节点运行状态${RESET}"
echo -e "${LIGHTBLUE}${BOLD}使用 'screen -d aztec' 命令分离screen会话${RESET}"
echo -e "${LIGHTBLUE}${BOLD}注意：macOS上可能需要先安装screen: brew install screen${RESET}" 