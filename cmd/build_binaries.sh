#!/bin/bash

check_required_binaries() {
    local version=$1
    local bindir="$ROOTDIR/bin/$version"
    
    local required_bins=("kcn" "kcnd" "homi")
    
    for bin in "${required_bins[@]}"; do
        if [ ! -x "$bindir/$bin" ]; then
            echo "Missing or non-executable binary: $bindir/$bin"
            return 1
        fi
    done
    
    echo "All required binaries found for $version"
    return 0
}

prepare_binaries() {
    local v2_exists=false
    local v1_exists=false
    
    if check_required_binaries "v2.0.0"; then
        v2_exists=true
        echo "v2.0.0 binaries already exist, skipping build"
    fi
    
    if check_required_binaries "v1.0.3"; then
        v1_exists=true
        echo "v1.0.3 binaries already exist, skipping build"
    fi
    
    if $v2_exists && $v1_exists; then
        echo "All required binaries already exist"
        return 0
    fi
    
    WORK_DIR="$ROOTDIR/build_work"
    mkdir -p "$WORK_DIR"
    
    echo "Cloning kaia repository..."
    cd "$WORK_DIR"
    if [ ! -d "kaia" ]; then
        git clone https://github.com/kaiachain/kaia.git
    fi
    cd kaia
    
    if ! $v2_exists; then
        echo "Building v2.0.0-rc.2..."
        git fetch --all --tags
        git checkout v2.0.0-rc.2
        make clean && make all
        
        mkdir -p "$ROOTDIR/bin/v2.0.0"
        cp build/bin/kcn "$ROOTDIR/bin/v2.0.0/"
        cp "$ROOTDIR/kcnd" "$ROOTDIR/bin/v2.0.0/"
        cp build/bin/homi "$ROOTDIR/bin/v2.0.0/"
    fi
    
    if ! $v1_exists; then
        echo "Building v1.0.3..."
        git checkout v1.0.3
        make clean && make all
        
        mkdir -p "$ROOTDIR/bin/v1.0.3"
        cp build/bin/kcn "$ROOTDIR/bin/v1.0.3/"
        cp "$ROOTDIR/kcnd" "$ROOTDIR/bin/v1.0.3/"
        cp build/bin/homi "$ROOTDIR/bin/v1.0.3/"
    fi
    
    echo "Binary preparation completed!"
}

run_homi_setup() {
    echo "Running homi setup for v2.0.0..."
    HOMI_OUTPUT_DIR_V2="$ROOTDIR/homi_output_v2"
    rm -rf "$HOMI_OUTPUT_DIR_V2"
    mkdir -p "$HOMI_OUTPUT_DIR_V2"
    cd "$HOMI_OUTPUT_DIR_V2"
    
    echo "Current directory: $(pwd)"
    echo "Executing: $ROOTDIR/bin/v2.0.0/homi setup --gen-type local --cn-num 2 --network-id 2020 --p2p-port 32323 --output $HOMI_OUTPUT_DIR_V2"
    "$ROOTDIR/bin/v2.0.0/homi" setup --gen-type local --cn-num 2 --network-id 2020 --p2p-port 32323 --output "$HOMI_OUTPUT_DIR_V2"
    
    ls -la "$HOMI_OUTPUT_DIR_V2"
    if [ ! -f "$HOMI_OUTPUT_DIR_V2/scripts/genesis.json" ]; then
        echo "Error: genesis.json not created in v2.0.0 output"
        exit 1
    fi
    
    echo "Running homi setup for v1.0.3..."
    HOMI_OUTPUT_DIR_V1="$ROOTDIR/homi_output_v1"
    rm -rf "$HOMI_OUTPUT_DIR_V1"
    mkdir -p "$HOMI_OUTPUT_DIR_V1"
    cd "$HOMI_OUTPUT_DIR_V1"
    
    echo "Current directory: $(pwd)"
    echo "Executing: $ROOTDIR/bin/v1.0.3/homi setup --gen-type local --cn-num 2 --network-id 2018 --p2p-port 32325 --output $HOMI_OUTPUT_DIR_V1"
    "$ROOTDIR/bin/v1.0.3/homi" setup --gen-type local --cn-num 2 --network-id 2018 --p2p-port 32325 --output "$HOMI_OUTPUT_DIR_V1"
    
    ls -la "$HOMI_OUTPUT_DIR_V1"
    if [ ! -f "$HOMI_OUTPUT_DIR_V1/scripts/genesis.json" ]; then
        echo "Error: genesis.json not created in v1.0.3 output"
        exit 1
    fi

    echo "Modifying static-nodes.json for v2.0.0..."
    sed -i.bak 's/0\.0\.0\.0/127\.0\.0\.1/g' "$HOMI_OUTPUT_DIR_V2/scripts/static-nodes.json"

    echo "Modifying static-nodes.json for v1.0.3..."
    sed -i.bak 's/0\.0\.0\.0/127\.0\.0\.1/g' "$HOMI_OUTPUT_DIR_V1/scripts/static-nodes.json"
    
    echo "HOMIOUTPUT_V2=$HOMI_OUTPUT_DIR_V2" > "$ROOTDIR/env.conf"
    echo "HOMIOUTPUT_V1=$HOMI_OUTPUT_DIR_V1" >> "$ROOTDIR/env.conf"
    
    echo "Contents of $HOMI_OUTPUT_DIR_V2:"
    ls -R "$HOMI_OUTPUT_DIR_V2"
    echo "static-nodes.json for v2.0.0:"
    cat "$HOMI_OUTPUT_DIR_V2/scripts/static-nodes.json"
    echo "Contents of $HOMI_OUTPUT_DIR_V1:"
    ls -R "$HOMI_OUTPUT_DIR_V1"
    echo "static-nodes.json for v1.0.3:"
    cat "$HOMI_OUTPUT_DIR_V1/scripts/static-nodes.json"
}

build_binaries() {
    if [ -z "$ROOTDIR" ]; then
        echo "Error: ROOTDIR environment variable is not set"
        exit 1
    fi

    prepare_binaries
    run_homi_setup

    echo "Setup completed successfully!"
    echo "You can now run './run setup' followed by './run start'"
}
