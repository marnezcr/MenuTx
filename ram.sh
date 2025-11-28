#!/bin/bash

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfigurasi
EXCLUDE="com.termux" # Termux otomatis dikecualikan
CACHEDIR="$HOME/.ramoptimizer_cache"
mkdir -p "$CACHEDIR"

# Konfigurasi Dirty Flags (Penanda bahwa cache perlu update)
# Flag ini hanya muncul jika ada perubahan status (freeze/uninstall)
DIRTY_FLAG_NONSYSTEM="$CACHEDIR/dirty_nonsystem.flag"
DIRTY_FLAG_SYSTEM="$CACHEDIR/dirty_system.flag"
DIRTY_FLAG_DISABLED="$CACHEDIR/dirty_disabled.flag"

## --- Fungsi Umum --- ##

# Cek root
check_root() {
    su -mm -c "id" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}[!] Butuh ROOT!${NC}"
        return 1
    fi
}

# Deteksi keyboard (otomatis dilindungi)
get_keyboard() {
    kb=$(su -mm -c "settings get secure default_input_method" 2>/dev/null | cut -d'/' -f1)
    if [[ -n "$kb" && "$kb" != "null" ]]; then
        echo "$kb"
        return
    fi
    # Fallback list umum
    for pkg in com.google.android.inputmethod.latin \
               com.samsung.android.honeyboard \
               com.touchtype.swiftkey \
               com.google.android.googlequicksearchbox; do
        if su -mm -c "pm path $pkg" >/dev/null 2>&1; then
            echo "$pkg"
            return
        fi
    done
    echo ""
}

# Menentukan Flag File berdasarkan filter
get_dirty_file_by_filter() {
    case "$1" in
        "-3") echo "$DIRTY_FLAG_NONSYSTEM" ;;
        "-s") echo "$DIRTY_FLAG_SYSTEM" ;;
        "-d") echo "$DIRTY_FLAG_DISABLED" ;;
    esac
}

# Cache daftar paket
get_cached_packages() {
    local filter="$1"
    local filename=$(echo "$filter" | tr -d '-')
    local file="$CACHEDIR/pkg_${filename}.cache"
    local dirty_flag=$(get_dirty_file_by_filter "$filter")

    if [[ -f "$file" && ! -f "$dirty_flag" ]]; then
        cat "$file"
        return
    fi
    
    echo -e "${YELLOW}Memperbarui daftar paket ($filter)...${NC}" >&2
    su -mm -c "pm list packages $filter" 2>/dev/null | cut -d':' -f2 | sort > "$file"
    cat "$file"
}

# --- OPTIMIZED GET LABELS (PARALLEL VERSION) ---
get_labels() {
    local filter="$1"
    local filename=$(echo "$filter" | tr -d '-')
    local file="$CACHEDIR/label_${filename}.cache"
    local dirty_flag=$(get_dirty_file_by_filter "$filter")

    # 1. Cek Cache
    if [[ -f "$file" && ! -f "$dirty_flag" ]]; then
        cat "$file"
        return
    fi

    rm -f "$dirty_flag"
    > "$file" # Kosongkan file cache
    
    mapfile -t pkgs < <(get_cached_packages "$filter") 
    local total_pkgs=${#pkgs[@]}
    [[ $total_pkgs -eq 0 ]] && return

    echo -e "${YELLOW}Memperbarui label info ($filter)...${NC}" >&2
    echo -e "${BLUE}Memproses $total_pkgs aplikasi secara paralel (Batch Mode)...${NC}" >&2

    # 2. Konfigurasi Batch (15 app sekaligus agar cepat tapi HP tidak lag)
    local BATCH_SIZE=15
    local batch_cmd=""
    local count=0
    local processed=0

    # 3. Loop Paket
    for pkg in "${pkgs[@]}"; do
        # Command Extraction: Dump -> Grep Label -> Sed Clean -> Format output "pkg|label"
        # Kita jalankan di background (&) agar jalan bersamaan
        local cmd="( raw=\$(pm dump $pkg | grep -m1 'android:label'); \
                    val=\${raw#*label=}; val=\${val//\\\"/}; \
                    echo \"$pkg|\${val:-$pkg}\" ) & "
        
        batch_cmd+="$cmd"
        ((count++))

        # Jika batch penuh, eksekusi
        if (( count >= BATCH_SIZE )); then
            # 'wait' penting agar script menunggu 15 proses ini selesai sebelum lanjut
            su -mm -c "$batch_cmd wait" >> "$file"
            
            batch_cmd=""
            count=0
            processed=$((processed + BATCH_SIZE))
            # Tampilkan progres sederhana
            echo -ne " Progress: $processed / $total_pkgs \r" >&2
        fi
    done

    # 4. Eksekusi sisa batch terakhir (jika ada)
    if [[ -n "$batch_cmd" ]]; then
        su -mm -c "$batch_cmd wait" >> "$file"
        echo -ne " Progress: $total_pkgs / $total_pkgs \n" >&2
    fi
    
    # 5. Sortir hasil agar rapi saat ditampilkan
    sort -o "$file" "$file"
    cat "$file"
}

# Fungsi menandai cache kotor (Perlu update nanti)
mark_cache_dirty() {
    local type="$1" # nonsys atau sys
    touch "$DIRTY_FLAG_DISABLED"
    if [[ "$type" == "nonsys" ]]; then
        touch "$DIRTY_FLAG_NONSYSTEM"
    elif [[ "$type" == "sys" ]]; then
        touch "$DIRTY_FLAG_SYSTEM"
    fi
}

# Opsi 8: Manual Refresh
manual_refresh() {
    check_root || return
    while :; do
        clear
        echo -e "${BLUE}=== Refresh Cache Manual ===${NC}"
        echo -e "Gunakan ini jika baru menginstall aplikasi baru.\n"
        echo " 1. Refresh Cache ${GREEN}Non-System${NC}"
        echo " 2. Refresh Cache ${YELLOW}System${NC}"
        echo " 3. Refresh SEMUA"
        echo " 0. Kembali"
        
        read -p "Pilih: " sub_pil
        
        case "$sub_pil" in
            1) 
                rm -f "$CACHEDIR/pkg_-3.cache" "$CACHEDIR/label_-3.cache"
                touch "$DIRTY_FLAG_NONSYSTEM"
                get_labels "-3" >/dev/null
                ;;
            2) 
                rm -f "$CACHEDIR/pkg_-s.cache" "$CACHEDIR/label_-s.cache"
                touch "$DIRTY_FLAG_SYSTEM"
                get_labels "-s" >/dev/null
                ;;
            3) 
                rm -f "$CACHEDIR"/*.cache
                rm -f "$CACHEDIR"/*.flag
                touch "$DIRTY_FLAG_NONSYSTEM" "$DIRTY_FLAG_SYSTEM" "$DIRTY_FLAG_DISABLED"
                get_labels "-3" >/dev/null
                get_labels "-s" >/dev/null
                ;;
            0) return ;;
            *) echo -e "${RED}Salah!${NC}"; sleep 1; continue ;;
        esac
        echo -e "${GREEN}Cache berhasil diperbarui!${NC}"
        read -p "Enter..."
    done
}

## --- Fungsi Utama Menu --- ##

# 1. Force stop non-system
stop_non_system() {
    check_root || return
    echo -e "${BLUE}Force stop non-system apps...${NC}"
    mapfile -t pkgs < <(get_cached_packages "-3")
    for pkg in "${pkgs[@]}"; do
        if [[ " $EXCLUDE $KEYBOARD " =~ " $pkg " ]]; then continue; fi
        su -mm -c "am force-stop '$pkg'" >/dev/null 2>&1
    done
    echo -e "${YELLOW}Selesai force stop non-system.${NC}"
}

# 2. Force stop semua
stop_all() {
    check_root || return
    echo -e "${BLUE}Force stop SEMUA apps...${NC}"
    for f in "-3" "-s"; do
        mapfile -t pkgs < <(get_cached_packages "$f")
        for pkg in "${pkgs[@]}"; do
            if [[ " $EXCLUDE $KEYBOARD " =~ " $pkg " ]]; then continue; fi
            su -mm -c "am force-stop '$pkg'" >/dev/null 2>&1
        done
    done
    echo -e "${YELLOW}Selesai force stop semua.${NC}"
}

# 3 & 4. Bekukan / Aktifkan
freeze_menu() {
    local sys=$1
    local dirty_type=""
    
    if (( sys == 1 )); then
        check_root || return
        local title="System"
        local filter="-s"
        dirty_type="sys"
    else
        local title="Non-System"
        local filter="-3"
        dirty_type="nonsys"
    fi

    clear
    echo -e "${BLUE}=== ${title} Apps ===${NC}\n"

    mapfile -t pkgs < <(get_cached_packages "$filter") 
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo -e "${RED}Tidak ada aplikasi.${NC}"
        read -p "Enter..."
        return
    fi
    mapfile -t lines < <(get_labels "$filter") 
    
    # Cek status disabled realtime
    declare -A DISABLED_APPS
    mapfile -t disabled_pkgs < <(su -mm -c "pm list packages -d" 2>/dev/null | cut -d':' -f2)
    for d in "${disabled_pkgs[@]}"; do DISABLED_APPS["$d"]=1; done

    declare -A label
    for l in "${lines[@]}"; do if [[ "$l" ]]; then label[${l%%|*}]="${l#*|}"; fi; done

    for i in "${!pkgs[@]}"; do
        local pkg_name="${pkgs[$i]}"
        local name="${label[$pkg_name]:-$pkg_name}"
        if [[ ${DISABLED_APPS["$pkg_name"]} ]]; then
            printf " %3d. ${RED}Nonaktif${NC}  %s\n" $((i+1)) "$name"
        else
            printf " %3d. ${GREEN}Aktif${NC}    %s\n" $((i+1)) "$name"
        fi
    done

    echo
    read -p "Pilih nomor (pisahkan spasi/koma, cth: 6,28): " raw_input
    local clean_input="${raw_input//,/ }"
    local pilihan=($clean_input)

    if [[ ${#pilihan[@]} -eq 0 || ${pilihan[0]} == 0 ]]; then return; fi

    local changed=0
    for p in "${pilihan[@]}"; do
        if ! [[ "$p" =~ ^[0-9]+$ ]]; then continue; fi
        idx=$((p-1))
        if [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]]; then continue; fi
        
        pkg="${pkgs[$idx]}"
        name="${label[$pkg]:-$pkg}"

        if [[ ${DISABLED_APPS["$pkg"]} ]]; then
            if su -mm -c "cmd package enable '$pkg'" >/dev/null 2>&1; then
                echo -e "${GREEN}Diaktifkan → ${name}${NC}"
                changed=1
            else
                echo -e "${RED}Gagal → ${name}${NC}"
            fi
        else
            if su -mm -c "cmd package disable-user --user 0 '$pkg'" >/dev/null 2>&1; then
                echo -e "${RED}Dibekukan → ${name}${NC}"
                changed=1
            else
                echo -e "${RED}Gagal (Protected) → ${name}${NC}"
            fi
        fi
    done
    
    if (( changed == 1 )); then 
        mark_cache_dirty "$dirty_type"
        echo -e "${YELLOW}Cache ditandai untuk update berikutnya.${NC}"
    fi
    read -p "Enter untuk kembali..."
}

# 5. List nonaktif
list_disabled() {
    check_root || return
    clear
    echo -e "${BLUE}=== Aplikasi Nonaktif ===${NC}\n"
    
    mapfile -t pkgs < <(get_cached_packages "-d")
    
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo -e "${RED}Tidak ada aplikasi nonaktif.${NC}"
        read -p "Enter..."
        return
    fi
    
    # Load dictionary labels
    declare -A label
    if [[ -f "$CACHEDIR/label_-3.cache" ]]; then
        while IFS='|' read -r p l; do label["$p"]="$l"; done < "$CACHEDIR/label_-3.cache"
    fi
    if [[ -f "$CACHEDIR/label_-s.cache" ]]; then
        while IFS='|' read -r p l; do label["$p"]="$l"; done < "$CACHEDIR/label_-s.cache"
    fi

    for i in "${!pkgs[@]}"; do
        local pkg_name="${pkgs[$i]}"
        local name="${label[$pkg_name]:-$pkg_name}"
        printf " %3d. ${RED}Nonaktif${NC}  %s\n" $((i+1)) "$name"
    done

    read -p "Pilih nomor (pisahkan spasi/koma, cth: 6,28): " raw_input
    local clean_input="${raw_input//,/ }"
    local pilihan=($clean_input)

    if [[ ${#pilihan[@]} -eq 0 || ${pilihan[0]} == 0 ]]; then return; fi

    local changed=0
    for p in "${pilihan[@]}"; do
        if ! [[ "$p" =~ ^[0-9]+$ ]]; then continue; fi
        idx=$((p-1))
        if [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]]; then continue; fi
        pkg="${pkgs[$idx]}"
        
        if su -mm -c "cmd package enable '$pkg'" >/dev/null 2>&1; then
            echo -e "${GREEN}Diaktifkan → $pkg${NC}"
            changed=1
        fi
    done
    
    if (( changed == 1 )); then 
        mark_cache_dirty "nonsys"
        mark_cache_dirty "sys"
    fi
    read -p "Enter..."
}

# 6 & 7. Hapus app
uninstall_menu() {
    local sys=$1
    local dirty_type=""
    local filter=""
    
    if (( sys == 1 )); then
        check_root || return
        local title="SYSTEM ${RED}(BAHAYA!)${NC}"
        filter="-s"
        dirty_type="sys"
    else
        local title="Non-System"
        filter="-3"
        dirty_type="nonsys"
    fi

    clear
    echo -e "${BLUE}=== Hapus ${title} ===${NC}\n"
    mapfile -t pkgs < <(get_cached_packages "$filter")
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo -e "${RED}Tidak ada.${NC}"; read -p "Enter..."; return
    fi

    mapfile -t lines < <(get_labels "$filter")
    declare -A label
    for l in "${lines[@]}"; do if [[ "$l" ]]; then label[${l%%|*}]="${l#*|}"; fi; done

    for i in "${!pkgs[@]}"; do
        local pkg_name="${pkgs[$i]}"
        local name="${label[$pkg_name]:-$pkg_name}"
        printf " %3d. ${YELLOW}%s${NC}\n" $((i+1)) "$name"
    done

    read -p "Pilih HAPUS (pisahkan spasi/koma, cth: 6,28): " raw_input
    local clean_input="${raw_input//,/ }"
    local pilihan=($clean_input)

    if [[ ${#pilihan[@]} -eq 0 || ${pilihan[0]} == 0 ]]; then return; fi

    local changed=0
    for p in "${pilihan[@]}"; do
        if ! [[ "$p" =~ ^[0-9]+$ ]]; then continue; fi
        idx=$((p-1))
        if [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]]; then continue; fi
        
        pkg="${pkgs[$idx]}"
        name="${label[$pkg]:-$pkg}"
        
        if (( sys == 1 )); then
            read -p "Yakin hapus $name permanen? (y/n) " k
            [[ "$k" != "y" ]] && continue
        fi
        
        if su -mm -c "pm uninstall '$pkg'" >/dev/null 2>&1; then
            echo -e "${GREEN}Terhapus → ${name}${NC}"
            changed=1
        else
            echo -e "${RED}Gagal hapus → ${name}${NC}"
        fi
    done
    
    if (( changed == 1 )); then mark_cache_dirty "$dirty_type"; fi
    read -p "Enter..."
}

## --- Eksekusi Utama --- ##

KEYBOARD=$(get_keyboard)
if [[ -n "$KEYBOARD" ]]; then EXCLUDE="$EXCLUDE $KEYBOARD"; fi

if check_root >/dev/null 2>&1; then
    get_labels "-3" >/dev/null 2>&1
    get_labels "-s" >/dev/null 2>&1
else
    echo -e "${YELLOW}Mode Non-Root.${NC}"
fi

while :; do
    clear
    echo -e "${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}       RAM OPTIMIZER (BY MARNEZ)     ${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}\n"
    
    echo " 1. Stop App Non-System "
    echo -e " 2. Stop App ${YELLOW}SYSTEM ${NC}"
    echo " 3. Bekukan App Non-System "
    echo -e " 4. Bekukan App ${YELLOW}SYSTEM ${NC}"
    echo " 5. Aktifkan App"
    echo " 6. Hapus App Non-System "
    echo -e " 7. Hapus App ${YELLOW}SYSTEM ${NC}"
    echo " 8. Refresh Cache"
    echo -e " 0. ${GREEN}KELUAR ${NC}"
    
    echo
    read -p "Pilih: " pil
    case "$pil" in
        1) stop_non_system ;;
        2) stop_all ;;
        3) freeze_menu 0 ;;
        4) freeze_menu 1 ;;
        5) list_disabled ;;
        6) uninstall_menu 0 ;;
        7) uninstall_menu 1 ;;
        8) manual_refresh ;;
        0) exit 0 ;;
        *) echo -e "${RED}Salah!${NC}"; sleep 1 ;;
    esac
    if [[ "$pil" != "0" ]]; then :; fi
done
