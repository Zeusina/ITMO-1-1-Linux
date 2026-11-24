#!/usr/bin/env bash

if [[ $# -ne 3 ]]; then
  echo "Скрипт принимает ровно три числа-аргумента"
  exit
fi

if [[ $1 -ge $2 && $1 -ge $3 ]]; then
  echo $1
  exit
fi

if [[ $2 -ge $1 && $2 -ge $3 ]]; then
  echo $2
  exit
fi

if [[ $3 -ge $2 && $3 -ge $1 ]]; then
  echo $3
  exit
fi

