#!/bin/bash
host=$(hostname -s | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) printf substr($i,1,1); print ""}')
echo "@${host}"
