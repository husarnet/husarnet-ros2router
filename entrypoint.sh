#!/bin/bash

if [ -z "$USER" ]; then
    export USER=root
elif ! id "$USER" &>/dev/null; then
    useradd -ms /bin/bash "$USER"
fi

if [[ $AUTO_CONFIG == "TRUE" ]]; then
    gosu $USER bash -c "/run_auto_config.sh"
fi

# setup dds router environment
source "/dds_router/install/setup.bash"

if [ $# -eq 0 ]; then
    exec gosu $USER /bin/bash
else
    exec gosu $USER "$@"
fi
