#!/bin/bash

echo "Waiting for \"${DS_HOSTNAME}\" host to be available in /etc/hosts"

while [[ $(grep ${DS_HOSTNAME} /etc/hosts | wc -l) -eq 0 ]]; do 
    sleep 1
done

sleep 2

echo "\"${DS_HOSTNAME}\" present in /etc/hosts:"

# print the IPv6 address of the Discovery Server
grep ${DS_HOSTNAME} /etc/hosts

echo "Ready to launch ROS 2 nodes"

