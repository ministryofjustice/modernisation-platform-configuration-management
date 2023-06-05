#!/bin/bash

while true
do
    service weblogic-all healthcheck
    sleep 120
done