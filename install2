#!/bin/sh
# VPSMonitor Installer for Keenetic Entware
# GitHub: https://github.com/romaca4/vpsmonitor-ui

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║        VPSMonitor Installer  ·  v1.1          ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}AWG 2.0 VPS Monitor – WebUI${NC}"
echo "Веб-панель для мониторинга трафика WireGuard"
echo ""
echo -e "${YELLOW}${BOLD}⚠  ВАЖНО:${NC}"
echo -e "   Панель работает ${BOLD}только с VPS, на которых установлен AmneziaWG 2.0${NC}"
echo "   (установщик install_amneziawg_en.sh от bivlked)."
echo "   С другими реализациями WireGuard работа не гарантируется."
echo ""

if [ ! -d /opt ]; then
    echo -e "${RED}Ошибка: /opt не найден. Убедитесь, что Entware установлен.${NC}"
    exit 1
fi

# ---------- ПРОВЕРКА ЗАВИСИМОСТЕЙ ----------
echo -e "${YELLOW}[1/6] Проверка зависимостей...${NC}"
echo "      Нужны: python3, expect, cron, dos2unix."
MISSING=""
for pkg in python3 expect cron dos2unix; do
    if ! opkg list-installed | grep -q "^$pkg"; then
        MISSING="$MISSING $pkg"
    fi
done

if [ -n "$MISSING" ]; then
    echo -e "${YELLOW}      Отсутствуют:$MISSING${NC}"
    echo -n "      Установить их сейчас? (y/n) "
    read -p "" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        opkg update
        opkg install $MISSING
    else
        echo -e "${RED}Установка отменена.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}      ✓ Все зависимости на месте.${NC}"
echo ""

# ---------- НАСТРОЙКА ВЕБ-ИНТЕРФЕЙСА ----------
echo -e "${YELLOW}[2/6] Настройка веб-интерфейса${NC}"
echo "      Порт, на котором будет доступна панель."
echo -n "      Порт (по умолчанию 2000): "
read WEB_PORT
WEB_PORT=${WEB_PORT:-2000}
echo -e "${GREEN}      ✓ Порт: ${BOLD}$WEB_PORT${NC}"
echo ""

# ---------- НАСТРОЙКА СЕРВЕРОВ ----------
echo -e "${YELLOW}[3/6] Настройка SSH-подключений к серверам WireGuard${NC}"
echo "      Укажите параметры для доступа к вашим VPS."
echo -n "      SSH порт (по умолчанию 22): "
read SSH_PORT
SSH_PORT=${SSH_PORT:-22}
echo -n "      SSH пользователь (по умолчанию root): "
read SSH_USER
SSH_USER=${SSH_USER:-root}
echo ""

read -p "      Сколько серверов вы хотите добавить? " SERVER_COUNT
while ! [[ "$SERVER_COUNT" =~ ^[1-9][0-9]*$ ]]; do
    echo -e "${RED}      Введите положительное число.${NC}"
    read -p "      Количество серверов: " SERVER_COUNT
done

for i in $(seq 1 $SERVER_COUNT); do
    echo -e "      ${CYAN}--- Сервер $i ---${NC}"
    read -p "      IP сервера или домен: " domain
    while [ -z "$domain" ]; do
        echo -e "${RED}      Адрес не может быть пустым!${NC}"
        read -p "      IP сервера или домен: " domain
    done
    echo "      При вводе пароля символы не отображаются — это нормально."
    read -sp "      Пароль SSH: " pass
    echo
    eval "SERVER$i=\"$domain\""
    eval "PASS$i=\"$pass\""
done
echo ""

# ---------- ЧАСТОТА СБОРА ----------
echo -e "${YELLOW}[4/6] Частота автоматического сбора статистики${NC}"
echo "      Как часто опрашивать серверы:"
echo -e "        1 — 1 раз в сутки        (03:00)"
echo -e "        2 — 2 раза в сутки       (06:00, 18:00)  ${BOLD}← по умолчанию${NC}"
echo -e "        3 — 3 раза в сутки       (00:00, 08:00, 16:00)"
echo -e "        4 — 4 раза в сутки       (00:00, 06:00, 12:00, 18:00)"
echo -e "        5 — 1 раз в неделю       (воскресенье 03:00)"
echo -e "        6 — 3 раза в неделю      (пн, ср, пт 03:00)"
echo -e "        7 — 1 раз в месяц        (1-е число 03:00)"
echo -e "        8 — 2 раза в месяц       (1-е и 15-е 03:00)"
echo -e "        9 — 3 раза в месяц       (1-е, 11-е, 21-е 03:00)"
read -p "      Введите номер (1–9, Enter = 2): " FREQ
FREQ=${FREQ:-2}
while ! [[ "$FREQ" =~ ^[1-9]$ ]]; do
    echo -e "${RED}      Ошибка: введите число от 1 до 9.${NC}"
    read -p "      Введите номер (1–9): " FREQ
done

CRON_LINES=""
case "$FREQ" in
    1) CRON_LINES="0 3 * * *" ;;
    2) CRON_LINES="0 6 * * *
0 18 * * *" ;;
    3) CRON_LINES="0 0 * * *
0 8 * * *
0 16 * * *" ;;
    4) CRON_LINES="0 0 * * *
0 6 * * *
0 12 * * *
0 18 * * *" ;;
    5) CRON_LINES="0 3 * * 0" ;;
    6) CRON_LINES="0 3 * * 1
0 3 * * 3
0 3 * * 5" ;;
    7) CRON_LINES="0 3 1 * *" ;;
    8) CRON_LINES="0 3 1,15 * *" ;;
    9) CRON_LINES="0 3 1,11,21 * *" ;;
esac

mkdir -p /opt/etc/vpsmonitor-ui
case "$FREQ" in
    1) SCHEDULE_DESC="1 раз в сутки (03:00)" ;;
    2) SCHEDULE_DESC="2 раза в сутки (06:00 и 18:00)" ;;
    3) SCHEDULE_DESC="3 раза в сутки (00:00, 08:00, 16:00)" ;;
    4) SCHEDULE_DESC="4 раза в сутки (00:00, 06:00, 12:00, 18:00)" ;;
    5) SCHEDULE_DESC="1 раз в неделю (воскресенье в 03:00)" ;;
    6) SCHEDULE_DESC="3 раза в неделю (пн, ср, пт в 03:00)" ;;
    7) SCHEDULE_DESC="1 раз в месяц (1-е число в 03:00)" ;;
    8) SCHEDULE_DESC="2 раза в месяц (1-е и 15-е в 03:00)" ;;
    9) SCHEDULE_DESC="3 раза в месяц (1-е, 11-е, 21-е в 03:00)" ;;
esac
echo "$SCHEDULE_DESC" > /opt/etc/vpsmonitor-ui/schedule.conf
echo -e "${GREEN}      ✓ Расписание: ${BOLD}$SCHEDULE_DESC${NC}"
echo ""

# ---------- РОТАЦИЯ ФАЙЛОВ ----------
echo -e "${YELLOW}[5/6] Ротация истории${NC}"
echo "      Сколько последних снимков хранить для каждого сервера?"
echo -e "        1 — 7 файлов"
echo -e "        2 — 14 файлов  ${BOLD}← по умолчанию${NC}"
echo -e "        3 — 30 файлов"
echo -e "        4 — 60 файлов"
echo -e "        5 — без ограничений"
read -p "      Введите номер (1–5, Enter = 2): " ROT
ROT=${ROT:-2}
while ! [[ "$ROT" =~ ^[1-5]$ ]]; do
    echo -e "${RED}      Ошибка: введите число от 1 до 5.${NC}"
    read -p "      Введите номер (1–5): " ROT
done
case "$ROT" in
    1) ROTATION=7; ROTATION_DESC="7 файлов" ;;
    2) ROTATION=14; ROTATION_DESC="14 файлов" ;;
    3) ROTATION=30; ROTATION_DESC="30 файлов" ;;
    4) ROTATION=60; ROTATION_DESC="60 файлов" ;;
    5) ROTATION="unlimited"; ROTATION_DESC="без ограничений" ;;
esac
echo "$ROTATION_DESC" > /opt/etc/vpsmonitor-ui/rotation.conf
echo -e "${GREEN}      ✓ Ротация: ${BOLD}$ROTATION_DESC${NC}"
echo ""

# ---------- ОБРЕЗКА ВЫВОДА ----------
echo -e "${YELLOW}[6/6] Обрезка вывода${NC}"
echo "      В выводе команды статистики первые 8 строк — заголовок,"
echo "      последняя строка — разделитель. Их можно убирать для компактности."
echo -e "      ${CYAN}Рекомендуется: обрезать (да).${NC}"
echo -n "      Обрезать вывод? (y/n, Enter = y): "
read -p "" -n 1 -r TRIM
echo
if [[ $TRIM =~ ^[Nn]$ ]]; then
    echo "no" > /opt/etc/vpsmonitor-ui/trim.conf
    TRIM_DESC="нет"
else
    echo "yes" > /opt/etc/vpsmonitor-ui/trim.conf
    TRIM_DESC="да"
fi
echo -e "${GREEN}      ✓ Обрезка: ${BOLD}$TRIM_DESC${NC}"
echo ""

echo -e "${CYAN}Все данные собраны. Начинаю установку...${NC}"
echo ""

# ================= ГЕНЕРАЦИЯ СКРИПТОВ =================

generate_collect_script() {
    cat > /opt/etc/vpsmonitor-ui/vpsmonitor.sh << EOF
#!/bin/sh
export PATH=/opt/bin:/opt/sbin:/bin:/sbin:/usr/bin:/usr/sbin

STATS_DIR="/tmp/vpsmonitor_stats"
mkdir -p "\$STATS_DIR"

SSH_PORT="$SSH_PORT"
SSH_USER="$SSH_USER"
SERVER_COUNT=$SERVER_COUNT
ROTATION="$ROTATION"

EOF

    for i in $(seq 1 $SERVER_COUNT); do
        eval "domain=\"\$SERVER$i\""
        eval "pass=\"\$PASS$i\""
        cat >> /opt/etc/vpsmonitor-ui/vpsmonitor.sh << EOF
SERVER$i="$domain"
PASS$i="$pass"
EOF
    done

    cat >> /opt/etc/vpsmonitor-ui/vpsmonitor.sh << 'EOF'

collect() {
    local server="$1"
    local pass="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local outfile="$STATS_DIR/stats_${server}_${timestamp}.txt"
    expect -c "
        set timeout 15
        spawn ssh -p $SSH_PORT -o StrictHostKeyChecking=no $SSH_USER@$server \"bash /root/awg/manage_amneziawg.sh stats\"
        expect \"password:\" { send \"$pass\r\" }
        expect eof
    " > "$outfile" 2>&1
    if [ -s "$outfile" ]; then
        echo "OK: $server"
        rm -f "$STATS_DIR/error_${server}.txt"
    else
        echo "FAIL: $server (пустой вывод)"
        rm -f "$outfile"
        echo "1" > "$STATS_DIR/error_${server}.txt"
    fi
}

for i in $(seq 1 $SERVER_COUNT); do
    eval "server=\"\$SERVER$i\""
    eval "pass=\"\$PASS$i\""
    collect "$server" "$pass"
done

if [ "$ROTATION" != "unlimited" ] && [ -n "$ROTATION" ]; then
    for i in $(seq 1 $SERVER_COUNT); do
        eval "server=\"\$SERVER$i\""
        ls -t "$STATS_DIR"/stats_${server}_*.txt 2>/dev/null | tail -n +$((ROTATION + 1)) | xargs rm -f 2>/dev/null
    done
fi
EOF

    chmod +x /opt/etc/vpsmonitor-ui/vpsmonitor.sh
    dos2unix /opt/etc/vpsmonitor-ui/vpsmonitor.sh
}

generate_collect_script

# ================= ВЕБ-СЕРВЕР =================

cat > /opt/etc/vpsmonitor-ui/vpsmonitor.py << 'PYEOF'
#!/opt/bin/python3
import http.server
import os
import glob
import urllib.parse
import json
from datetime import datetime, timedelta

STATS_DIR = '/tmp/vpsmonitor_stats'
PORT = __WEB_PORT__
NAMES_FILE = '/opt/etc/vpsmonitor-ui/server_names.json'
SCHEDULE_FILE = '/opt/etc/vpsmonitor-ui/schedule.conf'
ROTATION_FILE = '/opt/etc/vpsmonitor-ui/rotation.conf'
TRIM_FILE = '/opt/etc/vpsmonitor-ui/trim.conf'
CONFIG_FILE = '/opt/etc/vpsmonitor-ui/vpsmonitor.sh'

def load_names():
    if os.path.exists(NAMES_FILE):
        try:
            with open(NAMES_FILE, 'r') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_names(names):
    with open(NAMES_FILE, 'w') as f:
        json.dump(names, f, indent=2)

def load_text(path):
    if os.path.exists(path):
        with open(path, 'r') as f:
            return f.read().strip()
    return "Неизвестно"

def should_trim():
    if os.path.exists(TRIM_FILE):
        with open(TRIM_FILE, 'r') as f:
            return f.read().strip() == 'yes'
    return True

def next_monthly_run(now, days):
    for offset in (0, 1):
        year = now.year
        month = now.month + offset
        if month > 12:
            month -= 12
            year += 1
        for d in sorted(days):
            try:
                candidate = now.replace(year=year, month=month, day=d,
                                        hour=3, minute=0, second=0, microsecond=0)
            except ValueError:
                continue
            if candidate > now:
                return candidate
    return None

def get_next_run(desc):
    now = datetime.now()
    if "1 раз в сутки" in desc:
        nr = now.replace(hour=3, minute=0, second=0, microsecond=0)
        if nr <= now: nr += timedelta(days=1)
        return nr.strftime('%d.%m.%Y в %H:%M')
    if "2 раза в сутки" in desc:
        for h,m in [(6,0),(18,0)]:
            dt = now.replace(hour=h, minute=m, second=0, microsecond=0)
            if dt > now: return dt.strftime('%d.%m.%Y в %H:%M')
        dt = now.replace(hour=6, minute=0, second=0, microsecond=0) + timedelta(days=1)
        return dt.strftime('%d.%m.%Y в %H:%M')
    if "3 раза в сутки" in desc:
        for h,m in [(0,0),(8,0),(16,0)]:
            dt = now.replace(hour=h, minute=m, second=0, microsecond=0)
            if dt > now: return dt.strftime('%d.%m.%Y в %H:%M')
        dt = now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
        return dt.strftime('%d.%m.%Y в %H:%M')
    if "4 раза в сутки" in desc:
        for h,m in [(0,0),(6,0),(12,0),(18,0)]:
            dt = now.replace(hour=h, minute=m, second=0, microsecond=0)
            if dt > now: return dt.strftime('%d.%m.%Y в %H:%M')
        dt = now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
        return dt.strftime('%d.%m.%Y в %H:%M')
    if "3 раза в неделю" in desc:
        for wd in [0,2,4]:
            d = wd - now.weekday()
            if d < 0: d += 7
            if d == 0 and now.hour >= 3: d = 7
            nr = now.replace(hour=3, minute=0, second=0, microsecond=0) + timedelta(days=d)
            return nr.strftime('%d.%m.%Y в %H:%M')
    if "1 раз в неделю" in desc:
        d = 6 - now.weekday()
        if d <= 0: d += 7
        nr = now.replace(hour=3, minute=0, second=0, microsecond=0) + timedelta(days=d)
        return nr.strftime('%d.%m.%Y в %H:%M')
    if "3 раза в месяц" in desc:
        nr = next_monthly_run(now, [1,11,21])
        if nr: return nr.strftime('%d.%m.%Y в %H:%M')
    if "2 раза в месяц" in desc:
        nr = next_monthly_run(now, [1,15])
        if nr: return nr.strftime('%d.%m.%Y в %H:%M')
    if "1 раз в месяц" in desc:
        nr = next_monthly_run(now, [1])
        if nr: return nr.strftime('%d.%m.%Y в %H:%M')
    return "Неизвестно"

def get_dir_size(path):
    total = 0
    if os.path.exists(path):
        for dirpath, _, filenames in os.walk(path):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                try:
                    total += os.path.getsize(fp)
                except:
                    pass
    return total

def human_size(size):
    for unit in ['Б', 'КБ', 'МБ', 'ГБ']:
        if size < 1024: return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} ТБ"

def parse_content(content):
    if not should_trim():
        return content
    lines = content.splitlines()
    if len(lines) > 8:
        lines = lines[8:]
        if lines: lines = lines[:-1]
        return '\n'.join(lines)
    return ''

class StatsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(self.generate_html().encode('utf-8'))
        elif path == '/favicon.ico':
            self.send_favicon()
        elif path == '/api/latest':
            self.send_json(self.get_latest())
        elif path == '/api/history':
            self.send_json(self.get_history())
        elif path == '/api/file':
            self.serve_file(parsed.query)
        elif path == '/api/names':
            self.send_json(load_names())
        elif path == '/api/schedule':
            self.send_json(self.get_schedule())
        elif path == '/api/info':
            self.send_json(self.get_info())
        elif path == '/api/cleanup':
            self.cleanup_history()
        elif path == '/api/cleanup_server':
            self.cleanup_server_history(parsed.query)
        elif path == '/api/backup':
            self.backup_config()
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path == '/api/setname':
            self.set_name()
        elif path == '/api/restore':
            self.restore_config()
        else:
            self.send_error(404)

    def send_favicon(self):
        svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">🌍</text></svg>'
        self.send_response(200)
        self.send_header('Content-type', 'image/svg+xml')
        self.end_headers()
        self.wfile.write(svg.encode('utf-8'))

    def send_json(self, data):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

    def get_schedule(self):
        desc = load_text(SCHEDULE_FILE)
        return {'description': desc, 'next_run': get_next_run(desc)}

    def get_info(self):
        return {
            'schedule': load_text(SCHEDULE_FILE),
            'rotation': load_text(ROTATION_FILE),
            'trim': 'да' if should_trim() else 'нет',
            'dir_size': human_size(get_dir_size(STATS_DIR)),
            'version': '1.1'
        }

    def backup_config(self):
        if not os.path.exists(CONFIG_FILE):
            self.send_error(404)
            return
        with open(CONFIG_FILE, 'r') as f:
            content = f.read()
        self.send_response(200)
        self.send_header('Content-type', 'text/plain; charset=utf-8')
        self.send_header('Content-Disposition', 'attachment; filename=vpsmonitor.sh')
        self.end_headers()
        self.wfile.write(content.encode('utf-8'))

    def restore_config(self):
        length = int(self.headers.get('Content-Length', 0))
        try:
            content = self.rfile.read(length).decode('utf-8')
            if len(content) < 100 or '#!/bin/sh' not in content:
                self.send_json({'status': 'error', 'message': 'Некорректный файл конфигурации'})
                return
            with open(CONFIG_FILE, 'w') as f:
                f.write(content)
            os.chmod(CONFIG_FILE, 0o755)
            self.send_json({'status': 'ok', 'message': 'Конфигурация восстановлена. Не забудьте перезапустить сервер.'})
        except Exception as e:
            self.send_json({'status': 'error', 'message': str(e)})

    def cleanup_history(self):
        try:
            files = glob.glob(os.path.join(STATS_DIR, 'stats_*.txt'))
            servers = {}
            for f in files:
                basename = os.path.basename(f)
                parts = basename.split('_')
                if len(parts) >= 4:
                    domain = '_'.join(parts[1:-2])
                    servers.setdefault(domain, []).append(f)
            for domain, flist in servers.items():
                flist.sort(key=lambda x: os.path.getmtime(x), reverse=True)
                for f in flist[1:]:
                    os.remove(f)
            self.send_json({'status': 'ok', 'message': 'История очищена'})
        except Exception as e:
            self.send_json({'status': 'error', 'message': str(e)})

    def cleanup_server_history(self, query):
        params = urllib.parse.parse_qs(query)
        domain = params.get('domain', [''])[0]
        if not domain:
            self.send_json({'status': 'error', 'message': 'Не указан сервер'})
            return
        try:
            files = glob.glob(os.path.join(STATS_DIR, f'stats_{domain}_*.txt'))
            files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
            for f in files[1:]:
                os.remove(f)
            self.send_json({'status': 'ok', 'message': f'История для {domain} очищена'})
        except Exception as e:
            self.send_json({'status': 'error', 'message': str(e)})

    def set_name(self):
        length = int(self.headers.get('Content-Length', 0))
        data = json.loads(self.rfile.read(length).decode('utf-8'))
        domain = data.get('domain')
        new_name = data.get('name', '').strip()
        if not domain or not new_name:
            self.send_json({'status': 'error', 'message': 'Неверные данные'})
            return
        names = load_names()
        names[domain] = new_name
        save_names(names)
        self.send_json({'status': 'ok'})

    def get_latest(self):
        files = glob.glob(os.path.join(STATS_DIR, 'stats_*.txt'))
        servers = {}
        for f in files:
            basename = os.path.basename(f)
            parts = basename.split('_')
            if len(parts) >= 4:
                domain = '_'.join(parts[1:-2])
                date_part = parts[-2]
                time_part = parts[-1].replace('.txt', '')
                ts_str = f'{date_part}_{time_part}'
                servers.setdefault(domain, []).append((ts_str, f))
        result = {}
        names = load_names()
        for domain, files_list in servers.items():
            files_list.sort(key=lambda x: x[0], reverse=True)
            latest_ts, latest_file = files_list[0]
            with open(latest_file, 'r') as f:
                content = f.read()
            content = parse_content(content)
            try:
                dt = datetime.strptime(latest_ts, '%Y%m%d_%H%M%S')
                formatted = dt.strftime('%d.%m.%Y в %H:%M')
            except:
                formatted = latest_ts
            display_name = names.get(domain, domain)
            error_file = os.path.join(STATS_DIR, f'error_{domain}.txt')
            status = 'error' if os.path.exists(error_file) else 'ok'
            result[domain] = {
                'display_name': display_name,
                'timestamp': formatted,
                'content': content,
                'raw_ts': latest_ts,
                'status': status,
                'history_count': len(files_list)
            }
        return result

    def get_history(self):
        files = glob.glob(os.path.join(STATS_DIR, 'stats_*.txt'))
        history = {}
        for f in files:
            basename = os.path.basename(f)
            parts = basename.split('_')
            if len(parts) >= 4:
                domain = '_'.join(parts[1:-2])
                date_part = parts[-2]
                time_part = parts[-1].replace('.txt', '')
                ts_str = f'{date_part}_{time_part}'
                history.setdefault(domain, []).append({
                    'timestamp': ts_str,
                    'file': basename
                })
        for domain in history:
            history[domain].sort(key=lambda x: x['timestamp'], reverse=True)
        return history

    def serve_file(self, query):
        params = urllib.parse.parse_qs(query)
        filename = params.get('file', [''])[0]
        if not filename:
            self.send_error(400)
            return
        full_path = os.path.join(STATS_DIR, filename)
        if not os.path.exists(full_path):
            self.send_error(404)
            return
        with open(full_path, 'r') as f:
            content = f.read()
        content = parse_content(content)
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(content.encode('utf-8'))

    def generate_html(self):
        return '''<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AWG 2.0 VPS Monitor – WebUI</title>
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🌍</text></svg>">
<style>
:root {
    --bg-body:#0d1117; --bg-container:rgba(22,27,34,0.85); --border-color:#30363d;
    --text-primary:#f0f6fc; --text-secondary:#c9d1d9; --text-muted:#8b949e;
    --card-bg:#161b22; --card-border:#30363d; --card-shadow:0 6px 20px rgba(0,0,0,0.5);
    --pre-bg:#0d1117; --pre-border:#21262d; --accent:#58a6ff; --accent-hover:#79c0ff;
    --footer-border:#21262d; --btn-bg:#21262d; --btn-hover:#30363d;
    --input-bg:#0d1117; --input-border:#30363d; --input-focus:#58a6ff;
    --ok:#3fb950; --fail:#f85149;
}
body.light {
    --bg-body:#f6f8fa; --bg-container:rgba(255,255,255,0.9); --border-color:#d0d7de;
    --text-primary:#1f2328; --text-secondary:#24292f; --text-muted:#57606a;
    --card-bg:#fff; --card-border:#d0d7de; --card-shadow:0 6px 20px rgba(0,0,0,0.08);
    --pre-bg:#f6f8fa; --pre-border:#d0d7de; --accent:#0969da; --accent-hover:#0550ae;
    --footer-border:#d0d7de; --btn-bg:#f6f8fa; --btn-hover:#eaeef2;
    --input-bg:#fff; --input-border:#d0d7de; --input-focus:#0969da;
}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg-body);color:var(--text-secondary);font-family:'Segoe UI',-apple-system,BlinkMacSystemFont,Roboto,sans-serif;padding:20px;display:flex;justify-content:center;min-height:100vh;transition:background .3s,color .3s;}
.container{max-width:1200px;width:100%;background:var(--bg-container);backdrop-filter:blur(8px);border-radius:24px;padding:30px 30px 20px;box-shadow:0 8px 32px rgba(0,0,0,0.3);border:1px solid var(--border-color);}
header{text-align:center;padding:10px 0 15px;border-bottom:2px solid var(--border-color);margin-bottom:15px;}
header .globe{font-size:3.2rem;display:block;margin-bottom:4px;animation:pulse 2s infinite;}
@keyframes pulse{0%{transform:scale(1);}50%{transform:scale(1.1);}100%{transform:scale(1);}}
header h1{font-size:2.4rem;font-weight:300;letter-spacing:2px;color:var(--text-primary);}
header h1 span{color:var(--accent);font-weight:600;}
.subtitle{font-size:.95rem;color:var(--text-muted);margin-top:4px;letter-spacing:1px;}
.schedule-info{text-align:center;font-size:.9rem;color:var(--text-muted);margin:10px auto 5px;background:var(--pre-bg);padding:6px 14px;border-radius:20px;display:inline-block;border:1px solid var(--pre-border);cursor:pointer;transition:.2s;}
.schedule-info:hover{border-color:var(--accent);}
.summary-bar{display:flex;justify-content:center;gap:20px;margin:10px auto 15px;flex-wrap:wrap;font-size:.9rem;color:var(--text-muted);}
.summary-bar .item{background:var(--pre-bg);padding:5px 14px;border-radius:20px;border:1px solid var(--pre-border);}
.summary-bar .ok{color:var(--ok);}
.summary-bar .fail{color:var(--fail);}
.toolbar{display:flex;gap:10px;margin-bottom:20px;flex-wrap:wrap;align-items:center;}
.toolbar input[type="text"],.toolbar select{flex:1 1 200px;padding:8px 12px;background:var(--input-bg);border:1px solid var(--input-border);border-radius:10px;color:var(--text-primary);outline:none;font-size:.9rem;transition:.2s;}
.toolbar input:focus,.toolbar select:focus{border-color:var(--input-focus);}
.server-card{background:var(--card-bg);border:1px solid var(--card-border);border-radius:16px;padding:20px;margin-bottom:24px;transition:.3s;box-shadow:var(--card-shadow);cursor:pointer;}
.server-card:hover{border-color:var(--accent);transform:translateY(-2px);}
.server-header{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;margin-bottom:6px;}
.server-status{display:inline-block;width:12px;height:12px;border-radius:50%;margin-right:8px;vertical-align:middle;}
.server-status.ok{background:var(--ok);}
.server-status.fail{background:var(--fail);}
.server-status.unknown{background:var(--text-muted);}
.server-name{font-size:1.5rem;font-weight:500;color:var(--text-primary);cursor:pointer;padding:4px 10px;border-radius:6px;display:inline-block;background:var(--pre-bg);border:1px solid transparent;pointer-events:auto;transition:.2s;}
.server-name:hover{background:var(--btn-bg);border-color:var(--border-color);}
.server-name-input{font-size:1.5rem;background:var(--input-bg);border:1px solid var(--input-focus);color:var(--text-primary);padding:4px 10px;border-radius:6px;outline:none;font-weight:500;min-width:180px;}
.server-meta{color:var(--text-muted);font-size:.9rem;margin-top:6px;display:flex;flex-wrap:wrap;justify-content:flex-end;gap:12px;}
.action-btn{background:none;border:1px solid var(--border-color);color:var(--text-muted);cursor:pointer;font-size:.8rem;padding:3px 12px;border-radius:12px;background:var(--btn-bg);transition:.2s;}
.action-btn:hover{background:var(--btn-hover);color:var(--text-primary);}
pre{background:var(--pre-bg);border:1px solid var(--pre-border);border-radius:10px;padding:14px;font-size:.85rem;overflow-x:auto;white-space:pre-wrap;word-break:break-word;margin:14px 0 10px;font-family:'JetBrains Mono','Fira Code',monospace;color:var(--text-secondary);line-height:1.5;}
.server-content{transition:max-height .3s ease,opacity .3s;overflow:hidden;}
.server-content.collapsed{max-height:0 !important;opacity:0;padding:0 !important;margin:0 !important;}
.history-list{display:none;margin-top:12px;background:var(--pre-bg);border-radius:10px;border:1px solid var(--pre-border);padding:6px 0;}
.history-list.show{display:block;}
.history-item{padding:8px 16px;border-bottom:1px solid var(--pre-border);cursor:pointer;font-size:.9rem;display:flex;justify-content:space-between;align-items:center;transition:.15s;}
.history-item:last-child{border-bottom:none;}
.history-item:hover{background:var(--btn-bg);}
.history-item .date{color:var(--text-muted);margin-right:12px;}
.history-content{display:none;margin:8px 16px 16px;background:var(--pre-bg);border-left:3px solid var(--accent);padding:10px 16px;border-radius:6px;font-size:.8rem;white-space:pre-wrap;word-break:break-word;}
.history-content.show{display:block;}
.footer{margin-top:40px;text-align:center;color:var(--text-muted);font-size:.8rem;border-top:1px solid var(--footer-border);padding-top:18px;}
.footer .footer-controls{display:flex;justify-content:center;gap:10px;margin-bottom:10px;}
.footer-controls .btn-icon{background:none;border:1px solid var(--border-color);border-radius:30px;padding:4px 14px;cursor:pointer;font-size:.85rem;color:var(--text-secondary);background:var(--btn-bg);transition:.2s;}
.footer-controls .btn-icon:hover{background:var(--btn-hover);border-color:var(--accent);}
.footer a{color:var(--accent);text-decoration:none;}
.footer .version{margin-top:6px;font-size:.75rem;color:var(--text-muted);}
.status-msg{text-align:center;margin:10px 0;font-size:.9rem;min-height:1.5em;color:var(--text-muted);}
.status-msg.error{color:var(--fail);}
.status-msg.success{color:var(--ok);}
.modal{display:none;position:fixed;z-index:1000;left:0;top:0;width:100%;height:100%;background:rgba(0,0,0,0);justify-content:center;align-items:center;opacity:0;transition:opacity .25s,background .25s;}
.modal.show{display:flex;opacity:1;background:rgba(0,0,0,0.6);}
.modal-content{background:var(--card-bg);border:1px solid var(--border-color);border-radius:16px;padding:25px;max-width:720px;width:92%;max-height:85vh;overflow-y:auto;color:var(--text-secondary);transform:scale(0.92);opacity:0;transition:transform .25s ease,opacity .25s ease;}
.modal.show .modal-content{transform:scale(1);opacity:1;}
.modal-content h2{color:var(--text-primary);margin-bottom:15px;}
.modal-content p{margin:10px 0;line-height:1.6;}
.modal-content code{background:var(--pre-bg);padding:2px 6px;border-radius:4px;font-family:monospace;color:var(--accent);}
.code-block{background:var(--pre-bg);padding:10px 14px;border-radius:6px;border:1px solid var(--pre-border);font-family:monospace;font-size:.9rem;white-space:pre-wrap;word-break:break-word;cursor:pointer;transition:.2s;margin:8px 0;}
.code-block:hover{border-color:var(--accent);}
.tabs{display:flex;gap:4px;border-bottom:1px solid var(--border-color);margin-bottom:20px;}
.tab{padding:8px 16px;cursor:pointer;border-radius:8px 8px 0 0;color:var(--text-muted);transition:.2s;font-size:.9rem;font-weight:500;}
.tab:hover{color:var(--text-primary);background:var(--btn-bg);}
.tab.active{color:var(--accent);border-bottom:2px solid var(--accent);margin-bottom:-1px;}
.tab-content{display:none;}
.tab-content.active{display:block;animation:fadeIn .3s;}
@keyframes fadeIn{from{opacity:0;}to{opacity:1;}}
.modal-content details{margin:12px 0;border:1px solid var(--border-color);border-radius:8px;padding:8px 12px;background:var(--btn-bg);}
.modal-content summary{cursor:pointer;font-weight:500;color:var(--text-primary);}
.modal-content summary:hover{color:var(--accent);}
.modal-close{float:right;background:none;border:none;color:var(--text-muted);font-size:1.5rem;cursor:pointer;line-height:1;}
.modal-close:hover{color:var(--text-primary);}
.modal .btn{background:var(--btn-bg);border:1px solid var(--border-color);color:var(--text-secondary);padding:7px 16px;border-radius:20px;cursor:pointer;font-size:.9rem;transition:.2s;margin:4px;}
.modal .btn:hover{background:var(--btn-hover);border-color:var(--accent);}
.modal .btn-primary{background:var(--accent);border-color:var(--accent);color:#fff;}
.modal .btn-primary:hover{background:var(--accent-hover);}
.modal .btn-danger{background:#da3633;border-color:#f85149;color:#fff;}
.modal .btn-danger:hover{background:#f85149;}
.modal textarea{width:100%;min-height:180px;background:var(--input-bg);border:1px solid var(--input-border);border-radius:8px;padding:10px;color:var(--text-primary);font-family:monospace;font-size:.8rem;resize:vertical;}
.modal textarea:focus{outline:none;border-color:var(--input-focus);}
.info-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border-color);font-size:.9rem;}
.info-row:last-child{border-bottom:none;}
.info-row .k{color:var(--text-muted);}
.info-row .v{color:var(--text-primary);font-weight:500;}
@media (max-width:600px){
    body{padding:12px;}
    .container{padding:16px;}
    header h1{font-size:1.6rem;}
    .server-name{font-size:1.2rem;}
    pre{font-size:.75rem;padding:10px;}
    .footer{font-size:.7rem;}
    .summary-bar{font-size:.8rem;gap:10px;}
}
</style>
</head>
<body>
<div class="container">
    <header>
        <div class="globe">🌍</div>
        <h1>AWG 2.0 <span>VPS Monitor</span></h1>
        <div class="subtitle">Мониторинг трафика конфигураций AWG 2.0 на VPS</div>
        <div class="schedule-info" id="scheduleInfo">Следующее обновление: загрузка...</div>
        <div class="summary-bar" id="summaryBar"></div>
    </header>

    <div class="toolbar">
        <input type="text" id="searchInput" placeholder="🔍 Поиск по имени сервера...">
        <select id="sortSelect">
            <option value="name">Сортировка: по имени</option>
            <option value="date_desc">Сортировка: сначала свежие</option>
            <option value="date_asc">Сортировка: сначала старые</option>
            <option value="status">Сортировка: сначала ошибки</option>
        </select>
    </div>

    <div id="statusMsg" class="status-msg"></div>
    <div id="content"></div>

    <div class="footer">
        <div class="footer-controls">
            <button class="btn-icon" id="configBtn">⚙️ Управление</button>
        </div>
        <div>&copy; 2026 <a href="https://github.com/romaca4/vpsmonitor-ui" target="_blank">romaca4/vpsmonitor-ui</a></div>
        <div class="version">AWG 2.0 VPS Monitor (WebUI) · версия 1.1</div>
    </div>
</div>

<div class="modal" id="scheduleModal">
    <div class="modal-content">
        <button class="modal-close" id="closeSchedule">&times;</button>
        <h2>📅 Расписание обновления</h2>
        <p id="scheduleDetail">Загрузка...</p>
        <button class="btn btn-primary" id="closeScheduleBtn" style="margin-top:15px;">Закрыть</button>
    </div>
</div>

<div class="modal" id="configModal">
    <div class="modal-content">
        <button class="modal-close" id="closeConfig">&times;</button>
        <h2>⚙️ Управление</h2>
        <div class="tabs">
            <div class="tab active" data-tab="tab-settings">Настройки</div>
            <div class="tab" data-tab="tab-help">Помощь</div>
            <div class="tab" data-tab="tab-about">О системе</div>
        </div>

        <div class="tab-content active" id="tab-settings">
            <p><strong>Тема оформления:</strong></p>
            <button class="btn" id="themeToggleModal">🌙 Сменить тему</button>

            <p style="margin-top:20px;"><strong>Ротация истории:</strong></p>
            <div class="info-row"><span class="k">Хранится файлов на сервер:</span><span class="v" id="rotationVal">—</span></div>

            <p style="margin-top:20px;"><strong>Занято в /tmp:</strong></p>
            <div class="info-row"><span class="k">Размер каталога статистики:</span><span class="v" id="dirSizeVal">—</span></div>

            <p style="margin-top:20px;"><strong>Очистка:</strong></p>
            <button class="btn btn-danger" id="cleanupBtn">🗑️ Очистить историю (все серверы)</button>

            <p style="margin-top:20px;"><strong>Резервное копирование конфига:</strong></p>
            <button class="btn" id="backupBtn">💾 Скачать конфиг</button>
            <button class="btn" id="restoreShowBtn">📥 Восстановить из копии</button>
            <div id="restoreArea" style="display:none;margin-top:10px;">
                <textarea id="restoreText" placeholder="Вставьте содержимое vpsmonitor.sh..."></textarea>
                <button class="btn btn-primary" id="restoreDoBtn">Восстановить</button>
                <button class="btn" id="restoreCancelBtn">Отмена</button>
            </div>

            <p style="margin-top:20px;"><strong>Правка конфигурации серверов:</strong></p>
            <div class="code-block" onclick="copyText(this)">/opt/etc/vpsmonitor-ui/vpsmonitor.sh</div>
            <p style="color:var(--text-muted);font-size:.85rem;">Откройте файл через SSH (<code>nano /opt/etc/vpsmonitor-ui/vpsmonitor.sh</code>), отредактируйте и перезапустите сервер.</p>
            <div class="code-block" onclick="copyText(this)">/opt/etc/init.d/S99vpsmonitor restart</div>
            <p style="color:var(--text-muted);font-size:.85rem;">Все пароли хранятся в открытом виде. Ограничьте доступ к SSH роутера.</p>
        </div>

        <div class="tab-content" id="tab-help">
            <details>
                <summary>🔍 Переименование сервера</summary>
                <p>Кликните по названию сервера (IP или домен) на главной странице, введите новое имя и нажмите Enter.</p>
            </details>
            <details>
                <summary>🔄 Автоматический сбор статистики</summary>
                <p>Статистика собирается автоматически по расписанию, выбранному при установке. Расписание отображается в шапке панели.</p>
                <p><strong>Файл cron:</strong> <code>/opt/etc/cron.d/vpsmonitor</code></p>
                <p>Для изменения отредактируйте файл вручную.</p>
            </details>
            <details>
                <summary>📜 История изменений</summary>
                <p>Под каждым сервером есть кнопка «📜 История» с количеством сохранённых снимков. Клик по снимку — просмотр содержимого.</p>
            </details>
            <details>
                <summary>🗑️ Очистка истории</summary>
                <p>В разделе «Настройки» есть кнопка «Очистить историю» — удаляет всё, кроме последнего снимка каждого сервера.</p>
                <p>Для очистки одного сервера — разверните карточку и нажмите «🗑️ Очистить» рядом с «История».</p>
            </details>
            <details>
                <summary>💾 Резервное копирование</summary>
                <p>Скачайте конфиг (<code>vpsmonitor.sh</code>) кнопкой «Скачать конфиг». Восстановление — через вставку содержимого обратно.</p>
                <p>После восстановления рекомендуется перезапустить сервер: <code>/opt/etc/init.d/S99vpsmonitor restart</code>.</p>
            </details>
            <details>
                <summary>🔒 Конфиденциальность</summary>
                <p>IP, домены и пароли хранятся только локально на роутере. Код открыт на <a href="https://github.com/romaca4/vpsmonitor-ui" target="_blank">GitHub</a>.</p>
            </details>
            <details>
                <summary>🗑️ Удаление панели</summary>
                <p>Для полного удаления используйте <code>uninstall.sh</code> из репозитория проекта.</p>
            </details>
        </div>

        <div class="tab-content" id="tab-about">
            <div class="info-row"><span class="k">Версия панели:</span><span class="v">1.1</span></div>
            <div class="info-row"><span class="k">Порт веб-интерфейса:</span><span class="v">__WEB_PORT__</span></div>
            <div class="info-row"><span class="k">Расписание сбора:</span><span class="v" id="aboutSchedule">—</span></div>
            <div class="info-row"><span class="k">Ротация файлов:</span><span class="v" id="aboutRotation">—</span></div>
            <div class="info-row"><span class="k">Обрезка вывода:</span><span class="v" id="aboutTrim">—</span></div>
            <p style="margin-top:20px;"><strong>Проект:</strong> <a href="https://github.com/romaca4/vpsmonitor-ui" target="_blank" style="color:var(--accent);">github.com/romaca4/vpsmonitor-ui</a></p>
            <p style="color:var(--text-muted);font-size:.85rem;margin-top:15px;">AWG 2.0 VPS Monitor – WebUI · Open Source · 2026</p>
        </div>

        <div style="text-align:right;margin-top:20px;">
            <button class="btn btn-primary" id="closeConfigBtn">Закрыть</button>
        </div>
    </div>
</div>

<script>
let currentTheme = localStorage.getItem('theme') || 'dark';
if (currentTheme === 'light') document.body.classList.add('light');
const themeBtn = document.getElementById('themeToggleModal');
themeBtn.textContent = currentTheme === 'light' ? '☀️ Светлая тема' : '🌙 Тёмная тема';
themeBtn.addEventListener('click', function() {
    document.body.classList.toggle('light');
    const isLight = document.body.classList.contains('light');
    localStorage.setItem('theme', isLight ? 'light' : 'dark');
    this.textContent = isLight ? '☀️ Светлая тема' : '🌙 Тёмная тема';
});

const scheduleModal = document.getElementById('scheduleModal');
const configModal = document.getElementById('configModal');

document.getElementById('scheduleInfo').addEventListener('click', async function() {
    try {
        const r = await fetch('/api/schedule');
        const d = await r.json();
        document.getElementById('scheduleDetail').textContent = 'Расписание: ' + d.description + ' (следующий запуск: ' + d.next_run + ')';
    } catch(e) {
        document.getElementById('scheduleDetail').textContent = 'Не удалось загрузить расписание';
    }
    scheduleModal.classList.add('show');
});
document.getElementById('closeSchedule').addEventListener('click', () => scheduleModal.classList.remove('show'));
document.getElementById('closeScheduleBtn').addEventListener('click', () => scheduleModal.classList.remove('show'));

document.getElementById('configBtn').addEventListener('click', async function() {
    try {
        const r = await fetch('/api/info');
        const d = await r.json();
        document.getElementById('rotationVal').textContent = d.rotation;
        document.getElementById('dirSizeVal').textContent = d.dir_size;
        document.getElementById('aboutSchedule').textContent = d.schedule;
        document.getElementById('aboutRotation').textContent = d.rotation;
        document.getElementById('aboutTrim').textContent = d.trim;
    } catch(e) {}
    configModal.classList.add('show');
});
document.getElementById('closeConfig').addEventListener('click', () => configModal.classList.remove('show'));
document.getElementById('closeConfigBtn').addEventListener('click', () => configModal.classList.remove('show'));

window.addEventListener('click', (e) => {
    if (e.target === scheduleModal) scheduleModal.classList.remove('show');
    if (e.target === configModal) configModal.classList.remove('show');
});

document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById(tab.dataset.tab).classList.add('active');
    });
});

function copyText(el) {
    const text = el.textContent.trim();
    navigator.clipboard.writeText(text).then(() => {
        const orig = el.style.borderColor;
        el.style.borderColor = '#3fb950';
        setTimeout(() => el.style.borderColor = orig, 500);
    }).catch(() => {});
}

document.getElementById('cleanupBtn').addEventListener('click', async () => {
    if (!confirm('Удалить все файлы статистики, кроме последнего для каждого сервера?')) return;
    try {
        const r = await fetch('/api/cleanup');
        const res = await r.json();
        if (res.status === 'ok') {
            showStatus('История очищена', 'success');
            const data = await fetchLatest();
            renderLatest(data);
        } else showStatus('Ошибка: ' + res.message, 'error');
    } catch(e) { showStatus('Ошибка сети', 'error'); }
});

document.getElementById('backupBtn').addEventListener('click', () => {
    window.location.href = '/api/backup';
});
document.getElementById('restoreShowBtn').addEventListener('click', () => {
    document.getElementById('restoreArea').style.display = 'block';
});
document.getElementById('restoreCancelBtn').addEventListener('click', () => {
    document.getElementById('restoreArea').style.display = 'none';
    document.getElementById('restoreText').value = '';
});
document.getElementById('restoreDoBtn').addEventListener('click', async () => {
    const content = document.getElementById('restoreText').value;
    if (!content.trim() || !confirm('Восстановить конфигурацию? Текущий файл будет перезаписан.')) return;
    try {
        const r = await fetch('/api/restore', {method:'POST', body: content});
        const res = await r.json();
        if (res.status === 'ok') {
            showStatus('Конфигурация восстановлена. Перезапустите сервер.', 'success');
            document.getElementById('restoreArea').style.display = 'none';
            document.getElementById('restoreText').value = '';
        } else showStatus('Ошибка: ' + res.message, 'error');
    } catch(e) { showStatus('Ошибка сети', 'error'); }
});

async function fetchLatest() { return (await fetch('/api/latest')).json(); }
async function fetchHistory() { return (await fetch('/api/history')).json(); }
async function fetchSchedule() { return (await fetch('/api/schedule')).json(); }
function showStatus(text, type='') {
    const el = document.getElementById('statusMsg');
    el.textContent = text;
    el.className = 'status-msg' + (type ? ' ' + type : '');
}

let allServers = [];
let currentSearch = '';
let currentSort = 'name';

function renderSummary(data) {
    const total = Object.keys(data).length;
    let ok = 0, err = 0;
    for (const v of Object.values(data)) {
        if (v.status === 'ok') ok++; else err++;
    }
    const bar = document.getElementById('summaryBar');
    bar.innerHTML = `<span class="item">Серверов: <b>${total}</b></span>` +
                    `<span class="item ok">Успешно: <b>${ok}</b></span>` +
                    `<span class="item fail">Ошибки: <b>${err}</b></span>`;
}

function renderServers() {
    const container = document.getElementById('content');
    let data = allServers;
    if (currentSearch) {
        const q = currentSearch.toLowerCase();
        data = data.filter(([d, info]) => (info.display_name || d).toLowerCase().includes(q) || d.toLowerCase().includes(q));
    }
    switch (currentSort) {
        case 'date_desc': data.sort((a,b) => (b[1].raw_ts||'').localeCompare(a[1].raw_ts||'')); break;
        case 'date_asc': data.sort((a,b) => (a[1].raw_ts||'').localeCompare(b[1].raw_ts||'')); break;
        case 'status': data.sort((a,b) => (a[1].status === 'error' ? -1 : 1) - (b[1].status === 'error' ? -1 : 1)); break;
        default: data.sort((a,b) => (a[1].display_name || a[0]).localeCompare(b[1].display_name || b[0]));
    }
    if (data.length === 0) {
        container.innerHTML = '<p style="text-align:center;color:var(--text-muted);padding:40px 0;">Ничего не найдено.</p>';
        return;
    }
    let html = '';
    for (const [domain, info] of data) {
        const displayName = info.display_name || domain;
        const ts = info.timestamp;
        const statusClass = info.status === 'ok' ? 'ok' : 'fail';
        const statusTitle = info.status === 'ok' ? 'Данные получены' : 'Ошибка сбора';
        const cnt = info.history_count || 0;
        html += `<div class="server-card" data-domain="${domain}">
            <div class="server-header">
                <span>
                    <span class="server-status ${statusClass}" title="${statusTitle}"></span>
                    <span class="server-name" onclick="editName('${domain}')" id="name_${domain}">${displayName}</span>
                </span>
            </div>
            <div class="server-meta">
                <span class="time">Обновлено: ${ts}</span>
            </div>
            <div class="server-content" id="content_${domain}">
                <pre>${info.content || '(пусто)'}</pre>
                <div style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap;">
                    <button class="action-btn history-toggle" onclick="toggleHistory('${domain}')">📜 История (${cnt})</button>
                    <button class="action-btn" onclick="cleanupServer('${domain}')" style="color:#f85149;border-color:#f85149;">🗑️ Очистить</button>
                </div>
                <div class="history-list" id="history_${domain}"></div>
            </div>
        </div>`;
    }
    container.innerHTML = html;
    for (const [domain] of data) {
        loadHistory(domain);
        const collapsed = localStorage.getItem('collapsed_' + domain) === 'true';
        if (collapsed) {
            const c = document.getElementById('content_' + domain);
            if (c) c.classList.add('collapsed');
        }
    }
}

function renderLatest(data) {
    if (!data || Object.keys(data).length === 0) {
        document.getElementById('content').innerHTML = '<p style="text-align:center;color:var(--text-muted);padding:40px 0;">Нет данных. Дождитесь первого сбора.</p>';
        document.getElementById('summaryBar').innerHTML = '';
        return;
    }
    allServers = Object.entries(data);
    renderSummary(data);
    renderServers();

    document.getElementById('content').addEventListener('click', function(e) {
        const card = e.target.closest('.server-card');
        if (!card) return;
        if (e.target.closest('.server-name')) return;
        if (e.target.closest('.history-toggle')) return;
        if (e.target.closest('.action-btn')) return;
        if (e.target.closest('.history-item') || e.target.closest('.history-content')) return;
        toggleCollapse(card.dataset.domain);
    }, { once: true });
}

async function loadHistory(domain) {
    const historyData = await fetchHistory();
    if (!historyData) return;
    const list = document.getElementById(`history_${domain}`);
    if (!list) return;
    const entries = historyData[domain] || [];
    if (entries.length === 0) { list.innerHTML = '<div style="color:var(--text-muted);padding:8px 16px;">История пуста</div>'; return; }
    let html = '';
    entries.forEach((item) => {
        const ts = item.timestamp;
        let display = ts;
        if (ts.length >= 14) {
            const year = ts.slice(0,4), month = ts.slice(4,6), day = ts.slice(6,8);
            const hour = ts.slice(9,11), min = ts.slice(11,13);
            display = day+'.'+month+'.'+year+' в '+hour+':'+min;
        }
        html += `<div class="history-item" onclick="showHistoryContent('${domain}', '${item.file}')">
            <span><span class="date">${display}</span> ${item.file}</span>
        </div>`;
        html += `<div class="history-content" id="content_${domain}_${item.file}"></div>`;
    });
    list.innerHTML = html;
}

function toggleHistory(domain) {
    const list = document.getElementById(`history_${domain}`);
    if (list) list.classList.toggle('show');
}

async function showHistoryContent(domain, filename) {
    const cd = document.getElementById(`content_${domain}_${filename}`);
    if (!cd) return;
    if (cd.innerHTML.trim() !== '') { cd.classList.toggle('show'); return; }
    try {
        const r = await fetch(`/api/file?file=${filename}`);
        const t = await r.text();
        cd.textContent = t || '(пусто)';
        cd.classList.add('show');
    } catch(e) { cd.textContent = 'Ошибка загрузки'; cd.classList.add('show'); }
}

function editName(domain) {
    const span = document.getElementById(`name_${domain}`);
    const currentName = span.textContent.trim();
    const input = document.createElement('input');
    input.type = 'text'; input.value = currentName;
    input.className = 'server-name-input'; input.maxLength = 40;
    span.replaceWith(input);
    input.focus(); input.select();
    const finish = async () => {
        const newName = input.value.trim();
        if (newName && newName !== currentName) {
            try {
                const r = await fetch('/api/setname', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({domain,name:newName})});
                const res = await r.json();
                if (res.status === 'ok') {
                    const ns = document.createElement('span');
                    ns.className = 'server-name';
                    ns.textContent = newName;
                    ns.setAttribute('onclick', `editName('${domain}')`);
                    ns.id = `name_${domain}`;
                    input.replaceWith(ns);
                    showStatus('Имя обновлено', 'success');
                    const d = await fetchLatest(); renderLatest(d);
                } else {
                    showStatus('Ошибка: ' + (res.message || ''), 'error');
                    const os = document.createElement('span');
                    os.className = 'server-name';
                    os.textContent = currentName;
                    os.setAttribute('onclick', `editName('${domain}')`);
                    os.id = `name_${domain}`;
                    input.replaceWith(os);
                }
            } catch(e) {
                showStatus('Ошибка сети', 'error');
                const os = document.createElement('span');
                os.className = 'server-name';
                os.textContent = currentName;
                os.setAttribute('onclick', `editName('${domain}')`);
                os.id = `name_${domain}`;
                input.replaceWith(os);
            }
        } else {
            const os = document.createElement('span');
            os.className = 'server-name';
            os.textContent = currentName || domain;
            os.setAttribute('onclick', `editName('${domain}')`);
            os.id = `name_${domain}`;
            input.replaceWith(os);
        }
    };
    input.addEventListener('blur', finish);
    input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') input.blur();
        else if (e.key === 'Escape') {
            const os = document.createElement('span');
            os.className = 'server-name';
            os.textContent = currentName || domain;
            os.setAttribute('onclick', `editName('${domain}')`);
            os.id = `name_${domain}`;
            input.replaceWith(os);
        }
    });
}

function toggleCollapse(domain) {
    const c = document.getElementById('content_' + domain);
    if (!c) return;
    const isCollapsed = c.classList.toggle('collapsed');
    localStorage.setItem('collapsed_' + domain, isCollapsed ? 'true' : 'false');
}

async function cleanupServer(domain) {
    if (!confirm(`Удалить все файлы статистики для сервера ${domain}, кроме последнего?`)) return;
    try {
        const r = await fetch(`/api/cleanup_server?domain=${encodeURIComponent(domain)}`);
        const res = await r.json();
        if (res.status === 'ok') {
            showStatus(`История для ${domain} очищена`, 'success');
            const d = await fetchLatest(); renderLatest(d);
        } else showStatus('Ошибка: ' + res.message, 'error');
    } catch(e) { showStatus('Ошибка сети', 'error'); }
}

document.getElementById('searchInput').addEventListener('input', (e) => {
    currentSearch = e.target.value;
    renderServers();
});
document.getElementById('sortSelect').addEventListener('change', (e) => {
    currentSort = e.target.value;
    renderServers();
});

(async function init() {
    try {
        const s = await fetchSchedule();
        document.getElementById('scheduleInfo').textContent = 'Следующее обновление: ' + s.next_run;
    } catch(e) {
        document.getElementById('scheduleInfo').textContent = 'Следующее обновление: —';
    }
    const data = await fetchLatest();
    renderLatest(data);
    setInterval(async () => {
        const nd = await fetchLatest();
        renderLatest(nd);
    }, 3600000);
})();
</script>
</body>
</html>'''

if __name__ == '__main__':
    os.makedirs(STATS_DIR, exist_ok=True)
    server = http.server.HTTPServer(('0.0.0.0', PORT), StatsHandler)
    print(f'AWG 2.0 VPS Monitor – WebUI running on port {PORT}')
    server.serve_forever()
PYEOF

sed -i "s/__WEB_PORT__/$WEB_PORT/g" /opt/etc/vpsmonitor-ui/vpsmonitor.py
chmod +x /opt/etc/vpsmonitor-ui/vpsmonitor.py
dos2unix /opt/etc/vpsmonitor-ui/vpsmonitor.py

# ================= INIT-СКРИПТ =================

cat > /opt/etc/init.d/S99vpsmonitor << 'EOF'
#!/bin/sh
NOHUP=$(command -v nohup)
[ -z "$NOHUP" ] && [ -x /opt/bin/nohup ] && NOHUP=/opt/bin/nohup
[ -z "$NOHUP" ] && [ -x /usr/bin/nohup ] && NOHUP=/usr/bin/nohup
SH=$(command -v sh)
[ -z "$SH" ] && SH=/opt/bin/sh

start() {
    PID=$(ps | grep -v grep | grep vpsmonitor.py | awk '{print $1}')
    [ -n "$PID" ] && kill $PID 2>/dev/null && sleep 1
    if [ -n "$NOHUP" ]; then
        $NOHUP $SH -c "/opt/bin/python3 /opt/etc/vpsmonitor-ui/vpsmonitor.py" < /dev/null > /dev/null 2>&1 &
    else
        $SH -c "/opt/bin/python3 /opt/etc/vpsmonitor-ui/vpsmonitor.py < /dev/null > /dev/null 2>&1 &" &
    fi
    sleep 2
    if ps | grep -v grep | grep vpsmonitor.py > /dev/null; then
        echo "Server started"
    else
        echo "Server failed to start"
    fi
}
stop() {
    PID=$(ps | grep -v grep | grep vpsmonitor.py | awk '{print $1}')
    if [ -n "$PID" ]; then kill $PID; echo "Server stopped"; else echo "Server not running"; fi
}
case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    status) if ps | grep -v grep | grep vpsmonitor.py > /dev/null; then echo "Server is running"; else echo "Server is not running"; fi ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
EOF

chmod +x /opt/etc/init.d/S99vpsmonitor
dos2unix /opt/etc/init.d/S99vpsmonitor

RC_LOCAL="/opt/etc/init.d/rc.local"
if [ -f "$RC_LOCAL" ]; then
    grep -q "S99vpsmonitor" "$RC_LOCAL" || echo "/opt/etc/init.d/S99vpsmonitor start" >> "$RC_LOCAL"
else
    echo "#!/bin/sh" > "$RC_LOCAL"
    echo "/opt/etc/init.d/S99vpsmonitor start" >> "$RC_LOCAL"
    chmod +x "$RC_LOCAL"
fi

# ================= CRON =================

echo -e "${YELLOW}Настройка cron...${NC}"
/opt/etc/init.d/S10cron start 2>/dev/null || true
(crontab -l 2>/dev/null | grep -v vpsmonitor.sh | crontab -) 2>/dev/null || true
rm -f /opt/etc/cron.d/vpsmonitor
mkdir -p /opt/etc/cron.d

> /opt/etc/cron.d/vpsmonitor
echo "$CRON_LINES" | while read -r line; do
    [ -n "$line" ] && echo "$line root /opt/bin/sh /opt/etc/vpsmonitor-ui/vpsmonitor.sh >> /tmp/vpsmonitor_cron.log 2>&1" >> /opt/etc/cron.d/vpsmonitor
done
echo "" >> /opt/etc/cron.d/vpsmonitor
chmod 600 /opt/etc/cron.d/vpsmonitor

kill $(ps | grep cron | grep -v grep | awk '{print $1}') 2>/dev/null || true
sleep 1
/opt/etc/init.d/S10cron start

# ================= ЗАПУСК =================

echo -e "${YELLOW}Запуск веб-сервера...${NC}"
/opt/etc/init.d/S99vpsmonitor stop 2>/dev/null || true
/opt/etc/init.d/S99vpsmonitor start

echo -e "${YELLOW}Запуск первичного сбора статистики...${NC}"
/opt/etc/vpsmonitor-ui/vpsmonitor.sh > /dev/null 2>&1 &

echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║          Установка завершена!  ✓              ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Откройте панель в браузере:${NC}"
echo -e "   ${BOLD}http://192.168.1.1:$WEB_PORT/${NC}"
echo ""
echo -e "${CYAN}Настройки, выбранные при установке:${NC}"
echo "   Расписание:   $SCHEDULE_DESC"
echo "   Ротация:      $ROTATION_DESC"
echo "   Обрезка:      $TRIM_DESC"
echo ""
echo -e "${CYAN}Полезные команды:${NC}"
echo "   Статус:       /opt/etc/init.d/S99vpsmonitor status"
echo "   Остановка:    /opt/etc/init.d/S99vpsmonitor stop"
echo "   Запуск:       /opt/etc/init.d/S99vpsmonitor start"
echo "   Перезапуск:   /opt/etc/init.d/S99vpsmonitor restart"
echo ""
echo -e "${CYAN}Для управления серверами:${NC}"
echo "   Откройте: /opt/etc/vpsmonitor-ui/vpsmonitor.sh"
echo "   После правок: /opt/etc/init.d/S99vpsmonitor restart"
echo ""
echo -e "${YELLOW}⚠  Пароли SSH хранятся в открытом виде.${NC}"
echo -e "${YELLOW}   Рекомендуется: chmod 600 /opt/etc/vpsmonitor-ui/vpsmonitor.sh${NC}"
echo ""

exit 0
