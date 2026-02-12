#!/bin/bash

NEW_USER="alex"
SSH_PORT=22

if [ "$EUID" -ne 0 ]; then
    echo "[✖] Please run as root."
    exit 1
fi

echo "[*] Updating system..."
apt update && apt upgrade -y


if id "$NEW_USER" &>/dev/null; then
    echo "[i] User '$NEW_USER' already exists. Skipping creation."
else
    echo "[*] Creating non-root user: $NEW_USER..."
    adduser --gecos "" $NEW_USER
    usermod -aG sudo $NEW_USER
fi


SSH_DIR="/home/$NEW_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

if [ -f "$AUTH_KEYS" ]; then
    echo "[i] SSH key already exists for $NEW_USER. Skipping key setup."
else
    echo "[*] Configuring SSH key authentication..."
    mkdir -p $SSH_DIR
    chmod 700 $SSH_DIR
    echo "Paste your public key here, then press Ctrl+D:"
    cat >> $AUTH_KEYS
    chmod 600 $AUTH_KEYS
    chown -R $NEW_USER:$NEW_USER $SSH_DIR
fi

# Disable root login and password authentication
sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/^#PubkeyAuthentication no/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/^PubkeyAuthentication no/PubkeyAuthentication yes/" /etc/ssh/sshd_config

systemctl restart ssh


echo "[*] Configuring firewall..."
apt install ufw -y
ufw allow OpenSSH
ufw enable
ufw status


echo "[*] Installing Fail2Ban..."
apt install fail2ban -y
systemctl enable fail2ban


echo "[*] Configuring automatic updates..."
apt install unattended-upgrades -y
dpkg-reconfigure --priority=low unattended-upgrades


echo "[*] Setting timezone to Europe/London..."
timedatectl set-timezone Europe/London


echo "[*] Installing essential packages..."
apt install git curl wget htop vim unzip -y

echo "[*] Installing docker..."
if command -v docker &>/dev/null; then
    echo "[i] Docker already installed."
else
  apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)
  
  # Add Docker's official GPG key:
  apt update
  apt install ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  
  # Add the repository to Apt sources:
  tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt update
  apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  usermod -aG docker $NEW_USER
  systemctl status docker
  systemctl start docker
  systemctl enable docker
fi

if grep -q "Security hardening" /etc/sysctl.conf; then
    echo "[i] Kernel hardening already applied."
else
    echo "[*] Applying kernel hardening..."
    tee /etc/sysctl.conf <<EOF

# Security hardening
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
EOF

    sysctl -p
fi
apt update

echo "[*] Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --accept-dns=false

echo "[*] Creating SSH Key..."
ssh-keygen -t ed25519 -C "alex@$(hostname).avali.systems"
echo "[*] Displaying SSH Key..."
echo "=========================================="
cat /home/$NEW_USER/.ssh/id_ed25519.pub
echo "=========================================="



echo "=================================="
echo "[✔] VPS initial setup completed!"
echo "[✔] Login as: ssh $NEW_USER@$(hostname -I | awk '{print $1}')"
echo "=================================="
