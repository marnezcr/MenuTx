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
# Fungsi: Fitur Gemini Model & Coding Linux
# -------------------------
select_gemini_model() {
  local proj_dir="$1"
  echo
  echo -e "\e[1;36m======================================\e[0m"
  echo -e "\e[1;33m          PILIH MODEL GEMINI          \e[0m"
  echo -e "\e[1;36m======================================\e[0m"
  echo -e "Project Directory: \e[32m$proj_dir\e[0m"
  echo -e "--------------------------------------"
  echo -e "  \e[36m[1]\e[0m Gemini 3.6 Flash (gemini/gemini-3.6-flash)"
  echo -e "  \e[36m[2]\e[0m Gemini 2.5 Flash (gemini/gemini-2.5-flash)"
  echo -e "  \e[36m[3]\e[0m Gemini 2.5 Pro   (gemini/gemini-2.5-pro)"
  echo -e "  \e[36m[4]\e[0m Gemini 1.5 Flash (gemini/gemini-1.5-flash)"
  echo -e "  \e[36m[5]\e[0m Gemini 1.5 Pro   (gemini/gemini-1.5-pro)"
  echo -e "  \e[36m[6]\e[0m Input Custom Model Gemini"
  echo -e "--------------------------------------"
  read -p "Pilih model Gemini [1-6]: " m_choice

  local model_name=""
  case "$m_choice" in
    1) model_name="gemini/gemini-3.6-flash" ;;
    2) model_name="gemini/gemini-2.5-flash" ;;
    3) model_name="gemini/gemini-2.5-pro" ;;
    4) model_name="gemini/gemini-1.5-flash" ;;
    5) model_name="gemini/gemini-1.5-pro" ;;
    6)
      read -p "Masukkan nama model custom (misal gemini/gemini-2.0-flash): " custom_m
      model_name="$custom_m"
      ;;
    *)
      echo -e "\e[33mPilihan tidak valid, menggunakan default gemini/gemini-3.6-flash\e[0m"
      model_name="gemini/gemini-3.6-flash"
      sleep 1
      ;;
  esac

  if [ -z "$model_name" ]; then
    model_name="gemini/gemini-3.6-flash"
  fi

  echo -e "\e[36m--------------------------------------\e[0m"
  echo -e "\e[32m🚀 Menjalankan Aider di Proot Debian...\e[0m"
  echo -e "Directory : $proj_dir"
  echo -e "Model     : $model_name"
  echo -e "Perintah  : aider --model $model_name --no-stream"
  echo -e "\e[36m--------------------------------------\e[0m"

  proot-distro login debian --work-dir "$proj_dir" -- bash -l -c "cd \"$proj_dir\" 2>/dev/null; export PATH=\$PATH:\$HOME/.local/bin:/root/.local/bin:/usr/local/bin; aider --model '$model_name' --no-stream"
  read -p "ENTER untuk kembali..."
}

coding_menu() {
  local current_dir="/data/data/com.termux/files/home/storage/shared"

  if [ ! -d "$current_dir" ]; then
    current_dir="$HOME"
  fi

  local selected_project_dir=""

  while true; do
    clear
    echo -e "\e[1;36m======================================\e[0m"
    echo -e "\e[1;33m          PILIH FOLDER PROJECT        \e[0m"
    echo -e "\e[1;36m======================================\e[0m"
    echo -e "Lokasi saat ini: \e[32m$current_dir\e[0m"
    echo -e "--------------------------------------"

    local subdirs=()
    local idx=1

    for d in "$current_dir"/*/; do
      if [ -d "$d" ]; then
        subdirs+=("$d")
        echo -e "  \e[36m[$idx]\e[0m $(basename "$d")"
        ((idx++))
      fi
    done

    if [ ${#subdirs[@]} -eq 0 ]; then
      echo -e "\e[33m(Tidak ada sub-folder di direktori ini)\e[0m"
    fi

    echo -e "--------------------------------------"
    echo -e "Ketik nomor folder untuk memilih,"
    echo -e "Atau 'y' untuk menjadikan direktori saat ini sebagai project,"
    echo -e "Atau 'b' untuk kembali."
    read -p "Pilihan Anda: " input_choice

    if [[ "$input_choice" =~ ^[Yy]$ ]]; then
      selected_project_dir="$current_dir"
      break
    elif [[ "$input_choice" =~ ^[Bb]$ ]]; then
      return
    elif [[ "$input_choice" =~ ^[0-9]+$ ]] && [ "$input_choice" -ge 1 ] && [ "$input_choice" -le "${#subdirs[@]}" ]; then
      local chosen_folder="${subdirs[$((input_choice-1))]}"
      chosen_folder="${chosen_folder%/}"
      echo -e "Folder dipilih: \e[32m$(basename "$chosen_folder")\e[0m"
      read -p "Buka folder ini (n) atau tentukan sebagai folder project (y)? [n/y]: " confirm_choice
      if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        selected_project_dir="$chosen_folder"
        break
      else
        current_dir="$chosen_folder"
      fi
    else
      echo -e "\e[31m❌ Pilihan tidak valid!\e[0m"
      sleep 1
    fi
  done

  select_gemini_model "$selected_project_dir"
}

linux_menu() {
  while true; do
    clear
    echo -e "\e[1;36m======================================\e[0m"
    echo -e "\e[1;33m              MENU LINUX              \e[0m"
    echo -e "\e[1;36m======================================\e[0m"
    echo -e "  \e[36m[1]\e[0m Buka Linux (proot-distro login debian)"
    echo -e "  \e[36m[2]\e[0m Coding (Aider Gemini)"
    echo -e "  \e[36m[3]\e[0m Kembali ke Menu Utama"
    echo -e "======================================"
    read -p "Pilih opsi [1-3]: " opt_linux

    case "$opt_linux" in
      1)
        echo -e "\e[32m🚀 Membuka proot-distro login debian...\e[0m"
        proot-distro login debian
        read -p "ENTER untuk kembali..."
        ;;
      2)
        coding_menu
        ;;
      3)
        return
        ;;
      *)
        echo -e "\e[31m❌ Pilihan tidak valid!\e[0m"
        sleep 1
        ;;
    esac
  done
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
  echo -e "  \e[36m[3]\e[0m ➤ Linux 🐧"
  echo

  # --- BAGIAN 2: DINAMIS (PILIH DOR) ---
  echo -e "\e[1;36m# TOOL PYTHON\e[0m"
  
  # Array untuk menyimpan nama folder dinamis
  DYN_NAMES=()
  # Counter mulai dari 4 (karena 1, 2, 3 adalah menu tetap)
  n=4

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

  # 2. Cek REPO_LIST barangkali ada repo yang belum ter-scan
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
    3)
      # MENU LINUX
      linux_menu
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
      # LOGIC DINAMIS (4 ke atas)
      if [[ "$pilih" =~ ^[0-9]+$ ]]; then
        # Cek apakah nomor valid (>= 4 dan <= max_option)
        if [ "$pilih" -ge 4 ] && [ "$pilih" -le "$max_option" ]; then
          # Index array dimulai dari 0 (pilihan 4 -> index 0)
          index=$((pilih - 4))
          
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
