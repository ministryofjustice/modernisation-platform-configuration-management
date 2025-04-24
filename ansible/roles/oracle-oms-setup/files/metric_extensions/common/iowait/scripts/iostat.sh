#!/bin/bash

# Get average IO Wait Percent over last 10 seconds rather than instantaneous time - ignore short lived spikes

iostat -c 10 2 | awk '/^avg-cpu:/ {getline; print $4}' | tail -1
