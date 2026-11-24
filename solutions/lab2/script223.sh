#!/usr/bin/env bash

s=""
while read s && [[ $s != "q" ]]; do
  res="$res $s"
done

echo $res
