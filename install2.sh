#!/bin/sh
# VPSMonitor Installer for Keenetic Entware
# GitHub: https://github.com/romaca4/vpsmonitor-ui

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}=== VPSMonitor Installer ===${NC}"
echo "AWG 2.0 VPS Monitor – WebUI"
echo "Мониторинг трафика конфигураций AWG 2.0 на VPS"

if [ ! -d /opt ]; then
    echo -e "${RED}Ошибка: /opt не найден. Убедитесь, что Entware установлен.${NC}"
    exit 1
fi

echo -e "${YELLOW}Проверка зависимостей...${NC}"
MISSING=""
for pkg in python3 expect cron dos2unix; do
    if ! opkg list-installed | grep -q "^$pkg"; then
        MISSING="$MISSING $pkg"
    fi
done

if [ -n "$MISSING" ]; then
    echo -e "${YELLOW}Будут установлены следующие пакеты:$MISSING${NC}"
    read -p "Продолжить? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        opkg update
        opkg install $MISSING
    else
        echo "Установка отменена."
        exit 1
    fi
fi

echo -e "${GREEN}Настройка веб-интерфейса${NC}"
read -p "Порт веб-интерфейса (по умолчанию 2000): " WEB_PORT
WEB_PORT=${WEB_PORT:-2000}

input_servers() {
    echo -e "${GREEN}Настройка SSH-подключений к серверам WireGuard${NC}"
    echo "ВНИМАНИЕ: необходимо указать реальный IP-адрес или домен каждого сервера."
    echo "Рекомендуется использовать домен вместо IP."
    read -p "SSH порт (по умолчанию 22, но для безопасности лучше использовать нестандартный, например 2222): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    echo "Совет: используйте порт отличный от 22, например 2222, для повышения безопасности."
    read -p "SSH пользователь (по умолчанию root): " SSH_USER
    SSH_USER=${SSH_USER:-root}

    read -p "Количество серверов WireGuard: " SERVER_COUNT
    while ! [[ "$SERVER_COUNT" =~ ^[1-9][0-9]*$ ]]; do
        echo "Введите положительное число."
        read -p "Количество серверов: " SERVER_COUNT
    done

    for i in $(seq 1 $SERVER_COUNT); do
        echo "--- Сервер $i ---"
        read -p "Домен или IP (желательно домен): " domain
        while [ -z "$domain" ]; do
            echo "Адрес не может быть пустым!"
            read -p "Домен или IP: " domain
        done
        echo "При вводе пароля символы не отображаются — это нормально."
        read -sp "Пароль SSH: " pass
        echo
        eval "SERVER$i=\"$domain\""
        eval "PASS$i=\"$pass\""
    done
}

input_frequency() {
    echo -e "${GREEN}Настройка частоты сбора статистики${NC}"
    echo "Выберите вариант (по умолчанию 2):"
    echo "1 — 1 раз в сутки (в 03:00)"
    echo "2 — 2 раза в сутки (в 06:00 и 18:00)"
    echo "3 — 3 раза в сутки (в 00:00, 08:00, 16:00)"
    echo "4 — 4 раза в сутки (в 00:00, 06:00, 12:00, 18:00)"
    echo "5 — 1 раз в неделю (в воскресенье в 03:00)"
    echo "6 — 3 раза в неделю (пн, ср, пт в 03:00)"
    read -p "Введите номер (1–6, по умолчанию 2): " FREQ
    FREQ=${FREQ:-2}
    while ! [[ "$FREQ" =~ ^[1-6]$ ]]; do
        echo "Ошибка: введите число от 1 до 6."
        read -p "Введите номер (1–6): " FREQ
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
    esac
}

input_servers
input_frequency

mkdir -p /opt/etc/vpsmonitor-ui

# Генерация скрипта сбора
generate_collect_script() {
    cat > /opt/etc/vpsmonitor-ui/vpsmonitor.sh << EOF
#!/bin/sh
STATS_DIR="/tmp/vpsmonitor_stats"
mkdir -p "\$STATS_DIR"

SSH_PORT="$SSH_PORT"
SSH_USER="$SSH_USER"
SERVER_COUNT=$SERVER_COUNT

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
    else
        echo "FAIL: $server (пустой вывод)"
        rm -f "$outfile"
    fi
}

for i in $(seq 1 $SERVER_COUNT); do
    eval "server=\"\$SERVER$i\""
    eval "pass=\"\$PASS$i\""
    collect "$server" "$pass"
done

for i in $(seq 1 $SERVER_COUNT); do
    eval "server=\"\$SERVER$i\""
    ls -t "$STATS_DIR"/stats_${server}_*.txt 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null
done
EOF

    chmod +x /opt/etc/vpsmonitor-ui/vpsmonitor.sh
    dos2unix /opt/etc/vpsmonitor-ui/vpsmonitor.sh
}

generate_collect_script

# Генерация веб-сервера (Python)
cat > /opt/etc/vpsmonitor-ui/vpsmonitor.py << 'EOF'
#!/opt/bin/python3
import http.server
import os
import glob
import urllib.parse
import json
from datetime import datetime

STATS_DIR = '/tmp/vpsmonitor_stats'
PORT = __WEB_PORT__
NAMES_FILE = '/opt/etc/vpsmonitor-ui/server_names.json'

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
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path == '/api/setname':
            self.set_name()
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
            lines = content.splitlines()
            if len(lines) > 8:
                lines = lines[8:]
                if lines:
                    lines = lines[:-1]
                content = '\n'.join(lines)
            else:
                content = ''
            try:
                dt = datetime.strptime(latest_ts, '%Y%m%d_%H%M%S')
                formatted = dt.strftime('%d.%m.%Y в %H:%M')
            except:
                formatted = latest_ts
            display_name = names.get(domain, domain)
            result[domain] = {
                'display_name': display_name,
                'timestamp': formatted,
                'content': content,
                'raw_ts': latest_ts
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
        lines = content.splitlines()
        if len(lines) > 8:
            lines = lines[8:]
            if lines:
                lines = lines[:-1]
            content = '\n'.join(lines)
        else:
            content = ''
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
        /* ---- CSS (полный, как в эталонной версии) ---- */
        :root {
            --bg-body: #0d1117;
            --bg-container: rgba(22, 27, 34, 0.85);
            --border-color: #30363d;
            --text-primary: #f0f6fc;
            --text-secondary: #c9d1d9;
            --text-muted: #8b949e;
            --card-bg: #161b22;
            --card-border: #30363d;
            --card-shadow: 0 6px 20px rgba(0,0,0,0.5);
            --pre-bg: #0d1117;
            --pre-border: #21262d;
            --accent: #58a6ff;
            --accent-hover: #79c0ff;
            --footer-border: #21262d;
            --btn-bg: #21262d;
            --btn-hover: #30363d;
            --input-bg: #0d1117;
            --input-border: #30363d;
            --input-focus: #58a6ff;
            --globe-filter: none;
        }
        body.light {
            --bg-body: #f6f8fa;
            --bg-container: rgba(255, 255, 255, 0.9);
            --border-color: #d0d7de;
            --text-primary: #1f2328;
            --text-secondary: #24292f;
            --text-muted: #57606a;
            --card-bg: #ffffff;
            --card-border: #d0d7de;
            --card-shadow: 0 6px 20px rgba(0,0,0,0.08);
            --pre-bg: #f6f8fa;
            --pre-border: #d0d7de;
            --accent: #0969da;
            --accent-hover: #0550ae;
            --footer-border: #d0d7de;
            --btn-bg: #f6f8fa;
            --btn-hover: #eaeef2;
            --input-bg: #ffffff;
            --input-border: #d0d7de;
            --input-focus: #0969da;
            --globe-filter: none;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: var(--bg-body);
            color: var(--text-secondary);
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Oxygen, Ubuntu, sans-serif;
            padding: 20px;
            display: flex;
            justify-content: center;
            min-height: 100vh;
            transition: background 0.3s, color 0.3s;
            margin: 0;
        }
        .container {
            max-width: 1200px;
            width: 100%;
            background: var(--bg-container);
            backdrop-filter: blur(8px);
            border-radius: 24px;
            padding: 30px 30px 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
            border: 1px solid var(--border-color);
            transition: background 0.3s, border-color 0.3s;
        }
        header {
            text-align: center;
            padding: 10px 0 15px 0;
            border-bottom: 2px solid var(--border-color);
            margin-bottom: 20px;
            transition: border-color 0.3s;
        }
        header .globe {
            font-size: 3.2rem;
            display: block;
            margin-bottom: 4px;
            animation: pulse 2s infinite;
            filter: var(--globe-filter);
        }
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.1); }
            100% { transform: scale(1); }
        }
        header h1 {
            font-size: 2.4rem;
            font-weight: 300;
            letter-spacing: 2px;
            color: var(--text-primary);
            text-shadow: 0 2px 10px rgba(88,166,255,0.1);
            transition: color 0.3s;
        }
        header h1 span {
            color: var(--accent);
            font-weight: 600;
        }
        .subtitle {
            font-size: 0.95rem;
            color: var(--text-muted);
            margin-top: 4px;
            letter-spacing: 1px;
        }
        .server-card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            padding: 20px;
            margin-bottom: 24px;
            transition: background 0.3s, border-color 0.3s, box-shadow 0.3s, transform 0.25s ease;
            box-shadow: var(--card-shadow);
            cursor: pointer;
        }
        .server-card:hover {
            border-color: var(--accent);
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(88,166,255,0.12);
        }
        .server-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            margin-bottom: 6px;
        }
        .server-status {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
            vertical-align: middle;
        }
        .server-status.ok { background: #3fb950; }
        .server-status.fail { background: #f85149; }
        .server-status.unknown { background: #8b949e; }
        .server-name {
            font-size: 1.5rem;
            font-weight: 500;
            color: var(--text-primary);
            cursor: pointer;
            padding: 4px 10px;
            border-radius: 6px;
            transition: 0.2s;
            display: inline-block;
            background: var(--pre-bg);
            border: 1px solid transparent;
            pointer-events: auto;
        }
        .server-name:hover {
            background: var(--btn-bg);
            border-color: var(--border-color);
        }
        .server-name-input {
            font-size: 1.5rem;
            background: var(--input-bg);
            border: 1px solid var(--input-focus);
            color: var(--text-primary);
            padding: 4px 10px;
            border-radius: 6px;
            outline: none;
            font-weight: 500;
            width: auto;
            min-width: 180px;
            transition: background 0.3s, border-color 0.3s, color 0.3s;
        }
        .server-meta {
            color: var(--text-muted);
            font-size: 0.9rem;
            margin-top: 6px;
            display: flex;
            flex-wrap: wrap;
            justify-content: flex-end;
            align-items: center;
        }
        .server-meta .time { color: var(--text-muted); }
        .action-btn {
            background: none;
            border: 1px solid var(--border-color);
            color: var(--text-muted);
            cursor: pointer;
            font-size: 0.8rem;
            padding: 2px 10px;
            border-radius: 12px;
            transition: 0.2s;
            background: var(--btn-bg);
        }
        .action-btn:hover {
            background: var(--btn-hover);
            color: var(--text-primary);
        }
        pre {
            background: var(--pre-bg);
            border: 1px solid var(--pre-border);
            border-radius: 10px;
            padding: 14px;
            font-size: 0.85rem;
            overflow-x: auto;
            white-space: pre-wrap;
            word-break: break-word;
            margin: 14px 0 10px 0;
            font-family: 'JetBrains Mono', 'Fira Code', monospace;
            color: var(--text-secondary);
            line-height: 1.5;
            transition: background 0.3s, border-color 0.3s, color 0.3s;
        }
        .server-content {
            transition: max-height 0.3s ease, opacity 0.3s;
            overflow: hidden;
        }
        .server-content.collapsed {
            max-height: 0 !important;
            opacity: 0;
            padding: 0 !important;
            margin: 0 !important;
        }
        .server-content.collapsed pre,
        .server-content.collapsed .history-list {
            pointer-events: none;
        }
        .history-list {
            display: none;
            margin-top: 12px;
            background: var(--pre-bg);
            border-radius: 10px;
            border: 1px solid var(--pre-border);
            padding: 6px 0;
        }
        .history-list.show { display: block; }
        .history-item {
            padding: 8px 16px;
            border-bottom: 1px solid var(--pre-border);
            cursor: pointer;
            font-size: 0.9rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: 0.15s;
            color: var(--text-secondary);
        }
        .history-item:last-child { border-bottom: none; }
        .history-item:hover { background: var(--btn-bg); }
        .history-item .date { color: var(--text-muted); margin-right: 12px; }
        .history-content {
            display: none;
            margin: 8px 16px 16px 16px;
            background: var(--pre-bg);
            border-left: 3px solid var(--accent);
            padding: 10px 16px;
            border-radius: 6px;
            font-size: 0.8rem;
            white-space: pre-wrap;
            word-break: break-word;
            color: var(--text-secondary);
        }
        .history-content.show { display: block; }
        .footer {
            margin-top: 40px;
            text-align: center;
            color: var(--text-muted);
            font-size: 0.8rem;
            border-top: 1px solid var(--footer-border);
            padding-top: 18px;
            transition: border-color 0.3s, color 0.3s;
        }
        .footer .footer-controls {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-bottom: 10px;
        }
        .footer .footer-controls .btn-icon {
            background: none;
            border: 1px solid var(--border-color);
            border-radius: 30px;
            padding: 3px 10px;
            cursor: pointer;
            font-size: 0.8rem;
            color: var(--text-secondary);
            transition: 0.2s;
            background: var(--btn-bg);
            line-height: 1.4;
        }
        .footer .footer-controls .btn-icon:hover {
            background: var(--btn-hover);
            border-color: var(--accent);
        }
        .footer .footer-controls .theme-toggle-icon {
            font-size: 1rem;
            padding: 2px 8px;
        }
        .footer a { color: var(--accent); text-decoration: none; transition: 0.2s; }
        .footer a:hover { text-decoration: underline; color: var(--accent-hover); }
        .footer .version { margin-top: 6px; font-size: 0.75rem; color: var(--text-muted); }
        .status-msg {
            text-align: center;
            margin: 10px 0;
            color: var(--text-muted);
            font-size: 0.9rem;
            min-height: 1.5em;
        }
        .status-msg.error { color: #f85149; }
        .status-msg.success { color: #3fb950; }

        /* Модальные окна */
        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0; top: 0;
            width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            justify-content: center;
            align-items: center;
        }
        .modal.show { display: flex; }
        .modal-content {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 25px;
            max-width: 700px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
            color: var(--text-secondary);
        }
        .modal-content h2 { color: var(--text-primary); margin-bottom: 15px; }
        .modal-content p { margin: 10px 0; line-height: 1.6; }
        .modal-content code {
            background: var(--pre-bg);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: monospace;
            color: var(--accent);
        }
        .modal-content .code-block {
            background: var(--pre-bg);
            padding: 10px 14px;
            border-radius: 6px;
            border: 1px solid var(--pre-border);
            font-family: monospace;
            font-size: 0.9rem;
            white-space: pre-wrap;
            word-break: break-word;
            cursor: pointer;
            transition: 0.2s;
            margin: 8px 0;
        }
        .modal-content .code-block:hover {
            border-color: var(--accent);
        }
        .modal-content details {
            margin: 12px 0;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 8px 12px;
            background: var(--btn-bg);
        }
        .modal-content summary {
            cursor: pointer;
            font-weight: 500;
            color: var(--text-primary);
        }
        .modal-content summary:hover { color: var(--accent); }
        .modal-close {
            float: right;
            background: none;
            border: none;
            color: var(--text-muted);
            font-size: 1.5rem;
            cursor: pointer;
        }
        .modal-close:hover { color: var(--text-primary); }
        .modal .btn {
            background: var(--btn-bg);
            border: 1px solid var(--border-color);
            color: var(--text-secondary);
            padding: 6px 14px;
            border-radius: 20px;
            cursor: pointer;
            transition: 0.2s;
            font-size: 0.9rem;
        }
        .modal .btn:hover {
            background: var(--btn-hover);
            border-color: var(--accent);
        }
        .modal .btn-primary {
            background: var(--accent);
            border-color: var(--accent);
            color: #fff;
        }
        .modal .btn-primary:hover {
            background: var(--accent-hover);
        }
        @media (max-width: 600px) {
            body { padding: 12px; }
            .container { padding: 16px; }
            header h1 { font-size: 1.6rem; }
            .server-name { font-size: 1.2rem; }
            .server-name-input { font-size: 1.2rem; min-width: 120px; }
            pre { font-size: 0.75rem; padding: 10px; }
            .footer { font-size: 0.7rem; }
            .footer .footer-controls { flex-wrap: wrap; }
        }
    </style>
</head>
<body>
<div class="container">
    <header>
        <div class="globe">🌍</div>
        <h1>AWG 2.0 <span>VPS Monitor</span></h1>
        <div class="subtitle">Мониторинг трафика конфигураций AWG 2.0 на VPS</div>
    </header>

    <div id="statusMsg" class="status-msg"></div>
    <div id="content"></div>

    <div class="footer">
        <div class="footer-controls">
            <button class="btn-icon" id="helpBtn">📖 Помощь</button>
            <button class="btn-icon" id="configBtn">⚙️ Управление</button>
            <button class="btn-icon theme-toggle-icon" id="themeToggle">🌙</button>
        </div>
        <div>&copy; 2026 <a href="https://github.com/romaca4/vpsmonitor-ui" target="_blank">romaca4/vpsmonitor-ui</a></div>
        <div class="version">AWG 2.0 VPS Monitor (WebUI) · версия 1.0.0</div>
    </div>
</div>

<!-- Модальные окна -->
<div class="modal" id="helpModal">
    <div class="modal-content">
        <button class="modal-close" id="closeHelp">&times;</button>
        <h2>📖 Помощь</h2>
        <details>
            <summary>🔍 Переименование сервера</summary>
            <p>Кликните по названию сервера (IP или домен) на главной странице, введите новое имя и нажмите Enter.</p>
        </details>
        <details>
            <summary>🔄 Автоматический сбор статистики</summary>
            <p>Статистика собирается автоматически по расписанию, которое вы выбрали при установке.</p>
        </details>
        <details>
            <summary>📜 История изменений</summary>
            <p>Под каждым сервером есть кнопка <strong>«📜 История»</strong> — нажмите, чтобы увидеть все сохранённые файлы статистики. Клик по файлу покажет его содержимое.</p>
        </details>
        <details>
            <summary>🔒 Конфиденциальность</summary>
            <p>Ваши IP-адреса, домены и пароли <strong>не передаются никуда</strong> и хранятся исключительно локально на вашем роутере. Исходный код проекта открыт, вы можете изучить его на <a href="https://github.com/romaca4/vpsmonitor-ui" target="_blank">GitHub</a>.</p>
        </details>
        <button class="btn btn-primary" id="closeHelpBtn" style="margin-top:15px;">Закрыть</button>
    </div>
</div>

<div class="modal" id="configModal">
    <div class="modal-content">
        <button class="modal-close" id="closeConfig">&times;</button>
        <h2>⚙️ Управление серверами</h2>
        <p><strong>Добавление, изменение или удаление сервера</strong> производится через редактирование файла конфигурации на роутере:</p>
        <div class="code-block" onclick="copyText(this)">/opt/etc/vpsmonitor-ui/vpsmonitor.sh</div>
        <p>Откройте файл через SSH (например, <code>nano /opt/etc/vpsmonitor-ui/vpsmonitor.sh</code>) и измените строки <code>SERVER1=...</code>, <code>PASS1=...</code> и т.д. После редактирования сохраните файл.</p>
        <p><strong>Применение изменений:</strong></p>
        <div class="code-block" onclick="copyText(this)">/opt/etc/init.d/S99vpsmonitor stop</div>
        <div class="code-block" onclick="copyText(this)">/opt/etc/init.d/S99vpsmonitor start</div>
        <p><strong>Или просто перезагрузите роутер.</strong></p>
        <p><strong>Ручной запуск сбора статистики</strong> (вне расписания):</p>
        <div class="code-block" onclick="copyText(this)">/opt/etc/vpsmonitor-ui/vpsmonitor.sh</div>
        <p><strong>Остановка веб-сервера:</strong></p>
        <div class="code-block" onclick="copyText(this)">/opt/etc/init.d/S99vpsmonitor stop</div>
        <p><strong>Запуск веб-сервера:</strong></p>
        <div class="code-block" onclick="copyText(this)">/opt/etc/init.d/S99vpsmonitor start</div>
        <p style="margin-top:15px; color:var(--text-muted);">Все пароли хранятся в открытом виде. Ограничьте доступ к SSH роутера.</p>
        <button class="btn btn-primary" id="closeConfigBtn" style="margin-top:15px;">Закрыть</button>
    </div>
</div>

<script>
    // ---- Тема ----
    const themeToggle = document.getElementById('themeToggle');
    const currentTheme = localStorage.getItem('theme') || 'dark';
    if (currentTheme === 'light') {
        document.body.classList.add('light');
        themeToggle.textContent = '☀️';
    }
    themeToggle.addEventListener('click', () => {
        document.body.classList.toggle('light');
        const isLight = document.body.classList.contains('light');
        localStorage.setItem('theme', isLight ? 'light' : 'dark');
        themeToggle.textContent = isLight ? '☀️' : '🌙';
    });

    // ---- Модальные окна ----
    const helpModal = document.getElementById('helpModal');
    const configModal = document.getElementById('configModal');
    document.getElementById('helpBtn').addEventListener('click', () => helpModal.classList.add('show'));
    document.getElementById('closeHelp').addEventListener('click', () => helpModal.classList.remove('show'));
    document.getElementById('closeHelpBtn').addEventListener('click', () => helpModal.classList.remove('show'));
    document.getElementById('configBtn').addEventListener('click', () => configModal.classList.add('show'));
    document.getElementById('closeConfig').addEventListener('click', () => configModal.classList.remove('show'));
    document.getElementById('closeConfigBtn').addEventListener('click', () => configModal.classList.remove('show'));
    window.addEventListener('click', (e) => {
        if (e.target === helpModal) helpModal.classList.remove('show');
        if (e.target === configModal) configModal.classList.remove('show');
    });

    // ---- Копирование ----
    function copyText(el) {
        const text = el.textContent.trim();
        navigator.clipboard.writeText(text).then(() => {
            const orig = el.style.borderColor;
            el.style.borderColor = '#3fb950';
            setTimeout(() => el.style.borderColor = orig, 500);
        }).catch(() => {});
    }

    // ---- Основные функции ----
    async function fetchLatest() { const resp = await fetch('/api/latest'); return resp.json(); }
    async function fetchHistory() { const resp = await fetch('/api/history'); return resp.json(); }
    function showStatus(text, type='') { const el = document.getElementById('statusMsg'); el.textContent = text; el.className = 'status-msg' + (type ? ' ' + type : ''); }

    function renderLatest(data) {
        const container = document.getElementById('content');
        if (!data || Object.keys(data).length === 0) {
            container.innerHTML = '<p style="text-align:center; color:var(--text-muted); padding:40px 0;">Нет данных. Дождитесь первого сбора.</p>';
            return;
        }
        let html = '';
        for (const [domain, info] of Object.entries(data)) {
            const displayName = info.display_name || domain;
            const ts = info.timestamp;
            const statusClass = info.content && info.content.length > 0 ? 'ok' : 'fail';
            const statusTitle = info.content && info.content.length > 0 ? 'Данные получены' : 'Нет данных';
            html += `<div class="server-card" data-domain="${domain}">
                <div class="server-header">
                    <span>
                        <span class="server-status ${statusClass}" title="${statusTitle}"></span>
                        <span class="server-name" onclick="editName('${domain}')" id="name_${domain}">${displayName}</span>
                    </span>
                </div>
                <div class="server-meta"><span class="time">Обновлено: ${ts}</span></div>
                <div class="server-content" id="content_${domain}">
                    <pre>${info.content || '(пусто)'}</pre>
                    <div style="margin-top:8px;">
                        <button class="action-btn history-toggle" onclick="toggleHistory('${domain}')">📜 История</button>
                    </div>
                    <div class="history-list" id="history_${domain}"></div>
                </div>
            </div>`;
        }
        container.innerHTML = html;
        for (const domain of Object.keys(data)) {
            loadHistory(domain);
            const collapsed = localStorage.getItem('collapsed_' + domain) === 'true';
            if (collapsed) {
                const content = document.getElementById('content_' + domain);
                if (content) {
                    content.classList.add('collapsed');
                }
            }
        }
        container.addEventListener('click', function(e) {
            const card = e.target.closest('.server-card');
            if (!card) return;
            if (e.target.closest('.server-name')) return;
            if (e.target.closest('.history-toggle')) return;
            if (e.target.closest('.history-item') || e.target.closest('.history-content')) return;
            const domain = card.dataset.domain;
            toggleCollapse(domain);
        });
    }

    async function loadHistory(domain) {
        const historyData = await fetchHistory();
        if (!historyData) return;
        const list = document.getElementById(`history_${domain}`);
        if (!list) return;
        const entries = historyData[domain] || [];
        if (entries.length === 0) { list.innerHTML = '<div style="color:var(--text-muted); padding:8px 16px;">История пуста</div>'; return; }
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
        const contentDiv = document.getElementById(`content_${domain}_${filename}`);
        if (!contentDiv) return;
        if (contentDiv.innerHTML.trim() !== '') {
            contentDiv.classList.toggle('show');
            return;
        }
        try {
            const resp = await fetch(`/api/file?file=${filename}`);
            const text = await resp.text();
            contentDiv.textContent = text || '(пусто)';
            contentDiv.classList.add('show');
        } catch (e) {
            contentDiv.textContent = 'Ошибка загрузки';
            contentDiv.classList.add('show');
        }
    }

    function editName(domain) {
        const span = document.getElementById(`name_${domain}`);
        const currentName = span.textContent.trim();
        const input = document.createElement('input');
        input.type = 'text';
        input.value = currentName;
        input.className = 'server-name-input';
        input.maxLength = 40;
        span.replaceWith(input);
        input.focus();
        input.select();
        const finish = async () => {
            const newName = input.value.trim();
            if (newName && newName !== currentName) {
                try {
                    const resp = await fetch('/api/setname', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ domain, name: newName }) });
                    const result = await resp.json();
                    if (result.status === 'ok') {
                        const newSpan = document.createElement('span');
                        newSpan.className = 'server-name';
                        newSpan.textContent = newName;
                        newSpan.setAttribute('onclick', `editName('${domain}')`);
                        newSpan.id = `name_${domain}`;
                        input.replaceWith(newSpan);
                        showStatus('Имя обновлено', 'success');
                    } else {
                        showStatus('Ошибка: ' + (result.message || ''), 'error');
                        const oldSpan = document.createElement('span');
                        oldSpan.className = 'server-name';
                        oldSpan.textContent = currentName;
                        oldSpan.setAttribute('onclick', `editName('${domain}')`);
                        oldSpan.id = `name_${domain}`;
                        input.replaceWith(oldSpan);
                    }
                } catch (e) {
                    showStatus('Ошибка сети', 'error');
                    const oldSpan = document.createElement('span');
                    oldSpan.className = 'server-name';
                    oldSpan.textContent = currentName;
                    oldSpan.setAttribute('onclick', `editName('${domain}')`);
                    oldSpan.id = `name_${domain}`;
                    input.replaceWith(oldSpan);
                }
            } else {
                const oldSpan = document.createElement('span');
                oldSpan.className = 'server-name';
                oldSpan.textContent = currentName || domain;
                oldSpan.setAttribute('onclick', `editName('${domain}')`);
                oldSpan.id = `name_${domain}`;
                input.replaceWith(oldSpan);
            }
        };
        input.addEventListener('blur', finish);
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') input.blur();
            else if (e.key === 'Escape') {
                const oldSpan = document.createElement('span');
                oldSpan.className = 'server-name';
                oldSpan.textContent = currentName || domain;
                oldSpan.setAttribute('onclick', `editName('${domain}')`);
                oldSpan.id = `name_${domain}`;
                input.replaceWith(oldSpan);
            }
        });
    }

    function toggleCollapse(domain) {
        const content = document.getElementById('content_' + domain);
        if (!content) return;
        const isCollapsed = content.classList.toggle('collapsed');
        localStorage.setItem('collapsed_' + domain, isCollapsed ? 'true' : 'false');
    }

    // ---- Инициализация ----
    (async function init() {
        const data = await fetchLatest();
        renderLatest(data);
        setInterval(async () => {
            const newData = await fetchLatest();
            renderLatest(newData);
        }, 1800000); // 30 минут
    })();
</script>
</body>
</html>'''

if __name__ == '__main__':
    os.makedirs(STATS_DIR, exist_ok=True)
    server = http.server.HTTPServer(('0.0.0.0', PORT), StatsHandler)
    print(f'AWG 2.0 VPS Monitor – WebUI running on port {PORT}')
    server.serve_forever()
EOF

# Подставляем порт
sed -i "s/__WEB_PORT__/$WEB_PORT/g" /opt/etc/vpsmonitor-ui/vpsmonitor.py
chmod +x /opt/etc/vpsmonitor-ui/vpsmonitor.py
dos2unix /opt/etc/vpsmonitor-ui/vpsmonitor.py

# ---- Init-скрипт (финальный, рабочий) ----
cat > /opt/etc/init.d/S99vpsmonitor << 'EOF'
#!/bin/sh

# Определяем пути к nohup и sh
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
    if [ -n "$PID" ]; then
        kill $PID
        echo "Server stopped"
    else
        echo "Server not running"
    fi
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    status)
        if ps | grep -v grep | grep vpsmonitor.py > /dev/null; then
            echo "Server is running"
        else
            echo "Server is not running"
        fi
        ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
EOF

chmod +x /opt/etc/init.d/S99vpsmonitor
dos2unix /opt/etc/init.d/S99vpsmonitor

# Автозапуск через rc.local
RC_LOCAL="/opt/etc/init.d/rc.local"
if [ -f "$RC_LOCAL" ]; then
    if ! grep -q "S99vpsmonitor" "$RC_LOCAL"; then
        echo "/opt/etc/init.d/S99vpsmonitor start" >> "$RC_LOCAL"
    fi
else
    echo "#!/bin/sh" > "$RC_LOCAL"
    echo "/opt/etc/init.d/S99vpsmonitor start" >> "$RC_LOCAL"
    chmod +x "$RC_LOCAL"
fi

# Настройка cron
echo -e "${GREEN}Настройка cron...${NC}"
(crontab -l 2>/dev/null | grep -v vpsmonitor.sh | crontab -) 2>/dev/null || true
echo "$CRON_LINES" | while read -r line; do
    [ -n "$line" ] && (crontab -l 2>/dev/null; echo "$line /opt/etc/vpsmonitor-ui/vpsmonitor.sh") | crontab -
done

# Запуск веб-сервера
echo -e "${GREEN}Запуск веб-сервера...${NC}"
/opt/etc/init.d/S99vpsmonitor stop 2>/dev/null || true
/opt/etc/init.d/S99vpsmonitor start

# Запуск первичного сбора
echo -e "${YELLOW}Запуск первичного сбора статистики в фоне...${NC}"
/opt/etc/vpsmonitor-ui/vpsmonitor.sh > /dev/null 2>&1 &

echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo "Веб-интерфейс доступен по адресу вашего роутера (например, 10.10.10.1 или 192.168.1.1) на порту $WEB_PORT"
echo "Пример: http://10.10.10.1:$WEB_PORT/ или http://192.168.1.1:$WEB_PORT/"
echo ""
echo -e "${YELLOW}Для управления серверами отредактируйте файл:${NC}"
echo "  /opt/etc/vpsmonitor-ui/vpsmonitor.sh"
echo "После изменений перезапустите веб-сервер:"
echo "  /opt/etc/init.d/S99vpsmonitor stop"
echo "  /opt/etc/init.d/S99vpsmonitor start"
echo ""
echo "Остановка: /opt/etc/init.d/S99vpsmonitor stop"
echo "Запуск: /opt/etc/init.d/S99vpsmonitor start"
echo "Статус: /opt/etc/init.d/S99vpsmonitor status"
echo ""
echo -e "${YELLOW}Пароли SSH хранятся в открытом виде в /opt/etc/vpsmonitor-ui/vpsmonitor.sh${NC}"
echo "Рекомендуется: chmod 600 /opt/etc/vpsmonitor-ui/vpsmonitor.sh"
echo ""

exit 0
