#!/bin/bash

# check process PID with "ps aux | grep config_daemon.sh"
# kill the process with "pkill -f config_daemon.sh"

generate_topiclist_description() {
    local topiclist="$1"
    IFS=$'\n;'  # Set Internal Field Separator to newline and semicolon

    # Convert spaces to newlines (Only if you expect some entries to be separated by spaces)
    topiclist=$(echo "$topiclist" | tr ' ' '\n')

    for entry in $topiclist; do
        # Check if entry is empty or just whitespace, and skip if so
        if [[ ! $entry =~ [^[:space:]] ]]; then
            continue
        fi

        topic_name=$(echo "$entry" | cut -d':' -f1)
        msgs_type=$(echo "$entry" | cut -d':' -f2 | cut -d'/' -f1)
        msg=$(echo "$entry" | cut -d':' -f2 | cut -d'/' -f3-)

        echo "- name: \"rt${topic_name}\""
        echo "  type: \"${msgs_type}::msg::dds_::${msg}_\""
    done

    unset IFS  # Reset the IFS to its default value
}
 
# ALLOWLIST="/cmd_vel:geometry_msgs/msg/Twist /ros_out:rcl_interfaces/msg/Log"
# generate_topiclist_description "$ALLOWLIST"
# generate_topiclist_description "$ALLOWLIST"
LIST=$(echo -e "allowlist:\n$(generate_topiclist_description "$ALLOWLIST")")

echo "$LIST"