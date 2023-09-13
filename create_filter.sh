#!/bin/bash

# Exit if no arguments are provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <topic_name1> <topic_name2> ... <topic_nameN>"
    exit 1
fi

echo "allowlist:"

# Loop over each topic provided as argument
for TOPIC in "$@"; do
    # Fetch details using 'ros2 topic info'
    INFO=$(ros2 topic info $TOPIC)

    # Extract type of the message
    TYPE=$(echo "$INFO" | grep "Type:" | awk '{print $2}')

    # Convert ROS2 message type to DDS type dynamically
    PACKAGE_NAME=$(echo $TYPE | cut -d'/' -f1)
    MSG_NAME=$(echo $TYPE | cut -d'/' -f3)

    # Construct DDS_TYPE using the parsed package and message names
    DDS_TYPE="${PACKAGE_NAME}::msg::dds_::${MSG_NAME}_"

    # Check if conversion is successful
    if [ -z "$DDS_TYPE" ]; then
        echo "Error during type conversion for topic $TOPIC."
        continue
    fi

    # Print entry for current topic
    echo "  - name: \"rt$TOPIC\""
    echo "    type: \"$DDS_TYPE\""
done

echo "blocklist: []"
echo "builtin-topics: []"