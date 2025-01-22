#!/bin/bash
features1=$(grep ^features= "$1" | cut -d= -f2 | tr , '\n' | sort -u)
features2=$(grep ^features= "$2" | cut -d= -f2 | tr , '\n' | sort -u)
shift 2
diff $@ <(echo "$features1") <(echo "$features2")
