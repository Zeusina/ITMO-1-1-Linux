#!/usr/bin/env bash

cnt=0
s=1
while (( s % 2 != 0 )); do
  read s
  ((cnt++))
done

echo $cnt
