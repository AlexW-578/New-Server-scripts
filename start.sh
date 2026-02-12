#!/bin/bash

NEW_USER="alex"
SSH_PORT=22


echo "[*] Updating system..."
apt update && apt upgrade -y


echo "[*] Creating non-root user: $NEW_USER..."
adduser --gecos "" $NEW_USER
usermod -aG sudo $NEW_USER


echo "[*] Configuring SSH key authentication..."
mkdir -p /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
echo "Paste your public key here, then press Ctrl+D:"
cat >> /home/$NEW_USER/.ssh/authorized_keys
chmod 600 /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh

# Disable root login and password authentication
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl restart ssh


echo "[*] Configuring firewall..."
apt install ufw -y
ufw allow OpenSSH
ufw --force enable
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


echo "[*] Applying kernel hardening..."
cat <<EOF >> /etc/sysctl.conf

# Security hardening
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
EOF
sysctl -p


echo "=================================="
echo "[✔] VPS initial setup completed!"
echo "[✔] Login as: ssh $NEW_USER@$(hostname -I | awk '{print $1}')"
echo "=================================="
