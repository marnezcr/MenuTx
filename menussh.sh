#!/bin/bash
# Menu SSH dinamis untuk Termux - Versi Compact
# Simpan sebagai sshmenu.sh lalu jalankan: bash sshmenu.sh

LIST="$HOME/.sshlist"
touch $LIST

# Definisi Warna
KUNING='\033[1;33m'
HIJAU='\033[1;32m'
PUTIH='\033[1;37m'
CYAN='\033[1;36m'
MERAH='\033[1;31m'
NC='\033[0m'

function show_menu() {
    clear
    # Banner lebih ramping & komplit (MARNEZ)
    echo -e "${KUNING}  ╔══════════════════════════════════╗${NC}"
    echo -e "${KUNING}  ║${HIJAU}  __  __   _   ___ _  _ ___ ____  ${KUNING}║${NC}"
    echo -e "${KUNING}  ║${HIJAU} |  \/  | /_\ | _ \ \| | __|_  /  ${KUNING}║${NC}"
    echo -e "${KUNING}  ║${HIJAU} | |\/| |/ _ \|   / .  | _| / /   ${KUNING}║${NC}"
    echo -e "${KUNING}  ║${HIJAU} |_|  |_/_/ \_\_|_\_|\_|___/___|  ${KUNING}║${NC}"
    echo -e "${KUNING}  ║                   ${KUNING}               ║${NC}"
    echo -e "${KUNING}  ║${KUNING}        MARNEZ SSH MANAGER  ${KUNING}      ║${NC}"
    echo -e "${KUNING}  ╔══════════════════════════════════╗${NC}"
    echo -e "${KUNING}  ║                   ${KUNING}               ║${NC}"
    
    echo -e "${KUNING}  ║         ${CYAN}● MENU UTAMA  ${KUNING}           ║${NC}"
    echo -e "${KUNING}  ║         ${HIJAU}  [a]${NC} TAMBAH SSH ${KUNING}        ║${NC}"
    echo -e "${KUNING}  ║         ${HIJAU}  [b]${NC} HAPUS SSH ${KUNING}         ║${NC}"
    echo -e "${KUNING}  ║         ${MERAH}  [d]${NC} KELUAR ${KUNING}            ║${NC}"
    echo -e "${KUNING}  ║                   ${KUNING}               ║${NC}"
    echo -e "${KUNING}  ╔══════════════════════════════════╗${NC}"
    
    echo -e "  ${CYAN}● DAFTAR SSH${NC}"
    if [ -s "$LIST" ]; then
        # Format list: Nomor berwarna Hijau, teks Putih
        nl -w2 -s'. ' $LIST | sed "s/^[[:space:]]*[0-9]*/$(echo -e $HIJAU)  &  $(echo -e $NC)/"
    else
        echo -e "    ${PUTIH}(Daftar Kosong)${NC}"
    fi
    echo -e "${KUNING}  ════════════════════════════════════ ${NC}"
}

function add_ssh() {
    echo -e "\n${KUNING}┌─[ TAMBAH KONEKSI ]${NC}"
    read -p "  User    : " USER
    read -p "  Host/IP : " HOST
    read -p "  Port(22): " PORT
    PORT=${PORT:-22}
    echo "$USER@$HOST:$PORT" >> $LIST
    echo -e "${HIJAU}  ✔ Tersimpan!${NC}"
    sleep 1
}

function delete_ssh() {
    echo -e "\n${MERAH}┌─[ HAPUS KONEKSI ]${NC}"
    read -p "  MASUKAN NOMER: " NUM
    if [[ $NUM =~ ^[0-9]+$ ]]; then
        sed -i "${NUM}d" $LIST
        echo -e "${HIJAU}  ✔ TERHAPUS!${NC}"
    else
        echo -e "${MERAH}  ✘ SALAH INPUT${NC}"
    fi
    sleep 1
}

function login_by_number() {
    ENTRY=$(sed -n "${1}p" $LIST)
    if [ -n "$ENTRY" ]; then
        USER=$(echo $ENTRY | cut -d@ -f1)
        HOSTPORT=$(echo $ENTRY | cut -d@ -f2)
        HOST=$(echo $HOSTPORT | cut -d: -f1)
        PORT=$(echo $HOSTPORT | cut -d: -f2)
        echo -e "\n${HIJAU}  ➜ LOGIN KE $HOST...${NC}"
        ssh -p $PORT $USER@$HOST
    else
        echo -e "\n${MERAH}  ✘ No tidak ada!${NC}"
        sleep 1
    fi
}

while true; do
    show_menu
    echo -n -e "  ${PUTIH}PILIH [a/b/d] SSH [1/2....]: ${NC}"
    read CHOICE
    case $CHOICE in
        a) add_ssh ;;
        b) delete_ssh ;;
        d) echo -e "\n${KUNING} ════ MARNEZ CREATION ════${NC}"; exit ;;
        [0-9]*) login_by_number $CHOICE ;;
        *) echo -e "\n${MERAH}  SALAH ${NC}"; sleep 1 ;;
    esac
done
