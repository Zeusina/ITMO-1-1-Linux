#!/usr/bin/env bash

calculate () {
  pi=3.1415926535
  echo "$pi * $pi" | bc > /dev/null
}

start_time=$(date +%s%N)
for i in $(seq 1 100); do
  calculate
done
end_time=$(date +%s%N)

echo "scale=3; 1000000000/(($end_time - $start_time)/100)" | bc

