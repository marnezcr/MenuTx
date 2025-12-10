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

# Fungsi Update Cache Parsial (Hanya hapus 1 baris jika uninstall)
remove_from_cache() {
   local pkg_target="$1"
   # Hapus dari semua file cache yang mengandung nama package ini
   sed -i "/$pkg_target/d" "$CACHEDIR"/*.cache 2>/dev/null
}

# Cache daftar paket (Hanya generate jika file tidak ada)
get_cached_packages() {
   local filter="$1"
   # tr -d '-' membuat '-3' menjadi '3', '-s' menjadi 's'
   local filename=$(echo "$filter" | tr -d '-')
   local file="$CACHEDIR/pkg_${filename}.cache"

   # Jika file ada dan isinya tidak kosong, pakai itu
   if [[ -s "$file" ]]; then
       cat "$file"
       return
   fi
   
   echo -e "${YELLOW}Memuat daftar paket($filter)...${NC}" >&2
   su -mm -c "pm list packages $filter" 2>/dev/null | cut -d':' -f2 | sort > "$file"
   cat "$file"
}

# --- OPTIMIZED GET LABELS (PARALLEL VERSION) ---
get_labels() {
   local filter="$1"
   local filename=$(echo "$filter" | tr -d '-')
   local file="$CACHEDIR/label_${filename}.cache"

   # 1. Cek Cache (JANGAN DIHAPUS jika sudah ada)
   if [[ -s "$file" ]]; then
       cat "$file"
       return
   fi

   # Jika belum ada, baru buat
   mapfile -t pkgs < <(get_cached_packages "$filter")
   local total_pkgs=${#pkgs[@]}
   [[ $total_pkgs -eq 0 ]] && return

   echo -e "${YELLOW}Memperbarui label info ($filter)...${NC}" >&2
   echo -e "${BLUE}Memproses $total_pkgs Cache...${NC}" >&2

   local BATCH_SIZE=15
   local batch_cmd=""
   local count=0
   local processed=0

   # Loop Paket untuk ambil label
   for pkg in "${pkgs[@]}"; do
       # Ambil label via pm dump (background process)
       local cmd="( raw=\$(pm dump $pkg | grep -m1 'android:label'); \
                   val=\${raw#*label=}; val=\${val//\\\"/}; \
                   echo \"$pkg|\${val:-$pkg}\" ) & "
       
       batch_cmd+="$cmd"
       ((count++))

       if (( count >= BATCH_SIZE )); then
           su -mm -c "$batch_cmd wait" >> "$file"
           batch_cmd=""
           count=0
           processed=$((processed + BATCH_SIZE))
           echo -ne " Progress: $processed / $total_pkgs \r" >&2
       fi
   done

   # Sisa batch
   if [[ -n "$batch_cmd" ]]; then
       su -mm -c "$batch_cmd wait" >> "$file"
       echo -ne " Progress: $total_pkgs / $total_pkgs \n" >&2
   fi
   
   # Sortir hasil
   sort -o "$file" "$file"
   cat "$file"
}

# Opsi 8: Manual Refresh (SUDAH DIPERBAIKI)
manual_refresh() {
   check_root || return
   while :; do
       clear
       echo -e "${BLUE}=== Refresh Cache===${NC}"
       echo -e "Refresh jika app tidak ada di list\n"
       echo -e " 1. Cache ${GREEN}Non-System${NC}"
       echo -e " 2. Cache ${YELLOW}System${NC}"
       echo " 3. Refresh SEMUA"
       echo " 0. Kembali"
       
       read -p "Pilih: " sub_pil
       
       # PERBAIKAN: Hapus nama file yang benar (tanpa tanda '-')
       case "$sub_pil" in
           1) 
              echo -e "${YELLOW}Menghapus cache Non-System...${NC}"
              rm -f "$CACHEDIR/pkg_3.cache" "$CACHEDIR/label_3.cache"
              get_labels "-3" >/dev/null 
              ;;
           2) 
              echo -e "${YELLOW}Menghapus cache System...${NC}"
              rm -f "$CACHEDIR/pkg_s.cache" "$CACHEDIR/label_s.cache" 
              get_labels "-s" >/dev/null 
              ;;
           3) 
              echo -e "${YELLOW}Menghapus SEMUA cache...${NC}"
              rm -f "$CACHEDIR"/*.cache
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

# 3 & 4. Bekukan (HANYA TAMPILKAN YANG AKTIF)
freeze_menu() {
   local sys=$1
   
   if (( sys == 1 )); then
       check_root || return
       local title="System"
       local filter="-s"
   else
       local title="Non-System"
       local filter="-3"
   fi

   clear
   echo -e "${BLUE}=== Bekukan ${title} Apps ===${NC}"
   echo -e "${YELLOW}(Aplikasi yang sedang AKTIF)${NC}\n"

   # Load cache (Names & Labels)
   mapfile -t pkgs < <(get_cached_packages "$filter")
   if [[ ${#pkgs[@]} -eq 0 ]]; then
       echo -e "${RED}Tidak ada aplikasi terdata.${NC}"
       read -p "Enter..."
       return
   fi
   
   # Ambil list aplikasi yang SUDAH NONAKTIF (Disabled) secara real-time
   declare -A DISABLED_APPS
   mapfile -t disabled_pkgs < <(su -mm -c "pm list packages -d" 2>/dev/null | cut -d':' -f2)
   for d in "${disabled_pkgs[@]}"; do DISABLED_APPS["$d"]=1; done

   # Load Labels ke Array
   mapfile -t lines < <(get_labels "$filter")
   declare -A label
   for l in "${lines[@]}"; do if [[ "$l" ]]; then label[${l%%|*}]="${l#*|}"; fi; done

   # Array sementara untuk menyimpan list yang ditampilkan
   local display_pkgs=()
   local display_names=()
   local counter=1

   for pkg_name in "${pkgs[@]}"; do
       # LOGIKA UTAMA: Jika aplikasi ada di list DISABLED_APPS, SKIP (Jangan tampilkan)
       if [[ ${DISABLED_APPS["$pkg_name"]} ]]; then
           continue
       fi
       
       # Kecualikan Termux/Keyboard dari list bekukan agar aman
       if [[ " $EXCLUDE $KEYBOARD " =~ " $pkg_name " ]]; then continue; fi

       local name="${label[$pkg_name]:-$pkg_name}"
       
       # Simpan ke array display
       display_pkgs+=("$pkg_name")
       display_names+=("$name")
       
       printf " %3d.${GREEN}[ON]${NC}${YELLOW}%s${NC}\n" $counter "$name"
       ((counter++))
   done

   if [[ ${#display_pkgs[@]} -eq 0 ]]; then
       echo -e "${GREEN}List Aplikasi dibekukan.${NC}"
       read -p "Enter..."
       return
   fi

   echo
   read -p "Pilih Beberapa No.(pisah Dengan koma): 
" raw_input
   local clean_input="${raw_input//,/ }"
   local pilihan=($clean_input)

   if [[ ${#pilihan[@]} -eq 0 || ${pilihan[0]} == 0 ]]; then return; fi

   for p in "${pilihan[@]}"; do
       if ! [[ "$p" =~ ^[0-9]+$ ]]; then continue; fi
       
       # Konversi nomor input ke index array (kurangi 1)
       local idx=$((p-1))
       
       # Validasi index
       if [[ $idx -lt 0 || $idx -ge ${#display_pkgs[@]} ]]; then continue; fi
       
       local pkg="${display_pkgs[$idx]}"
       local name="${display_names[$idx]}"

       if su -mm -c "cmd package disable-user --user 0 '$pkg'" >/dev/null 2>&1; then
           echo -e "${RED}Dibekukan → ${name}${NC}"
       else
           echo -e "${RED}Gagal (Protected) → ${name}${NC}"
       fi
   done
   
   read -p "Enter untuk kembali..."
}

# 5. List nonaktif (AKTIFKAN KEMBALI)
list_disabled() {
   check_root || return
   clear
   echo -e "  ${YELLOW}=== Aplikasi Nonaktif ===${YELLOW}\n"
   
   # Ambil real-time list disabled apps
   mapfile -t pkgs < <(su -mm -c "pm list packages -d" 2>/dev/null | cut -d':' -f2 | sort)
   
   if [[ ${#pkgs[@]} -eq 0 ]]; then
       echo -e "${GREEN}Tidak ada yang dibekukan.${NC}"
       read -p "Enter..."
       return
   fi
   
   # Load dictionary labels dari cache (tanpa reload pm dump)
   # PERBAIKAN: Baca dari nama file yang benar (tanpa strip)
   declare -A label
   if [[ -f "$CACHEDIR/label_3.cache" ]]; then
       while IFS='|' read -r p l; do label["$p"]="$l"; done < "$CACHEDIR/label_3.cache"
   fi
   if [[ -f "$CACHEDIR/label_s.cache" ]]; then
       while IFS='|' read -r p l; do label["$p"]="$l"; done < "$CACHEDIR/label_s.cache"
   fi

   for i in "${!pkgs[@]}"; do
       local pkg_name="${pkgs[$i]}"
       local name="${label[$pkg_name]:-$pkg_name}"
       # Tampilkan sebagai Nonaktif
       printf "%3d.${RED}[OFF]${NC}${YELLOW}%s${NC}\n" $((i+1)) "$name"
   done
   echo
   read -p "Pilih Beberapa Nomer(pisah Dengan koma): 
"  raw_input
   local clean_input="${raw_input//,/ }"
   local pilihan=($clean_input)

   if [[ ${#pilihan[@]} -eq 0 || ${pilihan[0]} == 0 ]]; then return; fi

   for p in "${pilihan[@]}"; do
       if ! [[ "$p" =~ ^[0-9]+$ ]]; then continue; fi
       idx=$((p-1))
       if [[ $idx -lt 0 || $idx -ge ${#pkgs[@]} ]]; then continue; fi
       pkg="${pkgs[$idx]}"
       
       if su -mm -c "cmd package enable '$pkg'" >/dev/null 2>&1; then
           echo -e "${GREEN}Diaktifkan → $pkg${NC}"
       fi
   done
   
   read -p "Enter..."
}

# 6 & 7. Hapus app (UNINSTALL)
uninstall_menu() {
   local sys=$1
   local filter=""
   
   if (( sys == 1 )); then
       check_root || return
       local title="SYSTEM ${RED}(BAHAYA!)${NC}"
       filter="-s"
   else
       local title="Non-System"
       filter="-3"
   fi

   clear
   echo -e "${BLUE}=== Hapus ${title} ===${NC}\n"
   
   # Gunakan cache yang ada
   mapfile -t pkgs < <(get_cached_packages "$filter")
   if [[ ${#pkgs[@]} -eq 0 ]]; then
       echo -e "${RED}Tidak ada data.${NC}"; read -p "Enter..."; return
   fi

   mapfile -t lines < <(get_labels "$filter")
   declare -A label
   for l in "${lines[@]}"; do if [[ "$l" ]]; then label[${l%%|*}]="${l#*|}"; fi; done

   for i in "${!pkgs[@]}"; do
       local pkg_name="${pkgs[$i]}"
       local name="${label[$pkg_name]:-$pkg_name}"
       printf " %3d. ${YELLOW}%s${NC}\n" $((i+1)) "$name"
   done

   read -p "Pilih HAPUS (pisah Dengan koma): " raw_input
   local clean_input="${raw_input//,/ }"
   local pilihan=($clean_input)

   if [[ ${#pilihan[@]} -eq 0 || ${pilihan[0]} == 0 ]]; then return; fi

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
           # UPDATE CACHE PER APLIKASI (Hapus baris paket ini dari cache)
           remove_from_cache "$pkg"
       else
           echo -e "${RED}Gagal hapus → ${name}${NC}"
       fi
   done
   
   read -p "Enter..."
}

## --- Eksekusi Utama --- ##

KEYBOARD=$(get_keyboard)
if [[ -n "$KEYBOARD" ]]; then EXCLUDE="$EXCLUDE $KEYBOARD"; fi

if check_root >/dev/null 2>&1; then
   # Load cache awal jika belum ada
   # PERBAIKAN: Cek file yang benar (label_3 bukan label_-3)
   if [[ ! -f "$CACHEDIR/label_3.cache" ]]; then get_labels "-3" >/dev/null 2>&1; fi
   if [[ ! -f "$CACHEDIR/label_s.cache" ]]; then get_labels "-s" >/dev/null 2>&1; fi
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
   echo " 3. Bekukan App Non-System"
   echo -e " 4. Bekukan App ${YELLOW}SYSTEM ${NC}"
   echo -e " ${GREEN}5. Aktifkan App${NC}"
   echo " 6. Hapus App Non-System "
   echo -e " 7. Hapus App ${YELLOW}SYSTEM ${NC}"
   echo " 8. Refresh Cache"
   echo -e " 0. ${RED}KELUAR ${NC}"
   
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
