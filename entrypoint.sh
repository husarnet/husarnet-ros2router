#!/bin/bash

if [ -z "$USER" ]; then
    export USER=root
elif ! id "$USER" &>/dev/null; then
    useradd -ms /bin/bash "$USER"
fi

if [[ -n $PARTICIPANTS ]]; then
    gosu $USER bash -c "/run_auto_config.sh"
else
    echo "Skipping auto configuration."
fi

# setup dds router environment
source "/dds_router/install/setup.bash"

if [ $# -eq 0 ]; then
    exec gosu $USER /bin/bash
else
    exec gosu $USER "$@"
fi
