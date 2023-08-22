#!/bin/bash

. ~/.bash_profile
echo "show all;" | rman target / | grep "RETENTION POLICY"
