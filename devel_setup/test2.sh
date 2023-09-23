#!/bin/bash

yq '. * env(FILTER)' config.discovery-server.template.yaml