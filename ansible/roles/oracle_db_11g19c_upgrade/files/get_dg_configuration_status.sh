#!/bin/bash
# Get Data Guard Configuration Status


dgmgrl <<EDGMR
connect /
show configuration;
EDGMR
