#!/usr/bin/env bash

if ! which nano > /dev/null ; then
  echo "Nano не установлен, выхожу из скрипта"
  exit
fi

if ! which vi > /dev/null ; then
  echo "Vi не установлен, выхожу из скрипта"
  exit
fi

if ! which links > /dev/null ; then
  echo "Links не установлен, выхожу из скрипта"
  exit
fi

cat <<-"EOF"
	Выберите номер необходимого вам пункта
	1. Запустить редактор nano
	2. Запустить редактор vi
	3. Запустить браузер links
	4. Выйти из программы
EOF

read a

case $a in
  1)
    exec nano
  ;;
  2)
    exec vi
  ;;
  3)
    exec links
  ;;
  4)
    exit
  ;;
  *)
    echo "Неизвестное значение, выхожу"
  ;;
esac
