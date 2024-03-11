#!/bin/bash

# Get average IO Wait Percent over last 10 seconds rather than instantaneous time - ignore short lived spikes

iostat -c 10 2 | tail -2 | head -1 | awk '{print $4}'