#!/bin/bash

# Настройки
FORMAT_VERSION=v3
OUT_FILE="PASSPORT/inventory.txt"
TMP_DIR="PASSPORT/tmp"
LOG_FILE="PASSPORT/log/report.log"
NEED_SUDO=0

# Справка
usage() {
    echo "Использование: $0 [-h] [путь_к_отчету]"
    echo "По умолчанию отчет сохраняется в PASSPORT/inventory.txt"
}

die() {
    echo "Ошибка: $1" >&2
    exit 1
}

# Проверка прав
check_privileges() {
    if [[ "$EUID" == "0" ]]; then
        NEED_SUDO=0
        return
    fi

    check_tool sudo sudo

    sudo -v || die "Не удалось получить права sudo"

    if ! sudo -n id -u 2> /dev/null | grep -qx "0"; then
        die "Нет прав для выполнения команд от root"
    fi

    NEED_SUDO=1
}

# Запуск команды с правами root при необходимости
as_root() {
    if [[ "$NEED_SUDO" == "1" ]]; then
        sudo -n -- "$@" # -- Завершает поиск аргументов sudo чтобы например команды начинающиеся с - работали
    else
        "$@"
    fi
}

# Проверка программ
check_tool() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo "$1 не установлен. Установите пакет $2" >&2
        exit 1
    fi
}

# Запись раздела в отчет
write_section() {
    echo >> "$OUT_FILE"
    echo "=== $1 ===" >> "$OUT_FILE"
    cat >> "$OUT_FILE"
}

# Запись лога
log_run() {
    echo "Скрипт был запущен в: $(cat "$TMP_DIR/date.tmp") | Версия отчета: $FORMAT_VERSION | Отчет: $OUT_FILE" >> "$LOG_FILE"
}

# Удаление временных файлов
cleanup() {
    find "$TMP_DIR" -type f -name '*.tmp' -delete 2>/dev/null
}

# Функция выделения значения из lscpu
grep_cut_strip() {
    grep -F "$1" | head -n 1 | cut -d : -f2- | xargs
}

# Получение времени последнего входа
last_login() {
    local value

    if command -v lslogins > /dev/null 2>&1; then
        value=$(as_root env LC_ALL=C lslogins -o LAST-LOGIN -l "$1" 2>/dev/null | tail -n 1)
        if [[ -n "${value// /}" ]]; then
            echo "$value"
            return
        fi
    fi

    echo "Нет данных"
}

# Список пользователей
users_section() {
    local user uid groups changed login

    getent passwd | while IFS=: read -r user _ uid _; do # Меняем разделитель полей bash через IFS и разбираем строку через read
        [[ "$uid" =~ ^[0-9]+$ ]] || continue
        if [[ "$uid" -lt 1000 && "$uid" -ne 0 ]]; then
            continue
        fi

        groups=$(id -nG "$user" 2>/dev/null)
        changed=$(as_root chage -l "$user" 2>/dev/null | head -n 1 | cut -d : -f2- | xargs)
        login=$(last_login "$user")

        echo "Пользователь: $user"
        echo "UID: $uid"
        echo "Группы: ${groups:-Нет данных}"
        echo "Последний вход: $login"
        echo "Последняя смена пароля: ${changed:-Нет данных}"
        echo
    done
}

# Проверка параметров sshd
sshd_section() {
    local sshd_cmd key value config_lines config_file
    local configs=(/etc/ssh/sshd_config)

    sshd_cmd=$(command -v sshd 2>/dev/null)
    if [[ -z "$sshd_cmd" && -x /usr/sbin/sshd ]]; then
        sshd_cmd=/usr/sbin/sshd
    fi
    if [[ -z "$sshd_cmd" ]]; then
        die "sshd не установлен. Установите пакет openssh-server"
    fi

    if ! as_root "$sshd_cmd" -T > "$TMP_DIR/sshd.tmp" 2> "$TMP_DIR/sshd_error.tmp"; then
        echo "Не удалось получить настройки sshd"
        cat "$TMP_DIR/sshd_error.tmp"
        return
    fi

    # Основной конфиг и стандартный каталог с дополнительными конфигами
    for config_file in /etc/ssh/sshd_config.d/*.conf; do
        [[ -f "$config_file" ]] && configs+=("$config_file")
    done

    for key in permitrootlogin port logingracetime maxauthtries passwordauthentication pubkeyauthentication; do
        value=$(grep -m 1 "^$key " "$TMP_DIR/sshd.tmp" | cut -d ' ' -f2-)
        config_lines=$(as_root grep -inEi "^[[:space:]]*${key}([[:space:]]|$)" "${configs[@]}" 2>/dev/null || true) # Ищем незакомменированные параметры в конфигах(правда пропустит Match)

        if [[ -n "$config_lines" ]]; then
            echo "$key: ${value:-Нет данных} Есть в файлах конфига"
            echo "$config_lines"
        else
            echo "$key: ${value:-Нет данных} Нет в файлах конфига"
        fi
    done
}

# Подозрительные пользователи
suspicious_section() {
    local empty zero

    empty=$(as_root cut -d : -f1-2 /etc/shadow | grep ':$' | cut -d : -f1) || return 1
    zero=$(getent passwd | cut -d : -f1,3 | grep ':0$' | grep -v '^root:0$' | tr ':' ' ')

    echo "Пользователи с пустым паролем:"
    echo "${empty:-Не обнаружены}"
    echo
    echo "Пользователи с UID 0 (кроме root):"
    echo "${zero:-Не обнаружены}"
}

# Файлы с suid
suid_section() {
    as_root find /usr/bin /usr/sbin -type f -perm -4000 -printf '%m %u:%g %p\n' 2>/dev/null | sort
}

trap cleanup EXIT # Ставим триггер на завершение скрипта, чтобы очищать временные файлы при ctrl+c

# Обработка параметров
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if [[ "$1" == -* ]]; then
    die "Неизвестный параметр: $1"
fi

if [[ $# -gt 1 ]]; then
    die "Можно указать только один путь к отчету"
fi

if [[ $# -eq 1 ]]; then
    OUT_FILE="$1"
fi

# Проверка программ
check_privileges
check_tool lspci pciutils
check_tool nproc coreutils
check_tool lscpu util-linux
check_tool lslogins util-linux
check_tool free procps
check_tool ps procps
check_tool getent libc-bin
check_tool chage passwd
check_tool find findutils
check_tool awk 'gawk или mawk'
check_tool grep grep
check_tool cut coreutils
check_tool xargs findutils

# Подготовка
mkdir -p "$TMP_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$OUT_FILE")" || die "Не удалось создать каталоги"

# Сбор данных
date > "$TMP_DIR/date.tmp"
hostname > "$TMP_DIR/hostname.tmp"
whoami > "$TMP_DIR/whoami.tmp"
pwd > "$TMP_DIR/pwd.tmp"
ls > "$TMP_DIR/ls.tmp"
uname -svp > "$TMP_DIR/uname.tmp"
cp /etc/os-release "$TMP_DIR/os-release.tmp"
lscpu > "$TMP_DIR/cpu_info.tmp"
nproc > "$TMP_DIR/cpu_logical_cores.tmp"
free -h > "$TMP_DIR/free.tmp"

for field in board_name bios_date bios_version; do
    if [[ -r "/sys/devices/virtual/dmi/id/$field" ]]; then
        cat "/sys/devices/virtual/dmi/id/$field" > "$TMP_DIR/$field.tmp"
    else
        echo "-" > "$TMP_DIR/$field.tmp"
    fi
done

lspci > "$TMP_DIR/lspci.tmp"

# Обработка данных
cat "$TMP_DIR/os-release.tmp" | grep '^PRETTY_NAME=' | cut -d = -f2- | tr -d '"' > "$TMP_DIR/os-version.tmp"
cat "$TMP_DIR/cpu_info.tmp" | grep_cut_strip 'Model name:' > "$TMP_DIR/cpu_model.tmp"
cat "$TMP_DIR/cpu_info.tmp" | grep_cut_strip 'CPU max MHz:' > "$TMP_DIR/cpu-freq-max.tmp"
cat "$TMP_DIR/cpu_info.tmp" | grep_cut_strip 'CPU min MHz:' > "$TMP_DIR/cpu-freq-min.tmp"
cat "$TMP_DIR/cpu_info.tmp" | grep_cut_strip 'L1i cache:' > "$TMP_DIR/cpu_l1i_cache.tmp"
cat "$TMP_DIR/cpu_info.tmp" | grep_cut_strip 'L1d cache:' > "$TMP_DIR/cpu_l1d_cache.tmp"
cat "$TMP_DIR/cpu_info.tmp" | grep_cut_strip 'L2 cache:' > "$TMP_DIR/cpu_l2_cache.tmp"
cat "$TMP_DIR/cpu_info.tmp" | grep_cut_strip 'L3 cache:' > "$TMP_DIR/cpu_l3_cache.tmp"

cat "$TMP_DIR/free.tmp" | grep '^Mem:' | xargs | cut -d ' ' -f2 > "$TMP_DIR/physical_mem.tmp"

# Формирование отчета
cat <<EOF > "$OUT_FILE"
Формат отчета: $FORMAT_VERSION

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
Количество логических ядер: $(cat "$TMP_DIR/cpu_logical_cores.tmp")
Кэш L1i: $(val=$(cat "$TMP_DIR/cpu_l1i_cache.tmp"); echo "${val:--}")
Кэш L1d: $(val=$(cat "$TMP_DIR/cpu_l1d_cache.tmp"); echo "${val:--}")
Кэш L2: $(val=$(cat "$TMP_DIR/cpu_l2_cache.tmp"); echo "${val:--}")
Кэш L3: $(val=$(cat "$TMP_DIR/cpu_l3_cache.tmp"); echo "${val:--}")

=== Память ===
Объем физической памяти: $(cat "$TMP_DIR/physical_mem.tmp")

=== Платформа ===
Модель материнской платы: $(cat "$TMP_DIR/board_name.tmp")
Версия BIOS: $(cat "$TMP_DIR/bios_version.tmp")
Дата выпуска BIOS: $(cat "$TMP_DIR/bios_date.tmp")
EOF

write_section 'Устройства подключенные к шине PCI' < "$TMP_DIR/lspci.tmp"

write_section 'Информация о директории' <<EOF
Текущая директория: $(cat "$TMP_DIR/pwd.tmp")
Содержимое текущей директории:
$(cat "$TMP_DIR/ls.tmp")
EOF

write_section 'Пользователи' < <(users_section)
write_section 'Параметры sshd' < <(sshd_section)
write_section 'Топ-5 процессов по памяти' < <(ps -eo pid,ppid,user,%mem,args --sort=-%mem | head -n 6)
write_section 'Подозрительные учетные записи' < <(suspicious_section)
write_section 'Файлы с suid' < <(suid_section)

# Запись лога о выполнении
log_run || die "Не удалось записать лог"

# Удаление временных файлов
cleanup

echo "Отчет сохранен: $OUT_FILE"