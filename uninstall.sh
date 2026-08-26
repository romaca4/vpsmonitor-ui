#!/bin/sh
# VPSMonitor Uninstaller
# GitHub: https://github.com/romaca4/vpsmonitor-ui

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}=== VPSMonitor Uninstaller ===${NC}"
echo "Удаление AWG 2.0 VPS Monitor – WebUI"
echo ""
echo -e "${YELLOW}ВНИМАНИЕ: Это действие полностью удалит веб-панель и все её файлы.${NC}"
echo "Данные статистики, пароли и настройки будут удалены."
echo ""
read -p "Вы уверены, что хотите продолжить? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Удаление отменено."
    exit 0
fi

# 1. Остановка веб-сервера
echo -e "${YELLOW}Остановка веб-сервера...${NC}"
/opt/etc/init.d/S99vpsmonitor stop 2>/dev/null || true

# 2. Удаление init-скрипта
echo -e "${YELLOW}Удаление init-скрипта...${NC}"
rm -f /opt/etc/init.d/S99vpsmonitor
rm -f /opt/etc/rc.d/S99vpsmonitor 2>/dev/null || true

# 3. Удаление скриптов и конфигов
echo -e "${YELLOW}Удаление скриптов и конфигураций...${NC}"
rm -rf /opt/etc/vpsmonitor-ui

# 4. Удаление временных файлов статистики
echo -e "${YELLOW}Удаление временных данных...${NC}"
rm -rf /tmp/vpsmonitor_stats

# 5. Удаление cron-заданий (системный файл и пользовательские)
echo -e "${YELLOW}Удаление cron-заданий...${NC}"
# Удаляем файл из системного каталога
rm -f /opt/etc/cron.d/vpsmonitor
# Удаляем старые пользовательские задания (на случай, если остались)
(crontab -l 2>/dev/null | grep -v vpsmonitor.sh | crontab -) 2>/dev/null || true

# 6. Удаление строки автозапуска из rc.local
echo -e "${YELLOW}Очистка автозапуска...${NC}"
RC_LOCAL="/opt/etc/init.d/rc.local"
if [ -f "$RC_LOCAL" ]; then
    sed -i '/S99vpsmonitor/d' "$RC_LOCAL"
    if [ ! -s "$RC_LOCAL" ]; then
        rm -f "$RC_LOCAL"
    fi
fi

# 7. Итог
echo -e "${GREEN}=== Удаление завершено! ===${NC}"
echo "Все компоненты VPSMonitor удалены."
echo ""
echo "Пакеты python3, expect, cron, dos2unix не были удалены."
echo "Если они вам не нужны, удалите их вручную: opkg remove python3 expect cron dos2unix"
