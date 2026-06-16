#!/bin/bash
cpu=$(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.0f", 100 - $8}')
ram=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
dsk=$(df -h / --output=avail | tail -1 | tr -d ' ')
echo " ${cpu}%  ${ram}  ${dsk}"
