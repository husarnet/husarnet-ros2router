#!/bin/bash

# Path to your YAML file
yaml_file="/filter.yaml"

# Function to expand environment variables in the YAML content
expand_envs_in_yaml() {
    local file=$1
    cp /filter.yaml /var/tmp/filter.yaml
    yq -i '(.allowlist[] | select(.name)).name |= sub("{{env \"ROS_NAMESPACE\"}}"; env(ROS_NAMESPACE))' /var/tmp/filter.yaml
    
    # Use sed to replace '//' with '/'
    sed -i 's#//#/#g' /var/tmp/filter.yaml
}
# Call the function and output to terminal
expand_envs_in_yaml "$yaml_file"
