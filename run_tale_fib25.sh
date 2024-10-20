#!/bin/bash

ROOT_DIR="/mnt/fast/sophisid"
PROJECT_DIR="/mnt/fast/sophisid/cs562_sdpg"
DATASETS_DIR="$PROJECT_DIR/noisy_datasets/FIB25"
SCRIPT_DIR="$PROJECT_DIR/scripts"
SCHEMA_DISCOVERY_DIR="$PROJECT_DIR/schemadiscovery"
NEO4J_TAR="neo4j-community.tar.gz"
NEO4J_VERSION="neo4j-community-4.4.0"
NEO4J_DIR="$NEO4J_VERSION"
OUTPUT_BASE_DIR="$PROJECT_DIR/output"
NEO4J_PORT=7687  # Specify the Neo4j port to kill the process dynamically

mkdir -p "$OUTPUT_BASE_DIR"

datasets=($(ls "$DATASETS_DIR" | grep "corrupted"))

# Loop through each dataset
for dataset in "${datasets[@]}"
do
    echo "==============================="
    echo "Processing Dataset: $dataset"
    echo "==============================="

    # Current dataset directory
    current_dataset_dir="$DATASETS_DIR/$dataset"

    # Step 1: Remove the current Neo4j database directory
    echo "Removing $NEO4J_VERSION directory..."
    rm -rf "$NEO4J_DIR"

    # Step 2: Extract Neo4j from the tar.gz
    echo "Extracting Neo4j from $NEO4J_TAR..."
    tar -xzvf "$NEO4J_TAR" 
 
    # Step 3: Import the CSV files into Neo4j with explicit node labels and relationship types
    echo "Importing data into Neo4j from $current_dataset_dir..."
    "$NEO4J_DIR/bin/neo4j-admin" import --database=neo4j --delimiter=',' \
        --nodes=Meta="$current_dataset_dir/Neuprint_Meta_fib25_corrupted.csv" \
        --nodes=Neuron="$current_dataset_dir/Neuprint_Neurons_fib25_corrupted.csv" \
        --relationships=CONNECTS_TO="$current_dataset_dir/Neuprint_Neuron_Connections_fib25_corrupted.csv" \
        --nodes=SynapseSet="$current_dataset_dir/Neuprint_SynapseSet_fib25_corrupted.csv" \
        --relationships=CONNECTS_TO="$current_dataset_dir/Neuprint_SynapseSet_to_SynapseSet_fib25_corrupted.csv" \
        --relationships=CONTAINS="$current_dataset_dir/Neuprint_Neuron_to_SynapseSet_fib25_corrupted.csv" \
        --nodes=Synapse="$current_dataset_dir/Neuprint_Synapses_fib25_corrupted.csv" \
        --relationships=SYNAPSES_TO="$current_dataset_dir/Neuprint_Synapse_Connections_fib25_corrupted.csv" \
        --relationships=CONTAINS="$current_dataset_dir/Neuprint_SynapseSet_to_Synapses_fib25_corrupted.csv"

    # Step 4: Start Neo4j
    echo "Starting Neo4j..."
    "$NEO4J_DIR/bin/neo4j" start

    # Wait for Neo4j to start
    echo "Waiting for Neo4j to start..."
    sleep 100  # Adjust the time if necessary

    # Step 5: Run your Scala program
    echo "Running your Scala program..."
    cd "$SCHEMA_DISCOVERY_DIR" || { echo "Couldn't change directory to $SCHEMA_DISCOVERY_DIR"; exit 1; }
    sbt run > "$OUTPUT_BASE_DIR/output_FIB25_${dataset#corrupted}.txt"
    cd "$ROOT_DIR" || { echo "Couldn't change back to $ROOT_DIR"; exit 1; }

    # Step 6: Stop Neo4j
    echo "Stopping Neo4j..."
    "$NEO4J_DIR/bin/neo4j" stop
    sleep 60  # Wait 60 seconds to ensure Neo4j has stopped

    # Step 7: Dynamically kill any process on port 7687
    echo "Checking and killing any process on port $NEO4J_PORT..."
    PID=$(lsof -t -i :$NEO4J_PORT)

    if [ -z "$PID" ]; then
        echo "No process found on port $NEO4J_PORT."
    else
        echo "Killing process with PID: $PID"
        kill -9 $PID
        if [ $? -eq 0 ]; then
            echo "Process $PID successfully killed."
        else
            echo "Failed to kill process $PID."
        fi
    fi

    echo "Finished processing dataset: $dataset"
    echo ""
done

echo "All datasets have been processed."