#!/bin/bash
# Get Data Guard Apply Lag for Database

dgmgrl <<EDGMR | grep "Apply Lag:" | awk '{print $3}'
connect /
show database ${DATABASE};
EDGMR
