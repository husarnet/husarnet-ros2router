#!/bin/bash

source .env
husarnet dashboard login $HUSARNET_DASHBOARD_LOGIN $HUSARNET_DASHBOARD_PASSWORD

husarnet dashboard device remove talker
husarnet dashboard device remove listener