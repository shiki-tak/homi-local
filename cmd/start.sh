#!/bin/bash

start() {
    total_nodes=4
    
    ORIGINAL_DIR="$PWD"
    
    for i in $(seq 1 $total_nodes); do
        node_dir="$ROOTDIR/output/cn$i"
        if [ ! -d "$node_dir" ]; then
            echo "Error: Node directory $node_dir does not exist"
            cd "$ORIGINAL_DIR"
            return 1
        fi
        
        cd "$node_dir"
        echo "Starting node $i..."
        bin/kcnd start
    done
    
    cd "$ORIGINAL_DIR"
}
