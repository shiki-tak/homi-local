#!/bin/bash

set -e

if [ ! -f "$ROOTDIR/env.conf" ]; then
    echo "Error: env.conf not found. Please run build_binaries.sh first"
    exit 1
fi
source "$ROOTDIR/env.conf"

if [ -z "$HOMIOUTPUT_V2" ] || [ ! -d "$HOMIOUTPUT_V2" ] || [ -z "$HOMIOUTPUT_V1" ] || [ ! -d "$HOMIOUTPUT_V1" ]; then
    echo "Error: HOMIOUTPUT_V2 or HOMIOUTPUT_V1 is not properly set. Please run build_binaries.sh first"
    exit 1
fi

do_setup() {
    local idx=$1
    local version=$2
    local cn_dir=$3
    
    echo "Setting up node $idx with version $version in directory $cn_dir"
    
    mkdir -p "$cn_dir"
    cd "$cn_dir"
    mkdir -p conf bin
    mkdir -p data/log
    DATA_DIR="$PWD/data"
    
    if [ "$version" = "v2.0.0" ]; then
        HOMI_DIR="$HOMIOUTPUT_V2"
        NETWORK_ID="2020"
        NODE_IDX=$((idx))
        BASE_PORT=32323
        BASE_RPC_PORT=8551
    else
        HOMI_DIR="$HOMIOUTPUT_V1"
        NETWORK_ID="2018"
        NODE_IDX=$((idx-2))
        BASE_PORT=32325
        BASE_RPC_PORT=8553
    fi
    
    echo "Using genesis from: $HOMI_DIR/scripts/genesis.json"
    
    mkdir -p "$DATA_DIR"
    cp -f "$HOMI_DIR/scripts/genesis.json" "$DATA_DIR/"
    cp -f "$HOMI_DIR/scripts/static-nodes.json" "$DATA_DIR/"
    
    if [ "$version" = "v2.0.0" ]; then
        cp -f "$ROOTDIR/bin/v2.0.0/kcn" bin/
        cp -f "$ROOTDIR/bin/v2.0.0/kcnd" bin/
    else
        cp -f "$ROOTDIR/bin/v1.0.3/kcn" bin/
        cp -f "$ROOTDIR/bin/v1.0.3/kcnd" bin/
    fi
    chmod +x bin/kcn bin/kcnd
    
    NODEKEY="$HOMI_DIR/keys/nodekey$NODE_IDX"
    
    echo "Using nodekey: $NODEKEY"
    
    if [ ! -f "$NODEKEY" ]; then
        echo "Error: Required key file not found"
        echo "NodeKey: $NODEKEY"
        exit 1
    fi
    
    bin/kcn --datadir "$DATA_DIR" init "$DATA_DIR/genesis.json"
    
    cat > conf/kcnd.conf << EOF
NETWORK=
DATA_DIR=$DATA_DIR
LOG_DIR=$DATA_DIR/log
RPC_ENABLE=1
NETWORK_ID=$NETWORK_ID
NO_DISCOVER=1
EOF
    
    local p2p_port=$((BASE_PORT + NODE_IDX - 1))
    local rpc_port=$((BASE_RPC_PORT + NODE_IDX - 1))
    
    ADDITIONAL=""
    ADDITIONAL="$ADDITIONAL --identity CN-$idx"
    ADDITIONAL="$ADDITIONAL --nodekey $NODEKEY"
    ADDITIONAL="$ADDITIONAL --port $p2p_port"
    ADDITIONAL="$ADDITIONAL --rpc"
    ADDITIONAL="$ADDITIONAL --rpcapi admin,debug,klay,eth,net,personal,rpc,txpool,web3,governance"
    ADDITIONAL="$ADDITIONAL --rpcaddr 0.0.0.0"
    ADDITIONAL="$ADDITIONAL --rpcport $rpc_port"
    ADDITIONAL="$ADDITIONAL --rpcvhosts '*'"
    ADDITIONAL="$ADDITIONAL --prometheus"
    ADDITIONAL="$ADDITIONAL --prometheusport $((61001+idx-1))"
    ADDITIONAL="$ADDITIONAL --ntp.disable"
    
    echo "ADDITIONAL='$ADDITIONAL'" >> conf/kcnd.conf
    
    echo "Setup completed for node $idx with p2p port $p2p_port and rpc port $rpc_port"
}

setup() {
    total_nodes=4
    v2_nodes=2
    
    OUTPUT_DIR="$ROOTDIR/output"
    mkdir -p "$OUTPUT_DIR"
    
    ORIGINAL_DIR="$PWD"
    
    echo "Setting up v2.0.0 nodes..."
    for i in $(seq 1 $v2_nodes); do
        do_setup $i "v2.0.0" "$OUTPUT_DIR/cn$i"
    done
    
    echo "Setting up v1.0.3 nodes..."
    for i in $(seq $((v2_nodes+1)) $total_nodes); do
        do_setup $i "v1.0.3" "$OUTPUT_DIR/cn$i"
    done
    
    cd "$ORIGINAL_DIR"
    
    echo "Setup completed successfully for all nodes"
}
