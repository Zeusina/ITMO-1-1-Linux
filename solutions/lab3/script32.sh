#!/bin/bash

while true; do
  ppid=$(awk '/^PPid:/ {print $2}' "/proc/$$/status")

  echo "date: $(date) pid: $$ ppid: $ppid" >> ~/script32.log
  sleep 2
done