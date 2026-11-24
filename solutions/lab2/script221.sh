#!/usr/bin/env bash

if [[ $# -ne 2 ]]; then
  echo "Скрипт принимает ровно два аргумента"
  exit
fi

if [[ $1 == $2 ]]; then
  echo "Строки равны"
else
  echo "Строки не равны"
fi
