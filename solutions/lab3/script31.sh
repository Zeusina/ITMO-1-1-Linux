#/bin/env bash

if [ $EUID -ne 0 ]; then
    echo "Скрипт должен быть запущен от root"
    exit 1
fi

if [ $# -ne 2 ]; then
    echo "Должно быть ровно 2 аргумента: количество пользователей и стартовый номер."
    exit 1
fi

if ! [[ $2 =~ ^[0-9]+$ ]]; then # регулярное выражение проверяет что переменная содержит только не менее одной цифры
    echo "Стартовое число должно быть неотрицательным"
    exit 1
fi

if ! [[ $2 =~ ^[0-9]+$ ]]; then
    echo "Количество пользователей должно быть неотрицательным"
    exit 1
fi


for i in $(seq $2 $(($2 + $1 - 1))); do
    username="u$i"
    if ! getent passwd $username &>/dev/null; then
        useradd -m -s /bin/bash $username
        echo "$username:DerParol$i" | chpasswd
    fi
done
