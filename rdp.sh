#!/bin/bash
# ============================================
# 🚀 Auto Installer: Windows 10 Pro on Docker + Cloudflare Tunnel
# ============================================

set -e

echo "=== 🔧 Menjalankan sebagai root ==="
if [ "$EUID" -ne 0 ]; then
  echo "Script ini butuh akses root. Jalankan dengan: sudo bash install-windows10-cloudflare.sh"
  exit 1
fi

echo
echo "=== 📦 Update & Install Docker Compose ==="
apt update -y
apt install docker-compose -y

systemctl enable docker
systemctl start docker

echo
echo "=== 📂 Membuat direktori kerja dockercom ==="
mkdir -p /root/dockercom
cd /root/dockercom

echo
echo "=== 🧾 Membuat file windows.yml (Windows 10 Pro) ==="
cat > windows.yml <<'EOF'
version: "3.9"
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      # Mengatur VM ke Windows 10
      VERSION: "10" 
      USERNAME: "MASTER"
      PASSWORD: "admin@123"
      RAM_SIZE: "7G"
      CPU_CORES: "4"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006" # Port NoVNC (Web Console)
      - "3389:3389/tcp" # Port RDP TCP
      - "3389:3389/udp" # Port RDP UDP
    volumes:
      - /tmp/windows-storage:/storage # Direktori penyimpanan VM
    restart: always
    stop_grace_period: 2m

EOF

echo
echo "=== ✅ File windows.yml berhasil dibuat ==="
cat windows.yml

echo
echo "=== 🚀 Menjalankan Windows 10 container (Tunggu beberapa menit untuk instalasi OS) ==="
docker-compose -f windows.yml up -d

echo
echo "=== ☁️ Instalasi Cloudflare Tunnel ==="
if [ ! -f "/usr/local/bin/cloudflared" ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo
echo "=== 🌍 Membuat tunnel publik untuk akses web & RDP ==="
# Tunnel untuk Web Console (NoVNC)
nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
# Tunnel untuk RDP
nohup cloudflared tunnel --url tcp://localhost:3389 > /var/log/cloudflared_rdp.log 2>&1 &
sleep 6 # Memberi waktu agar Cloudflared menghasilkan URL

CF_WEB=$(grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" /var/log/cloudflared_web.log | head -n 1)
CF_RDP=$(grep -o "tcp://[a-zA-Z0-9.-]*\.trycloudflare\.com:[0-9]*" /var/log/cloudflared_rdp.log | head -n 1)

echo
echo "=============================================="
echo "🎉 INSTALASI DASAR WINDOWS 10 SELESAI!"
echo "=============================================="
echo

if [ -n "$CF_WEB" ]; then
  echo "🌍 Web Console (NoVNC / UI):"
  echo "    ${CF_WEB}"
else
  echo "⚠️ Tidak menemukan link web Cloudflare (port 8006)"
  echo "    Cek log: tail -f /var/log/cloudflared_web.log"
fi

if [ -n "$CF_RDP" ]; then
  echo
  echo "🖥️  Remote Desktop (RDP) melalui Cloudflare:"
  echo "    ${CF_RDP}"
else
  echo "⚠️ Tidak menemukan link RDP Cloudflare (port 3389)"
  echo "    Cek log: tail -f /var/log/cloudflared_rdp.log"
fi

echo
echo "🔑 Username Default: MASTER"
echo "🔒 Password Default: admin@123"
echo
echo "--- 💡 LANGKAH INSTALASI ROBLOX STUDIO: ---"
echo "1. Tunggu 5-10 menit hingga Windows 10 selesai booting."
echo "2. Akses VM menggunakan link **Web Console (NoVNC)** di atas."
echo "3. Setelah masuk, buka browser di dalam VM."
echo "4. Unduh dan instal **Roblox Studio** dari situs resmi."
echo "-------------------------------------------"
echo
echo "Untuk melihat status container:"
echo "  docker ps"
echo
echo "Untuk melihat log Windows (proses booting):"
echo "  docker logs -f windows"
echo
echo "=== ✅ Windows 10 di Docker siap digunakan! ==="
echo "=============================================="
