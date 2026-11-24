# Подготовка

mkdir -p PASSPORT/{log,tmp}

TMP_DIR=PASSPORT/tmp

# Сбор данных

date > $TMP_DIR/date.tmp
hostname > $TMP_DIR/hostname.tmp
whoami > $TMP_DIR/whoami.tmp
pwd > $TMP_DIR/pwd.tmp
ls > $TMP_DIR/ls.tmp

# Обработка данных и формирование отчета

OUT_FILE=$TMP_DIR/out.tmp
echo -e \\n=== Дата запуска === > $OUT_FILE # -e включает escape последовательности
cat $TMP_DIR/date.tmp >> $OUT_FILE
echo -e \\n=== Информация о системе === >> $OUT_FILE
echo -n 'Имя хоста: ' >> $OUT_FILE
cat $TMP_DIR/hostname.tmp >> $OUT_FILE
echo -n 'Текущий пользователь: ' >> $OUT_FILE
cat $TMP_DIR/whoami.tmp >> $OUT_FILE
echo -e \\n=== Информация о директории === >> $OUT_FILE
echo -n 'Текущая директория: ' >> $OUT_FILE
cat $TMP_DIR/pwd.tmp >> $OUT_FILE
echo -e 'Содержимое текущей директории:' >> $OUT_FILE
cat $TMP_DIR/ls.tmp >> $OUT_FILE

# Вывод отчета

cat $OUT_FILE > PASSPORT/passport.txt

# Запись лога о выполнении

echo "Скрипт был запущен в: $(cat $TMP_DIR/date.tmp)" >> PASSPORT/log/report.log

# Удаление временных файлов

find PASSPORT -name *.tmp -exec rm {} +
