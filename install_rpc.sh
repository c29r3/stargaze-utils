#!/bin/bash

CONF=$(curl -s https://raw.githubusercontent.com/c29r3/stargaze-utils/main/stargaze.json)
BINARY_LINK=$(jq -r .binary_link <<< $CONF)
BIN_NAME=$(jq -r .binary_name <<< $CONF)
CHAIN_ID=$(jq -r .chain-id <<< $CONF)
COIN=$(jq -r .coin <<< $CONF)
GENESIS=$(jq -r .genesis <<< $CONF)
SEEDS=$(jq -r .seeds <<< $CONF)
PEERS=$(jq -r .persistent_peers <<< $CONF)
RPC_SERVERS=$(jq -r .rpc_servers <<< $CONF)
PORT_OFFSET=1

# install binary
wget -qO- $BINARY_LINK | tar -C /usr/local/bin/ -xzf-

# check binary version
$BIN_NAME version

# install service file
echo '[Unit]
Description=Stargaze Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which $BIN_NAME) start
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/$BIN_NAME.service

sudo systemctl daemon-reload
sudo systemctl enable $BIN_NAME

# init configs
$BIN_NAME config chain-id $CHAIN_ID
$BIN_NAME init c29r3_RPC --chain-id $CHAIN_ID

# download genesis file
wget -qO- $GENESIS | tar -C ~/.starsd/config/ -xzf-

# changing values in config files
CONF_PATH=$(echo -e "$HOME/.$BIN_NAME/config/config.toml")
APP_CONF_PATH=$(echo -e "$HOME/.$BIN_NAME/config/app.toml")
sed -i 's|prof_laddr = "localhost:6060"|prof_laddr = "localhost:60'"$PORT_OFFSET"'0"|g' $CONF_PATH

sed -i 's|laddr = "tcp://0.0.0.0:26656"|laddr = "tcp://0.0.0.0:2'"$PORT_OFFSET"'656"|g' $CONF_PATH

sed -i 's|proxy_app = "tcp://127.0.0.1:26658"|proxy_app = "tcp://127.0.0.1:2'"$PORT_OFFSET"'658"|g' $CONF_PATH

sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://127.0.0.1:2'"$PORT_OFFSET"'657"|g' $CONF_PATH

sed -i "s|persistent_peers = \"\"|persistent_peers = \"$PEERS\"|g" $CONF_PATH

sed -i "s|seeds = \"\"|seeds = \"$SEEDS\"|g" $CONF_PATH

sed -i "s|address = \"0.0.0.0:9091\"|address = \"0.0.0.0:9"$PORT_OFFSET"91\"|g" $APP_CONF_PATH

sed -i "s|address = \"tcp://0.0.0.0:1317\"|address = \"tcp://0.0.0.0:1"$PORT_OFFSET"17\"|g" $APP_CONF_PATH

sed -i "s|address = \":8080\"|address = \":8"$PORT_OFFSET"80\"|g" $APP_CONF_PATH

sed -i "s|enable = "'false'"|enable = "'true'"|g" $APP_CONF_PATH

sed -i "s|snapshot-interval = 0|snapshot-interval = 500|g" $APP_CONF_PATH

# configure statesync if rpc_list is not empty
if [ $RPC_SERVERS != "" ]; then
	statesync_data=$(curl -s echo "$(echo $RPC_SERVERS | cut -d ',' -f 1)/commit" | jq "{height: .result.signed_header.header.height, hash: .result.signed_header.commit.block_id.hash}")
	height=$(jq -r .height <<< $statesync_data)
	hash=$(jq -r .hash <<< $statesync_data)

	sed -i "s|enable = "'false'"|enable = "'true'"|g" $CONF_PATH
	sed -i "s|rpc_servers = \"\"|rpc_servers = \"$RPC_SERVERS\"|g" $CONF_PATH
	sed -i "s|trust_height = 0|trust_height = $height|g" $CONF_PATH
	sed -i "s|trust_hash = \"\"|trust_hash = \"$hash\"|g" $CONF_PATH

fi

sudo systemctl start $BIN_NAME
sudo systemctl status $BIN_NAME
