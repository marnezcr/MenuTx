#!/data/data/com.termux/files/usr/bin/bash
set -e

DEST="$HOME/.jwf-menu"
REPO_URL="https://raw.githubusercontent.com/marnezcr/MenuTx/main/menu.sh"

# Buat direktori tujuan
mkdir -p "$DEST" "$PREFIX/bin"

# Unduh menu.sh langsung dari GitHub
curl -fsSL "$REPO_URL" -o "$DEST/menu.sh"
chmod +x "$DEST/menu.sh"

# Cek dan unduh adb.sh jika tidak ditemukan
if [ -f "$DEST/adb.sh" ]; then
  echo "File adb.sh sudah ada, memberikan izin eksekusi..."
  chmod +x "$DEST/adb.sh"
else
  echo "File adb.sh tidak ditemukan, mengunduh dari repositori..."
  curl -fsSL "https://raw.githubusercontent.com/marnezcr/MenuTx/adb.sh" -o "$DEST/adb.sh"
  chmod +x "$DEST/adb.sh"
fi

# Cek dan unduh ram.sh jika tidak ditemukan
if [ -f "$DEST/ram.sh" ]; then
  echo "File ram.sh sudah ada, memberikan izin eksekusi..."
  chmod +x "$DEST/ram.sh"
else
  echo "File ram.sh tidak ditemukan, mengunduh dari repositori..."
  curl -fsSL "https://raw.githubusercontent.com/marnezcr/MenuTx/ram.sh" -o "$DEST/ram.sh"
  chmod +x "$DEST/ram.sh"
fi

# Backup bashrc
if [ -f "$HOME/.bashrc" ]; then
  cp -f "$HOME/.bashrc" "$HOME/.bashrc.bak.jwf"
fi

# Tambahkan autoload ke .bashrc kalau belum ada
LINE='[ -f "$HOME/.jwf-menu/menu.sh" ] && . "$HOME/.jwf-menu/menu.sh"'
grep -qxF "$LINE" "$HOME/.bashrc" || echo "$LINE" >> "$HOME/.bashrc"

# Pesan sukses
echo -e "\n\e[32m✅ Instalasi selesai. Menjalankan menu sekarang...\e[0m"
sleep 1

# Jalankan menu.sh langsung
bash "$DEST/menu.sh"
