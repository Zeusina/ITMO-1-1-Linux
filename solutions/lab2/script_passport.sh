# Проверка программ
not_run=0

check_which() {
if ! which $1 > /dev/null 2>&1 ; then
  echo $1 не установлен
  not_run=1
fi
}

check_which lspci
check_which nproc

# if ! which nproc > /dev/null 2>&1 ; then
#   echo nproc не установлен
#   not_run=1
# fi

if [[ "$not_run" == "1" ]]; then
  echo "Выход"
  exit
fi

# Подготовка

mkdir -p PASSPORT/{log,tmp}

TMP_DIR=PASSPORT/tmp

# Сбор данных

date > $TMP_DIR/date.tmp
hostname > $TMP_DIR/hostname.tmp
whoami > $TMP_DIR/whoami.tmp
pwd > $TMP_DIR/pwd.tmp
ls > $TMP_DIR/ls.tmp
uname -svp > $TMP_DIR/uname.tmp
cp /etc/os-release $TMP_DIR/os-release.tmp
lscpu > $TMP_DIR/cpu_info.tmp
nproc > $TMP_DIR/cpu_logical_cores.tmp
free -h > $TMP_DIR/free.tmp
cat /sys/devices/virtual/dmi/id/board_name > $TMP_DIR/mb_name.tmp # Можно получать и через dmidecode, но я выбрал sysfs
cat /sys/devices/virtual/dmi/id/bios_date > $TMP_DIR/bios_date.tmp # Аналогично получаем данные через sysfs
cat /sys/devices/virtual/dmi/id/bios_version > $TMP_DIR/bios_version.tmp
lspci > $TMP_DIR/lspci.tmp

# Обработка данных

grep_cut_strip() {
 grep "$1" | cut -d : -f2 | xargs
}

cat $TMP_DIR/os-release.tmp | grep "^VERSION=" | cut -d = -f2- | tr -d '"' > $TMP_DIR/os-version.tmp # Достаем из os-release человекочитаемую версию системы

cat $TMP_DIR/cpu_info.tmp | grep_cut_strip "Model name:" > $TMP_DIR/cpu_model.tmp
cat $TMP_DIR/cpu_info.tmp | grep_cut_strip "CPU max MHz:" > $TMP_DIR/cpu-freq-max.tmp
cat $TMP_DIR/cpu_info.tmp | grep_cut_strip "CPU min MHz:" > $TMP_DIR/cpu-freq-min.tmp
cat $TMP_DIR/cpu_info.tmp | grep_cut_strip "L1d cache:" | cut -d " " -f1-2 > $TMP_DIR/cpu_l1d_cache.tmp
cat $TMP_DIR/cpu_info.tmp | grep_cut_strip "L1d cache:" | cut -d " " -f1-2 > $TMP_DIR/cpu_l1i_cache.tmp
cat $TMP_DIR/cpu_info.tmp | grep_cut_strip "L2 cache:"  | cut -d " " -f1-2 > $TMP_DIR/cpu_l2_cache.tmp
cat $TMP_DIR/cpu_info.tmp | grep_cut_strip "L3 cache:"  | cut -d " " -f1-2 > $TMP_DIR/cpu_l3_cache.tmp

cat $TMP_DIR/free.tmp | awk '/Mem:/ {print $2}' > $TMP_DIR/physical_mem.tmp # Через awk получаем из вывода free память, выражение внутри // это селектор, а внутри {} это оператор, в данном случае выбираем строку содержащую "MEM:", awk разбивает ее на поля и мы выводим второе

# Формирование отчета

OUT_FILE=$TMP_DIR/out.tmp

# $(val=$(cat "$TMP_DIR/cpu_l2_cache.tmp"); echo "${val:--}") - данное выражение используется для подстановки -, если значения нет, такое произошло в моей VM VMWare. Система не возвращает частоту и кэши процессора, а также модель процессора 
cat <<EOF > "$OUT_FILE" # Перешел на использование Heredoc для удобства оформления, heredoc это объявление при помощи << произвольного маркера и весь текст до следующего маркера будет передан в команду через stdin

=== Дата запуска ===
$(cat "$TMP_DIR/date.tmp")

=== Информация о системе ===
Имя хоста: $(cat "$TMP_DIR/hostname.tmp")
Текущий пользователь: $(cat "$TMP_DIR/whoami.tmp")
Название и версия ядра: $(cat "$TMP_DIR/uname.tmp")
Версия операционной системы: $(cat "$TMP_DIR/os-version.tmp")

=== Процессор ===
Модель процессора: $(val=$(cat "$TMP_DIR/cpu_model.tmp"); echo "${val:--}")
Максимальная частота процессора, МГц: $(val=$(cat "$TMP_DIR/cpu-freq-max.tmp"); echo "${val:--}")
Минимальная частота процессора, МГц: $(val=$(cat "$TMP_DIR/cpu-freq-min.tmp"); echo "${val:--}")
Количество логических ядер: $(cat $TMP_DIR/cpu_logical_cores.tmp)
Кэш L1i: $(val=$(cat "$TMP_DIR/cpu_l1i_cache.tmp"); echo "${val:--}")
Кэш L1d: $(val=$(cat "$TMP_DIR/cpu_l1d_cache.tmp"); echo "${val:--}")
Кэш L2: $(val=$(cat "$TMP_DIR/cpu_l2_cache.tmp"); echo "${val:--}")
Кэш L3: $(val=$(cat "$TMP_DIR/cpu_l3_cache.tmp"); echo "${val:--}")

=== Память ===
Объем физической памяти: $(cat $TMP_DIR/physical_mem.tmp)

=== Платформа ===
Модель материнской платы: $(cat $TMP_DIR/mb_name.tmp)
Версия BIOS: $(cat $TMP_DIR/bios_version.tmp)
Дата выпуска BIOS: $(cat $TMP_DIR/bios_date.tmp)

=== Устройства подключенные к шине PCI ===

$(cat $TMP_DIR/lspci.tmp)

=== Информация о директории ===
Текущая директория: $(cat "$TMP_DIR/pwd.tmp")
Содержимое текущей директории:
$(cat "$TMP_DIR/ls.tmp")
EOF

# Вывод отчета

cat $OUT_FILE > PASSPORT/inventory.txt

# Запись лога о выполнении

echo "Скрипт был запущен в: $(cat $TMP_DIR/date.tmp)" >> PASSPORT/log/report.log

# Удаление временных файлов

find PASSPORT -name *.tmp -delete
