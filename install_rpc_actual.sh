#!/bin/bash

BINARY_VERSION="v6.0.0"
REP_URL="https://github.com/public-awesome/stargaze.git"
BIN_NAME="starsd"
BIN_PATH="/usr/local/bin/${BIN_NAME}"
CHAIN_ID="stargaze-1"
SERVICE_FILE="https://raw.githubusercontent.com/c29r3/stargaze-utils/main/stargaze.service"
CONFIG_TOML="https://raw.githubusercontent.com/c29r3/stargaze-utils/main/config.toml"
APP_TOML="https://raw.githubusercontent.com/c29r3/stargaze-utils/main/app.toml"
GENESIS_URL="https://raw.githubusercontent.com/public-awesome/mainnet/main/stargaze-1/genesis.tar.gz"

# install requirements
sudo apt-get update
sudo apt-get install -y jq curl wget htop pv bc git

echo install go
curl -s https://gist.githubusercontent.com/c29r3/3130b5cd51c4a94f897cc58443890c28/raw/134d86f8a90b2bbb7c68cd6bb663c60c5846ae31/install_golang.sh | bash -s - 1.18

echo "removing old data"
rm -rf ${HOME}/.${BIN_NAME}
rm ${HOME}/go/bin/${BIN_NAME} ${BIN_PATH}

echo "stop service"
sudo systemctl stop ${BIN_NAME}.service

echo install binary
cd /tmp
rm -rf stargaze
git clone ${REP_URL}
cd stargaze
git checkout main
git pull
git checkout ${BINARY_VERSION}

cd stargaze
make build
make install
cp ${HOME}/go/bin/${BIN_NAME} ${BIN_PATH}

$BIN_PATH version

echo "init node"
$BIN_PATH init c29r3 --chain-id $CHAIN_ID

echo "download configs"
rm $HOME/.$BIN_NAME/config/genesis.json
echo download genesis file
wget -qO- ${GENESIS_URL} | tar -C ~/.$BIN_NAME/config/ -xzf-

curl -s $CONFIG_TOML > $HOME/.${BIN_NAME}/config/config.toml
curl -s $APP_TOML > $HOME/.${BIN_NAME}/config/app.toml

echo "install service unit"
curl -s $SERVICE_FILE > /etc/systemd/system/${BIN_NAME}.service
sudo systemctl daemon-reload
sudo systemctl enable ${BIN_NAME}.service

echo "download wasm"
rm -rf ~/.${BIN_NAME}/wasm
mkdir -p ~/.${BIN_NAME}/wasm
cd ~/.${BIN_NAME}/wasm
wget -O - http://135.181.60.250:8086/stargaze/stargaze_wasm.tar | tar xf -


echo "download snapshot"
rm -rf ~/.${BIN_NAME}/data
mkdir -p ~/.${BIN_NAME}/data
cd ~/.${BIN_NAME}/data

SNAP_NAME=$(curl -s https://snapshots.c29r3.xyz/stargaze/ | egrep -o ">stargaze.*tar" | tr -d ">"); \
wget -O - https://snapshots.c29r3.xyz/stargaze/${SNAP_NAME} | tar xf -



#echo "ufw rules"
#sudo ufw allow 28957,28959,28956,1518,9890/tcp comment "allow akash public nodes"

echo "start service"
sudo systemctl start ${BIN_NAME}.service
