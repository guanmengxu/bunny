#!/bin/bash

if ! command -v bc >/dev/null 2>&1; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
    else
        echo "无法识别系统类型，请手动安装 bc"
        exit 1
    fi

    case "$OS_ID" in
        ubuntu|debian)
            apt-get update
            apt-get install -y bc
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y bc || dnf install -y bc
            ;;
        *)
            echo "不支持的系统: $OS_ID，请手动安装 bc"
            exit 1
            ;;
    esac
fi

sysctl --quiet --write net.ipv4.conf.all.arp_announce=1
sysctl --quiet --write net.ipv4.conf.default.arp_announce=1

sed -i '/^net\.ipv4\.conf\.all\.arp_announce/d' /etc/sysctl.conf
echo "net.ipv4.conf.all.arp_announce = 1" >> /etc/sysctl.conf
sed -i '/^net\.ipv4\.conf\.default\.arp_announce/d' /etc/sysctl.conf
echo "net.ipv4.conf.default.arp_announce = 1" >> /etc/sysctl.conf

sysctl -p > /dev/null 2>&1

CONFIG_FILE="/etc/gre_tunnel_config"

echo "PREFIXES=(" > $CONFIG_FILE
while true; do
    read -p "请输入分配的网段 (或输入'done'来结束): " PREFIX
    if [ "$PREFIX" = "done" ]; then
        break
    fi
    echo "\"$PREFIX\"" >> $CONFIG_FILE
done
echo ")" >> $CONFIG_FILE

mapfile -t local_ips < <(hostname -I | tr ' ' '\n' | grep '^172\.17\.')
ip=${local_ips[0]}
NEW_GATEWAY=$(echo "$ip" | awk -F. '{print $1"."$2"."$3".254"}')
read -p "Enter pulic source IP address: " NEW_SRC

if [ -n "$NEW_GATEWAY" ]; then
    echo "NEW_GATEWAY=$NEW_GATEWAY" >> "$CONFIG_FILE"
fi
if [ -n "$NEW_SRC" ]; then
    echo "NEW_SRC=$NEW_SRC" >> "$CONFIG_FILE"
fi


cat << 'EOF3' > 2e.sh
#!/bin/bash

CONFIG_FILE="/etc/gre_tunnel_config"
SERVICE_PATH="/etc/systemd/system/gre-configuration.service"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration file not found! Please create /etc/gre_tunnel_config first."
    exit 1
fi

source "$CONFIG_FILE"

default_interface=$(ip route | grep default | awk 'NR==1 {print $5}')


for PREFIX in "${PREFIXES[@]}"; do
    IFS='.' read -r -a ADDR <<< "$(echo "$PREFIX" | cut -d'/' -f1)"
    MASK=$(echo "$PREFIX" | cut -d'/' -f2)
    for i in $(seq 0 $(echo "2^(32-$MASK)-1" | bc)); do
        IP=$(echo "${ADDR[0]}.${ADDR[1]}.$((ADDR[2] + i / 256)).$((ADDR[3] + i % 256))")
        ip address add "$IP"/32 dev "$default_interface"
    done
done

if [ -n "$NEW_GATEWAY" ] || [ -n "$NEW_SRC" ]; then
    if [ -z "$NEW_GATEWAY" ]; then
        NEW_GATEWAY="$gateway_ip"
    fi
    if [ -n "$NEW_SRC" ]; then
        ip route replace default via "$NEW_GATEWAY" src "$NEW_SRC"
    else
        ip route replace default via "$NEW_GATEWAY"
    fi
fi

if [[ ! -f "$SERVICE_PATH" ]]; then
    cat > "$SERVICE_PATH" <<EOL
[Unit]
Description=Configure GRE Tunnel and IPs
After=network.target

[Service]
Type=oneshot
ExecStart=/root/2e.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL
    systemctl daemon-reload
    systemctl enable gre-configuration
fi

EOF3

chmod +x 2e.sh

DROP_IN_DIR="/etc/systemd/system/cloud-final.service.d"
if [ ! -d "$DROP_IN_DIR" ]; then
    mkdir -p "$DROP_IN_DIR"
else
    echo "Directory already exists: $DROP_IN_DIR"
fi

DROP_IN_FILE="$DROP_IN_DIR/override.conf"

exec_start_post=""

if [ -f /root/2e.sh ]; then
    chmod +x /root/2e.sh
    exec_start_post+="ExecStartPost=/root/2e.sh"$'\n'
else
    echo "/root/2e.sh not found, please check path or create the script."
fi

if [ -f /root/2.sh ]; then
    chmod +x /root/2.sh > /dev/null 2>&1
    exec_start_post+="ExecStartPost=/root/2.sh"$'\n'
else
    echo "/root/2.sh not found, please check path or create the script."
fi

cat <<EOL > "$DROP_IN_FILE"
[Service]
$exec_start_post
EOL

systemctl daemon-reload

bash 2e.sh