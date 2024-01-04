#!/bin/bash

# # Path to your YAML file
# yaml_file="/filter.yaml"

# # Function to expand environment variables in the YAML content
# expand_envs_in_yaml() {
#     local file=$1
#     cp /filter.yaml /var/tmp/filter.yaml
#     yq -i '(.allowlist[] | select(.name)).name |= sub("{{env \"ROS_NAMESPACE\"}}"; env(ROS_NAMESPACE))' /var/tmp/filter.yaml

#     # Use sed to replace '//' with '/'
#     sed -i 's#//#/#g' /var/tmp/filter.yaml
# }
# # Call the function and output to terminal
# expand_envs_in_yaml "$yaml_file"

CFG_PATH="filter.tmp.yaml"
RANDOM_ENV="abcd"  # Define your environment variable

# Function to replace {{env "VARIABLE"}} with its value
envsubst_custom() {
    local content=$(<"$1")
    echo "$content" | while IFS= read -r line; do
        if [[ $line =~ \{\{env\ [\"]*([^\"]+)[\"]*\}\} ]]; then
            var="${BASH_REMATCH[1]}"
            value=$(eval echo "\$$var")
            line=$(echo "$line" | sed "s/{{env [\"]*$var[\"]*}}/$value/g")
        fi
        echo "$line"
    done
}

# envsubst_custom > "${CFG_PATH}.tmp" && mv "${CFG_PATH}.tmp" "$CFG_PATH"
envsubst_custom