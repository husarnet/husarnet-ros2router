#!/bin/bash

ip addr show docker0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1

