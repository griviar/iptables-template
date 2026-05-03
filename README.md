# IPtables Framework

Фреймворк для управления правилами IPtables и IPset на нескольких серверах.
Шаблоны хранятся в Git, серверная конфигурация — локально.

---

## Структура проекта

```
.
├── build.sh                    ← главный скрипт сборки
├── .tag.example                ← пример файла тегов
│
├── templates/
│   ├── general/                ← всегда включается (базовые правила)
│   │   ├── 10-vars.sh
│   │   ├── 20-ipset-init.sh
│   │   ├── 30-flush.sh
│   │   ├── 40-policy.sh
│   │   ├── 50-loopback.sh
│   │   ├── 60-icmp.sh
│   │   ├── 70-conntrack.sh
│   │   ├── 80-security.sh
│   │   └── 90-ssh.sh
│   ├── web/                    ← тег: web
│   ├── mail/                   ← тег: mail
│   ├── sip/                    ← тег: sip
│   ├── h323/                   ← тег: h323
│   ├── dns/                    ← тег: dns
│   ├── docker/                 ← тег: docker
│   ├── gateway/                ← тег: gateway
│   └── logging/                ← тег: logging
│
└── user/                       ← серверная специфика (в .gitignore)
    ├── .env                    ← переменные: WAN, WAN_IP, PORT_SSH, и т.д.
    ├── ipset-populate.sh       ← добавление IP-адресов в IPset
    └── custom.sh               ← произвольные правила для этого сервера
```

---

## Быстрый старт на новом сервере

```bash
# 1. Клонировать репозиторий
git clone git@gitlab.example.com:you/iptables-framework.git /opt/iptables
cd /opt/iptables

# 2. Создать файл тегов
cp .tag.example .tag
# Отредактировать .tag — оставить только нужные теги

# 3. Создать пользовательские файлы
mkdir -p user
cp user/.env.example           user/.env
cp user/ipset-populate.sh.example user/ipset-populate.sh
cp user/custom.sh.example      user/custom.sh
# Отредактировать все три файла под этот сервер

# 4. Собрать скрипт
bash build.sh

# 5. Применить правила
sudo bash iptables.sh
```

---

## Файл `.tag`

Один тег на строку. Строки начинающиеся с `#` — комментарии.

```
# web-server with Docker
web
docker
```

### Доступные теги

| Тег       | Открывает                                    | Доп. переменные в user/.env     |
|-----------|----------------------------------------------|---------------------------------|
| `web`     | TCP 80, 443                                  | —                               |
| `mail`    | TCP 25, 110, 143, 465, 993, 995              | —                               |
| `sip`     | UDP/TCP 5060, UDP 10000-15000 (RTP)          | —                               |
| `h323`    | TCP 1720                                     | —                               |
| `dns`     | UDP/TCP 53                                   | —                               |
| `gateway` | LAN→WAN forward + MASQUERADE                 | `LAN1`, `LAN1_IP_RANGE`         |
| `logging` | логирует все дропнутые пакеты                | — *(указывать последним)*       |

---

## Файл `user/.env`

Переменные, специфичные для конкретного сервера:

```bash
export WAN=eth0
export WAN_IP=100.100.100.100
export PORT_SSH=22
export PORT_APP=46284

# Для тега gateway:
# export LAN1=eth1
# export LAN1_IP_RANGE=10.1.3.0/24
```

---

## Файл `user/ipset-populate.sh`

Наполняет IPset-листы конкретными IP-адресами:

```bash
$IPS add $SSH_SET 1.2.3.4 -exist   # разрешить SSH с этого IP
$IPS add $APP_SET 1.2.3.4 -exist   # разрешить доступ к приложению
```

---

## Файл `user/custom.sh`

Произвольные правила, добавляемые после всех шаблонных:

```bash
# Заблокировать IP
$IPT -A INPUT -s 84.122.21.197 -j REJECT

# Открыть нестандартный порт
$IPT -A INPUT -p tcp --dport 8080 -j ACCEPT
```

---

## Порядок сборки `iptables.sh`

```
10-vars.sh          ← константы (IPT, IPS, имена set-ов)
user/.env           ← серверные переменные (WAN, порты, …)
20-ipset-init.sh    ← создать/очистить IPset-ы
user/ipset-populate.sh  ← заполнить IPset-ы IP-адресами
30-flush.sh … 90-ssh.sh ← базовые правила
templates/<tag>/*.sh    ← правила тегов (в порядке .tag)
user/custom.sh          ← индивидуальные правила сервера
```

---

## Добавление нового тега

1. Создать директорию `templates/<newtag>/`
2. Добавить один или несколько файлов `NN-name.sh` (числовой префикс задаёт порядок)
3. Добавить описание тега в эту таблицу
4. На нужных серверах добавить тег в `.tag` и перегенерировать

Пример — тег `vpn` для OpenVPN:
```bash
mkdir templates/vpn
cat > templates/vpn/10-openvpn.sh << 'EOF'
# OpenVPN
$IPT -A INPUT -p udp --dport 1194 -j ACCEPT
$IPT -A FORWARD -i tun+ -j ACCEPT
$IPT -A FORWARD -o tun+ -j ACCEPT
$IPT -t nat -A POSTROUTING -s 10.8.0.0/24 -o $WAN -j MASQUERADE
EOF
```
