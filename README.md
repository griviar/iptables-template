# IPtables Framework

Фреймворк для управления правилами IPtables и IPset на нескольких серверах.
Шаблоны хранятся в Git, серверная конфигурация — локально на каждом сервере.

---

## Структура проекта

```
.
├── build.sh                     ← собирает iptables.sh из шаблонов
├── detect-wan.sh                ← определяет WAN-интерфейс и записывает в user/.env
├── save.sh                      ← сохраняет правила для автозагрузки при перезапуске
├── .tag.example                 ← пример файла тегов
│
├── templates/
│   ├── general/                 ← всегда включается (базовые правила)
│   │   ├── 10-vars.sh           ← алиасы IPT/IPS, имена IPset-ов
│   │   ├── 30-flush.sh
│   │   ├── 40-policy.sh
│   │   ├── 50-loopback.sh
│   │   ├── 60-icmp.sh
│   │   ├── 70-conntrack.sh
│   │   ├── 80-security.sh
│   │   └── 90-ssh.sh            ← SSH открыт на 22 для всех; APP_SET по вайтлисту
│   ├── web/                     ← тег: web
│   ├── mail/                    ← тег: mail
│   ├── sip/                     ← тег: sip
│   ├── h323/                    ← тег: h323
│   ├── dns/                     ← тег: dns
│   ├── gateway/                 ← тег: gateway
│   └── logging/                 ← тег: logging  (указывать последним)
│
└── user/                        ← серверная специфика (в .gitignore)
    ├── .env                     ← WAN, WAN_IP, PORT_APP, и т.д.
    ├── ipsets/                  ← по одному файлу на каждый IPset
    │   ├── app-list             ← IP-адреса для APP_SET
    │   └── ssh-list             ← IP-адреса для SSH вайтлиста (если нужен)
    └── custom.sh                ← произвольные правила для этого сервера
```

---

## Быстрый старт на новом сервере

```bash
# 1. Клонировать репозиторий
git clone git@gitlab.example.com:you/iptables-framework.git /opt/iptables
cd /opt/iptables

# 2. Определить WAN-интерфейс
bash detect-wan.sh
# Скрипт найдёт интерфейсы, предложит выбрать и запишет WAN/WAN_IP в user/.env

# 3. Дополнить user/.env нужными переменными (PORT_APP и т.д.)
# Смотри user/.env.example

# 4. Создать IPset-файлы
mkdir -p user/ipsets
# Скопировать примеры и заполнить своими IP-адресами:
cp user/ipsets/app-list.example user/ipsets/app-list

# 5. При необходимости настроить user/custom.sh
cp user/custom.sh.example user/custom.sh

# 6. Указать роли сервера
cp .tag.example .tag
# Отредактировать .tag — оставить только нужные теги

# 7. Собрать и применить
bash build.sh
sudo bash iptables.sh

# 8. Сохранить правила для автозагрузки (требует iptables-persistent, ipset-persistent)
sudo bash save.sh
```

---

## Файл `.tag`

Один тег на строку. Строки начинающиеся с `#` — комментарии.

```
# Почтовый сервер
mail
logging
```

### Доступные теги

| Тег       | Открывает                               | Доп. переменные в user/.env |
|-----------|-----------------------------------------|-----------------------------|
| `web`     | TCP 80, 443                             | —                           |
| `mail`    | TCP 25, 110, 143, 465, 993, 995         | —                           |
| `sip`     | UDP/TCP 5060, UDP 10000–15000 (RTP)     | —                           |
| `h323`    | TCP 1720                                | —                           |
| `dns`     | UDP/TCP 53                              | —                           |
| `gateway` | LAN→WAN FORWARD + MASQUERADE            | `LAN1`, `LAN1_IP_RANGE`     |
| `logging` | логирует все дропнутые пакеты           | — *(указывать последним)*   |

---

## Файл `user/.env`

Переменные, специфичные для конкретного сервера. `detect-wan.sh` заполняет WAN и WAN_IP автоматически.

```bash
export WAN=eth0
export WAN_IP=1.2.3.4
export PORT_APP=46284

# Для тега gateway:
# export LAN1=eth1
# export LAN1_IP_RANGE=10.1.3.0/24

# Для SSH-вайтлиста (см. user/custom.sh.example):
# export PORT_SSH=2222
```

---

## Папка `user/ipsets/`

Каждый файл в этой папке — один IPSet. Имя файла = имя сета. Тип `hash:net` поддерживает одиночные IP и подсети.

```
# Комментарий — сохраняется в сгенерированном скрипте
1.2.3.4             # одиночный IP
10.0.0.0/24         # подсеть
5.6.7.8 # офис      # инлайн-комментарий обрезается, IP берётся
```

Имя сета в `10-vars.sh` (`APP_SET=app-list`) должно совпадать с именем файла в `user/ipsets/`.

---

## SSH-доступ

По умолчанию (`templates/general/90-ssh.sh`) — порт 22 открыт для всех.

Чтобы ограничить SSH вайтлистом на нестандартном порту — см. инструкцию в `user/custom.sh.example` (4 шага).

---

## Файл `user/custom.sh`

Произвольные правила, добавляемые после всех шаблонных. Все переменные из `user/.env` доступны.

```bash
# Открыть дополнительный порт
$IPT -A INPUT -p tcp --dport $PORT_PANEL -j ACCEPT

# Заблокировать IP
$IPT -A INPUT -s 84.122.21.197 -j REJECT
```

---

## Порядок сборки `iptables.sh`

```
templates/general/10-vars.sh      ← константы
user/.env                         ← серверные переменные
user/ipsets/*                     ← создание и наполнение IPset-ов
templates/general/30-90-*.sh      ← базовые правила
templates/<tag>/*.sh              ← правила тегов (в порядке .tag)
user/custom.sh                    ← индивидуальные правила сервера
```

---

## Добавление нового тега

1. Создать директорию `templates/<newtag>/`
2. Добавить один или несколько файлов `NN-name.sh` (числовой префикс задаёт порядок внутри тега)
3. Сниппеты — чистый bash без shebang; используют переменные `$IPT`, `$IPS`, `$WAN` и т.д.

Пример — тег `vpn` для OpenVPN:
```bash
mkdir templates/vpn
cat > templates/vpn/10-openvpn.sh << 'EOF'
$IPT -A INPUT -p udp --dport 1194 -j ACCEPT
$IPT -A FORWARD -i tun+ -j ACCEPT
$IPT -A FORWARD -o tun+ -j ACCEPT
$IPT -t nat -A POSTROUTING -s 10.8.0.0/24 -o $WAN -j MASQUERADE
EOF
```
