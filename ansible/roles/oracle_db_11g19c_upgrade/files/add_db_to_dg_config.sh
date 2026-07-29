#!/bin/bash
# Add Database to Dataguard Broker Configuration

DATABASE=$1

dgmgrl <<EDGMRL
connect /
add database ${DATABASE} as connect identifier is ${DATABASE} maintained as physical;
enable database ${DATABASE};
enable configuration;
EDGMRL