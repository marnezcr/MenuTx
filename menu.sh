#!/bin/bash
# ==========================================
# 🌟 TERMUX MENU BY CORRODEDVOMIT 
# 🙏 EDIT BY MARNEZ (Versi Custom Request)
# ==========================================

REPO_LIST="$HOME/.termux_repos"

# Pastikan REPO_LIST ada
touch "$REPO_LIST" 2>/dev/null || {
  echo -e "\e[31m❌ Gagal membuat atau mengakses $REPO_LIST\e[0m"
  exit 1
}

# Aktifkan nullglob agar loop tidak error jika folder kosong
shopt -s nullglob

# -------------------------
# Fungsi: Jalankan atau clone (Helper)
# -------------------------
run_or_clone() {
  local folder="$1"
  local repo_url="$2"
  # Fungsi ini tetap ada untuk menghandle penambahan repo baru via menu 'a'
  cd "$HOME" || return

  if [ ! -d "$HOME/$folder" ]; then
    echo -e "\e[33m🔍 Folder $folder belum ada, cloning dari $repo_url ...\e[0m"
    if ! git clone "$repo_url" "$HOME/$folder"; then
      echo -e "\e[31m❌ Gagal clone repo\e[0m"
      read -p "ENTER..."
      return
    fi
    if [ -f "$HOME/$folder/setup.sh" ]; then
      (cd "$HOME/$folder" && bash setup.sh)
    fi
  fi
}

# -------------------------
# Fungsi: Tambah Repo baru (Menu a)
# -------------------------
add_new_repo() {
  echo
  echo -e "\e[1;33m[ Tambah Repo Baru ]\e[0m"
  read -p "🌐 Masukkan URL Git repo: " repo_raw
  
  # Bersihkan input
  repo_raw="${repo_raw#"${repo_raw%%[![:space:]]*}"}"   
  repo_raw="${repo_raw%"${repo_raw##*[![:space:]]}"}"   
  repo="${repo_raw#git clone }"
  repo="${repo#git clone}"
  repo="${repo#git }"
  repo="${repo%\"}"
  repo="${repo#\"}"
  repo="${repo%\'}"
  repo="${repo#\'}"
  repo="${repo%/}"

  if [[ -z "$repo" ]] || ! [[ "$repo" =~ ^(https?://|git@) ]]; then
    echo -e "\e[31m❌ URL repo tidak valid.\e[0m"
    read -p "ENTER..."
    return
  fi

  folder=$(basename "$repo" .git)
  
  echo -e "\e[33m🔍 Meng-clone '$folder'...\e[0m"

  if [ -d "$HOME/$folder" ]; then
    read -p "Folder $folder sudah ada. Hapus dan timpa? (y/n): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      rm -rf "$HOME/$folder"
    else
      return
    fi
  fi

  if ! git clone "$repo" "$HOME/$folder"; then
    echo -e "\e[31m❌ Gagal clone.\e[0m"
    read -p "ENTER..."
    return
  fi

  if [ -f "$HOME/$folder/setup.sh" ]; then
    echo -e "\e[36m🛠 Menjalankan setup.sh...\e[0m"
    (cd "$HOME/$folder" && bash setup.sh)
  fi

  # Simpan ke list agar prioritas (opsional, karena folder scan otomatis menangkapnya)
  entry="$folder|$repo"
  if ! grep -Fxq "$entry" "$REPO_LIST"; then
    echo "$entry" >> "$REPO_LIST"
  fi

  echo -e "\e[32m✅ Berhasil ditambahkan!\e[0m"
  read -p "ENTER untuk kembali..."
}

# -------------------------
# Fungsi: Tambah manual repo (Menu b)
# -------------------------
add_manual_repo() {
  echo
  echo -e "\e[1;33m[ Tambah Repo Manual (Folder Lokal) ]\e[0m"
  read -p "📁 Masukkan nama folder di home: " input
  
  if [ -z "$input" ]; then return; fi
  
  if [[ "$input" = /* ]]; then
    folder=$(basename "$input")
  else
    folder="$input"
  fi

  if [ ! -d "$HOME/$folder" ]; then
    echo -e "\e[31m❌ Folder '$folder' tidak ditemukan di $HOME.\e[0m"
    read -p "ENTER..."
    return
  fi

  if grep -Fq "^$folder|" "$REPO_LIST"; then
    echo -e "\e[33m⚠️  Folder sudah terdaftar.\e[0m"
  else
    echo "$folder|manual" >> "$REPO_LIST"
    echo -e "\e[32m✅ Folder '$folder' didaftarkan.\e[0m"
  fi
  read -p "ENTER untuk kembali..."
}

# -------------------------
# Fungsi: Hapus Repo (Menu c)
# -------------------------
delete_repo() {
  echo
  echo -e "\e[1;31m🗑️  HAPUS REPO DARI MENU\e[0m"
  
  # Gunakan array DYN_NAMES yang sudah di-generate di menu utama
  # Kita harus generate ulang di sini scope lokal atau gunakan global logic
  # Agar aman, kita scan ulang simpel
  local i=1
  local list_del=()
  
  # Logic scan sama dengan menu utama untuk konsistensi
  EXCLUDE_SET=" " # Tambahkan folder yang ingin di-exclude jika ada
  
  for dir in "$HOME"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    case "$name" in .*) continue ;; esac
    # Filter folder sistem termux/khusus jika perlu
    [ -f "$HOME/$name/main.py" ] || continue 
    
    list_del+=("$name")
  done

  # Cek tambahan dari REPO_LIST
  if [ -f "$REPO_LIST" ]; then
    while IFS='|' read -r folder repourl; do
       [ -z "$folder" ] && continue
       skip=false
       for e in "${list_del[@]}"; do
         if [ "$e" = "$folder" ]; then skip=true; break; fi
       done
       $skip && continue
       if [ -d "$HOME/$folder" ] && [ -f "$HOME/$folder/main.py" ]; then
         list_del+=("$folder")
       fi
    done < "$REPO_LIST"
  fi

  if [ ${#list_del[@]} -eq 0 ]; then
    echo "Tidak ada folder dengan main.py untuk dihapus."
    read -p "ENTER..."
    return
  fi

  local count=1
  for d in "${list_del[@]}"; do
    echo "  [$count] $d"
    ((count++))
  done

  echo
  read -p "Pilih nomor yang akan dihapus: " num
  if [[ ! "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt ${#list_del[@]} ]; then
    echo "❌ Pilihan tidak valid."
    read -p "ENTER..."
    return
  fi

  target="${list_del[$((num-1))]}"
  read -p "⚠️ Hapus folder '$target' dan datanya? (y/n): " konf
  if [[ "$konf" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/$target"
    # Bersihkan dari list database juga
    sed -i "/^${target}|/d" "$REPO_LIST" 2>/dev/null || true
    echo -e "\e[32m✅ Terhapus.\e[0m"
  else
    echo "Batal."
  fi
  read -p "ENTER..."
}

# -------------------------
# Fungsi: Update Repo (Menu d)
# -------------------------
update_repo() {
  echo -e "\n\e[36m🔄 Update Semua Repo...\e[0m"
  for dir in "$HOME"/*/; do
    if [ -d "${dir}.git" ] || [ -d "$dir/.git" ]; then
      echo -e "\e[33m📦 Updating $(basename "$dir")...\e[0m"
      (cd "$dir" && git pull)
    fi
  done
  echo -e "\e[32m✅ Selesai.\e[0m"
  read -p "ENTER..."
}

# -------------------------
# MENU UTAMA
# -------------------------
while true; do
  clear
  echo -e "\e[1;36m╔═══════════════════════════════════════════╗\e[0m"
  echo -e "\e[1;36m║\e[0m             🔥 \e[1;33mMARNEZ TOOLS\e[0m 🔥            \e[1;36m║\e[0m"
  echo -e "\e[1;36m╚═══════════════════════════════════════════╝\e[0m"
  
  # --- BAGIAN 1: TOOLS ---
  echo -e "\e[1;33m# TOOLS MCR\e[0m"
  echo -e "  \e[36m[1]\e[0m ➤ Optimasi RAM 🧹"
  echo -e "  \e[36m[2]\e[0m ➤ Jalankan ADB 📵"
  echo

  # --- BAGIAN 2: DINAMIS (PILIH DOR) ---
  echo -e "\e[1;36m# TOOL PYTHON\e[0m"
  
  # Array untuk menyimpan nama folder dinamis
  DYN_NAMES=()
  # Counter mulai dari 3
  n=3

  # Logic Scan Folder: Hanya folder yang punya main.py
  # 1. Scan folder fisik di HOME
  for dir in "$HOME"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    # Skip hidden folder
    case "$name" in .*) continue ;; esac
    
    # Syarat: harus ada main.py agar masuk menu
    if [ -f "$HOME/$name/main.py" ]; then
        DYN_NAMES+=("$name")
        printf "  \e[32m[%d]\e[0m ➤ %s\n" "$n" "$name"
        n=$((n+1))
    fi
  done

  # 2. Cek REPO_LIST barangkali ada repo yang belum ter-scan (misal struktur beda)
  #    tapi biasanya scan folder di atas sudah cukup. Ini backup.
  if [ -f "$REPO_LIST" ]; then
    while IFS='|' read -r folder repourl; do
      [ -z "$folder" ] && continue
      # Cek duplikasi agar tidak muncul 2x
      skip=false
      for e in "${DYN_NAMES[@]}"; do
        if [ "$e" = "$folder" ]; then skip=true; break; fi
      done
      $skip && continue

      # Tampilkan
      if [ -d "$HOME/$folder" ] && [ -f "$HOME/$folder/main.py" ]; then
        DYN_NAMES+=("$folder")
        printf "  \e[32m[%d]\e[0m ➤ %s\n" "$n" "$folder"
        n=$((n+1))
      fi
    done < "$REPO_LIST"
  fi

  echo
  echo -e "  \e[36m----------------------------------------\e[0m"
  echo -e "  \e[33m[a]\e[0m Repo baru      \e[36m[x]\e[0m KELUAR MENU"
  echo -e "  \e[33m[b]\e[0m Repo manual    \e[36m[q]\e[0m KELUAR TERMUX"
  echo -e "  \e[33m[c]\e[0m Hapus repo"
  echo -e "  \e[33m[d]\e[0m Update repo"
  echo -e "  \e[36m----------------------------------------\e[0m"
  
  max_option=$((n-1))
  
  read -p "Masukkan pilihan: " pilih

  case "$pilih" in
    1)
      # OPTIMASI RAM
      script_ram="$HOME/MenuTx/ram.sh"
      # Fallback jika file tidak di MenuTx, cek di current dir atau folder lain
      if [ ! -f "$script_ram" ]; then script_ram="ram.sh"; fi 
      
      if [ -f "$script_ram" ]; then
        echo -e "\e[90m🚀 Menjalankan Optimasi RAM...\e[0m"
        bash "$script_ram"
      else
        echo -e "\e[31m❌ File ram.sh tidak ditemukan ($script_ram)\e[0m"
      fi
      read -p "ENTER..."
      ;;
    2)
      # JALANKAN ADB
      script_adb="$HOME/MenuTx/adb.sh"
      if [ ! -f "$script_adb" ]; then script_adb="adb.sh"; fi
      
      if [ -f "$script_adb" ]; then
        echo -e "\e[90m🚀 Menjalankan ADB...\e[0m"
        bash "$script_adb"
      else
        echo -e "\e[31m❌ File adb.sh tidak ditemukan ($script_adb)\e[0m"
      fi
      read -p "ENTER..."
      ;;
      
    a|A) add_new_repo ;;
    b|B) add_manual_repo ;;
    c|C) delete_repo ;;
    d|D) update_repo ;;
    x|X) 
      echo -e "\e[36mKeluar menu...\e[0m"
      break 
      ;;
    q|Q) 
      echo -e "\e[31mBye bye!\e[0m"
      exit 0 
      ;;
      
    *)
      # LOGIC DINAMIS (3 ke atas)
      if [[ "$pilih" =~ ^[0-9]+$ ]]; then
        # Cek apakah nomor valid (>= 3 dan <= max_option)
        if [ "$pilih" -ge 3 ] && [ "$pilih" -le "$max_option" ]; then
          # Hitung index array. 
          # Karena menu mulai dari 3, index 0 adalah menu 3.
          # Rumus: index = pilihan - 3
          index=$((pilih - 3))
          
          target_folder="${DYN_NAMES[$index]}"
          
          if [ -d "$HOME/$target_folder" ]; then
            cd "$HOME/$target_folder" || continue
            echo -e "\e[90m🚀 Menjalankan $target_folder (main.py)...\e[0m"
            python main.py
          else
            echo -e "\e[31m❌ Folder tidak ditemukan.\e[0m"
          fi
          read -p "ENTER..."
        else
          echo -e "\e[31m❌ Pilihan tidak ada.\e[0m"
          read -p "ENTER..."
        fi
      else
        echo -e "\e[31m❌ Input salah.\e[0m"
        read -p "ENTER..."
      fi
      ;;
  esac
done
