#!/bin/bash

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paket dikecualikan
EXCLUDE="com.termux"

# Cek root
check_root() {
    if ! su -mm -c "id" >/dev/null 2>&1; then
        echo -e "${RED}[!] ROOT tidak tersedia atau su gagal!${NC}"
        return 1
    fi
    return 0
}

# Deteksi keyboard
get_keyboard() {
    kb=$(su -mm -c "settings get secure default_input_method" 2>/dev/null | cut -d'/' -f1)
    [[ -n "$kb" && "$kb" != "null" ]] && echo "$kb" && return
    for pkg in com.google.android.inputmethod.latin com.samsung.android.honeyboard com.touchtype.swiftkey com.gboard; do
        su -mm -c "pm list packages" 2>/dev/null | grep -q "^package:$pkg$" && echo "$pkg" && return
    done
    echo ""
}

KEYBOARD=$(get_keyboard)
[[ -n "$KEYBOARD" ]] && EXCLUDE="$EXCLUDE $KEYBOARD"

# === 1. Force Stop Non-System ===
force_stop_non_system() {
    echo -e "${BLUE}Memaksa berhenti app non-system...${NC}\n"
    local stopped=0 failed=0
    mapfile -t pkgs < <(su -mm -c "pm list packages -3" 2>/dev/null | cut -d':' -f2)
    for pkg in "${pkgs[@]}"; do
        [[ " $EXCLUDE " == *" $pkg "* ]] && continue
        if su -mm -c "am force-stop '$pkg'" >/dev/null 2>&1; then
            echo -e "   ${RED}STOPPED:${NC} $pkg"
            ((stopped++))
        else
            echo -e "   ${GREEN}FAILED :${NC} $pkg"
            ((failed++))
        fi
    done
    echo -e "\n${YELLOW}Selesai: ${RED}$stopped${NC} stopped, ${GREEN}$failed${NC} failed${NC}"
}

# === 2. Force Stop Semua (ROOT) ===
force_stop_all() {
    check_root || return
    echo -e "${BLUE}Memaksa berhenti SEMUA app...${NC}\n"
    local stopped=0 failed=0

    # Non-system
    mapfile -t pkgs < <(su -mm -c "pm list packages -3" 2>/dev/null | cut -d':' -f2)
    for pkg in "${pkgs[@]}"; do
        [[ " $EXCLUDE " == *" $pkg "* ]] && continue
        su -mm -c "am force-stop '$pkg'" >/dev/null 2>&1 && { echo -e "   ${RED}STOPPED:${NC} $pkg"; ((stopped++)); } || { echo -e "   ${GREEN}FAILED :${NC} $pkg"; ((failed++)); }
    done

    # System
    mapfile -t pkgs < <(su -mm -c "pm list packages -s" 2>/dev/null | cut -d':' -f2)
    for pkg in "${pkgs[@]}"; do
        [[ " $EXCLUDE " == *" $pkg "* ]] && continue
        su -mm -c "am force-stop '$pkg'" >/dev/null 2>&1 && { echo -e "   ${RED}STOPPED (sys):${NC} $pkg"; ((stopped++)); } || { echo -e "   ${GREEN}FAILED (sys):${NC} $pkg"; ((failed++)); }
    done

    echo -e "\n${YELLOW}Selesai: ${RED}$stopped${NC} stopped, ${GREEN}$failed${NC} failed${NC}"
}

# === 3 & 4. Bekukan / Aktifkan ===
freeze_apps() {
    local is_system=$1 title="Non-System" filter="-3"
    [[ $is_system -eq 1 ]] && title="System" && filter="-s"
    [[ $is_system -eq 1 ]] && ! check_root && return

    clear
    echo -e "${BLUE}=== $title Apps ===${NC}\n"
    mapfile -t pkgs < <(su -mm -c "pm list packages $filter" 2>/dev/null | cut -d':' -f2)
    [[ ${#pkgs[@]} -eq 0 ]] && { echo -e "${RED}Tidak ada aplikasi $title.${NC}"; read -p "Enter untuk lanjut..."; return; }

    declare -A seen
    for i in "${!pkgs[@]}"; do
        pkg="${pkgs[$i]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")
        [[ -z "$name" || "$name" == "null" ]] && name="$pkg"
        if su -mm -c "pm list packages -d" 2>/dev/null | grep -q "^package:$pkg$"; then
            [[ ! -v seen[$name] ]] && echo -e " $(printf "%3d. ${RED}Nonaktif${NC}  %s" $((i+1)) "$name")" && seen[$name]=1
        else
            [[ ! -v seen[$name] ]] && echo -e " $(printf "%3d. ${GREEN}Aktif   ${NC}  %s" $((i+1)) "$name")" && seen[$name]=1
        fi
    done

    echo
    read -p "Masukkan nomor aplikasi (pisah spasi, 0=keluar): " -a choices
    [[ ${#choices[@]} -eq 0 || ${choices[0]} -eq 0 ]] && return

    for c in "${choices[@]}"; do
        idx=$((c-1))
        [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]] && { echo -e "${RED}Nomor $c invalid!${NC}"; continue; }
        pkg="${pkgs[$idx]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")

        if su -mm -c "pm list packages -d" 2>/dev/null | grep -q "^package:$pkg$"; then
            # Aktifkan
            if [[ $is_system -eq 1 ]]; then
                su -mm -c "cmd package enable '$pkg'" >/dev/null 2>&1 && echo -e "${GREEN}Aktif: $name${NC}" || echo -e "${RED}GAGAL! $name${NC}"
            else
                su -mm -c "cmd package enable '$pkg'" >/dev/null 2>&1 && echo -e "${GREEN}Aktif: $name${NC}" || echo -e "${RED}GAGAL! $name${NC}"
            fi
        else
            # Bekukan
            if [[ $is_system -eq 1 ]]; then
                su -mm -c "cmd package disable-user --user 0 '$pkg'" >/dev/null 2>&1 && echo -e "${RED}DIBEKUKAN: $name${NC}" || echo -e "${RED}GAGAL (dilindungi)! $name${NC}"
            else
                su -mm -c "cmd package disable-user --user 0 '$pkg'" >/dev/null 2>&1 && echo -e "${RED}DIBEKUKAN: $name${NC}" || echo -e "${RED}GAGAL! $name${NC}"
            fi
        fi
    done
    read -p "Enter untuk lanjut..."
}

# === 5. List Aplikasi Nonaktif ===
list_inactive_apps() {
    check_root || return
    clear
    echo -e "${BLUE}=== List Aplikasi Nonaktif ===${NC}\n"
    mapfile -t pkgs < <(su -mm -c "pm list packages -d" 2>/dev/null | cut -d':' -f2)
    [[ ${#pkgs[@]} -eq 0 ]] && { echo -e "${RED}Tidak ada aplikasi nonaktif.${NC}"; read -p "Enter untuk lanjut..."; return; }

    declare -A seen
    for i in "${!pkgs[@]}"; do
        pkg="${pkgs[$i]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")
        [[ -z "$name" || "$name" == "null" ]] && name="$pkg"
        [[ ! -v seen[$name] ]] && echo -e " $(printf "%3d. ${RED}Nonaktif${NC}  %s" $((i+1)) "$name")" && seen[$name]=1
    done

    echo
    read -p "Masukkan nomor aplikasi untuk aktifkan (pisah spasi, 0=keluar): " -a choices
    [[ ${#choices[@]} -eq 0 || ${choices[0]} -eq 0 ]] && return

    for c in "${choices[@]}"; do
        idx=$((c-1))
        [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]] && { echo -e "${RED}Nomor $c invalid!${NC}"; continue; }
        pkg="${pkgs[$idx]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")
        if su -mm -c "cmd package enable '$pkg'" >/dev/null 2>&1; then
            echo -e "${GREEN}Aktif: $name${NC}"
        else
            echo -e "${RED}GAGAL! $name${NC}"
        fi
    done
    read -p "Enter untuk lanjut..."
}

# === 6. Hapus App (Non-System) ===
uninstall_non_system_apps() {
    check_root || return
    clear
    echo -e "${BLUE}=== List Aplikasi Non-System untuk Dihapus ===${NC}\n"
    mapfile -t pkgs < <(su -mm -c "pm list packages -3" 2>/dev/null | cut -d':' -f2)
    [[ ${#pkgs[@]} -eq 0 ]] && { echo -e "${RED}Tidak ada aplikasi non-system.${NC}"; read -p "Enter untuk lanjut..."; return; }

    declare -A seen
    for i in "${!pkgs[@]}"; do
        pkg="${pkgs[$i]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")
        [[ -z "$name" || "$name" == "null" ]] && name="$pkg"
        [[ ! -v seen[$name] ]] && echo -e " $(printf "%3d. ${YELLOW}%s${NC}" $((i+1)) "$name")" && seen[$name]=1
    done

    echo
    read -p "Masukkan nomor aplikasi untuk dihapus (pisah spasi, 0=keluar): " -a choices
    [[ ${#choices[@]} -eq 0 || ${choices[0]} -eq 0 ]] && return

    for c in "${choices[@]}"; do
        idx=$((c-1))
        [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]] && { echo -e "${RED}Nomor $c invalid!${NC}"; continue; }
        pkg="${pkgs[$idx]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")
        if su -mm -c "pm uninstall '$pkg'" >/dev/null 2>&1; then
            echo -e "${GREEN}Dihapus: $name${NC}"
        else
            echo -e "${RED}GAGAL! $name${NC}"
        fi
    done
    read -p "Enter untuk lanjut..."
}

# === 7. Hapus System App ===
uninstall_system_apps() {
    check_root || return
    clear
    echo -e "${BLUE}=== List Aplikasi Sistem untuk Dihapus ===${NC}\n"
    mapfile -t pkgs < <(su -mm -c "pm list packages -s" 2>/dev/null | cut -d':' -f2)
    [[ ${#pkgs[@]} -eq 0 ]] && { echo -e "${RED}Tidak ada aplikasi sistem.${NC}"; read -p "Enter untuk lanjut..."; return; }

    declare -A seen
    for i in "${!pkgs[@]}"; do
        pkg="${pkgs[$i]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")
        [[ -z "$name" || "$name" == "null" ]] && name="$pkg"
        [[ ! -v seen[$name] ]] && echo -e " $(printf "%3d. ${YELLOW}%s${NC}" $((i+1)) "$name")" && seen[$name]=1
    done

    echo
    read -p "Masukkan nomor aplikasi untuk dihapus (pisah spasi, 0=keluar): " -a choices
    [[ ${#choices[@]} -eq 0 || ${choices[0]} -eq 0 ]] && return

    for c in "${choices[@]}"; do
        idx=$((c-1))
        [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]] && { echo -e "${RED}Nomor $c invalid!${NC}"; continue; }
        pkg="${pkgs[$idx]}"
        name=$(su -mm -c "pm dump '$pkg'" 2>/dev/null | grep -m1 "android:label" | cut -d'=' -f2 | tr -d '"' || echo "$pkg")
        echo -e "${RED}PERINGATAN: Aplikasi sistem ($name) akan dihapus permanen! Lanjutkan? (Y/N)${NC}"
        read -p "Pilih (Y/N): " confirm
        if [[ "$confirm" == "Y" || "$confirm" == "y" ]]; then
            if su -mm -c "pm uninstall '$pkg'" >/dev/null 2>&1; then
                echo -e "${GREEN}Dihapus: $name${NC}"
            else
                echo -e "${RED}GAGAL! $name${NC}"
            fi
        else
            echo -e "${YELLOW}Dibatalkan: $name${NC}"
        fi
    done
    read -p "Enter untuk lanjut..."
}

# === MENU ===
while :; do
    clear
    echo -e "${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}       RAM OPTIMIZER BY MARNEZ  ${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo " 1. Stop non-system"
    echo " 2. Stop semua "
    echo " 3. Bekukan non-system"
    echo " 4. Bekukan system"
    echo " 5. List aplikasi nonaktif"
    echo " 6. Hapus App"
    echo " 7. Hapus System App"
    echo " 0. Keluar"
    [[ -n "$KEYBOARD" ]] && echo -e "Keyboard: ${BLUE}$KEYBOARD${NC}"
    echo

    read -p "Pilih: " m
    case "$m" in
        1) force_stop_non_system ;;
        2) force_stop_all ;;
        3) freeze_apps 0 ;;
        4) freeze_apps 1 ;;
        5) list_inactive_apps ;;
        6) uninstall_non_system_apps ;;
        7) uninstall_system_apps ;;
        0) echo -e "${GREEN}Selesai!${NC}"; exit 0 ;;
        *) echo -e "${RED}Salah!${NC}" ;;
    esac
    echo
    read -p "Enter untuk lanjut..."
done
