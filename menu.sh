#!/bin/bash
# ==========================================
# 🌟 TERMUX MENU BY CORRODEDVOMIT 
# 🙏 EDIT BY MARNEZ (Versi Custom Request)
# ==========================================

REPO_LIST="$HOME/.termux_repos"
CUSTOM_MODELS_FILE="$HOME/.gemini_custom_models"
CUSTOM_TOOLS_FILE="$HOME/.termux_custom_tools"
MENU_TX_DIR="$HOME/MenuTx"

# Pastikan file-file config ada
touch "$REPO_LIST" 2>/dev/null || { echo -e "\e[31m❌ Gagal akses $REPO_LIST\e[0m"; exit 1; }
touch "$CUSTOM_MODELS_FILE" 2>/dev/null || { echo -e "\e[31m❌ Gagal akses $CUSTOM_MODELS_FILE\e[0m"; exit 1; }
touch "$CUSTOM_TOOLS_FILE" 2>/dev/null || { echo -e "\e[31m❌ Gagal akses $CUSTOM_TOOLS_FILE\e[0m"; exit 1; }

# Aktifkan nullglob
shopt -s nullglob

# -------------------------
# Fungsi: Load Custom Tools
# -------------------------
load_custom_tools() {
  CUSTOM_TOOLS_LABELS=()
  CUSTOM_TOOLS_PATHS=()
  if [ -f "$CUSTOM_TOOLS_FILE" ]; then
    while IFS='|' read -r label path; do
      [ -z "$label" ] && continue
      if [ -f "$path" ]; then
        CUSTOM_TOOLS_LABELS+=("$label")
        CUSTOM_TOOLS_PATHS+=("$path")
      fi
    done < "$CUSTOM_TOOLS_FILE"
  fi
}

# -------------------------
# Fungsi: Save Custom Tools
# -------------------------
save_custom_tools() {
  > "$CUSTOM_TOOLS_FILE" # Truncate
  for i in "${!CUSTOM_TOOLS_LABELS[@]}"; do
    echo "${CUSTOM_TOOLS_LABELS[$i]}|${CUSTOM_TOOLS_PATHS[$i]}" >> "$CUSTOM_TOOLS_FILE"
  done
}

# -------------------------
# Fungsi: Tambah Custom Tool (Menu e)
# -------------------------
add_custom_tool() {
  echo
  echo -e "\e[1;33m[ Tambah Script .sh ke Tools MCR ]\e[0m"
  
  if [ ! -d "$MENU_TX_DIR" ]; then
    echo -e "\e[31m❌ Direktori $MENU_TX_DIR tidak ditemukan.\e[0m"
    read -p "ENTER..."
    return
  fi

  local sh_files=()
  local idx=1
  echo -e "Scanning \e[32m$MENU_TX_DIR\e[0m untuk file .sh ..."
  echo
  
  for f in "$MENU_TX_DIR"/*.sh; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    # Cek apakah sudah terdaftar
    skip=false
    for p in "${CUSTOM_TOOLS_PATHS[@]}"; do
      if [ "$p" = "$f" ]; then skip=true; break; fi
    done
    if $skip; then
      echo -e "  \e[90m[$idx] $fname (Sudah terdaftar)\e[0m"
    else
      sh_files+=("$f")
      echo -e "  \e[36m[$idx]\e[0m $fname"
    fi
    ((idx++))
  done

  if [ ${#sh_files[@]} -eq 0 ]; then
    echo -e "\e[33mTidak ada file .sh baru untuk ditambahkan.\e[0m"
    read -p "ENTER..."
    return
  fi

  echo
  read -p "Pilih nomor file untuk ditambahkan (0 batal): " choice
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ] || [ "$choice" -gt ${#sh_files[@]} ]; then
    echo "Batal atau pilihan tidak valid."
    read -p "ENTER..."
    return
  fi

  selected_file="${sh_files[$((choice-1))]}"
  default_label=$(basename "$selected_file" .sh)
  read -p "Label menu (default: $default_label): " label
  label="${label:-$default_label}"

  CUSTOM_TOOLS_LABELS+=("$label")
  CUSTOM_TOOLS_PATHS+=("$selected_file")
  save_custom_tools
  echo -e "\e[32m✅ Ditambahkan: $label -> $selected_file\e[0m"
  read -p "ENTER..."
}

# -------------------------
# Fungsi: Hapus Custom Tool (Menu f)
# -------------------------
delete_custom_tool() {
  if [ ${#CUSTOM_TOOLS_LABELS[@]} -eq 0 ]; then
    echo -e "\e[33mTidak ada custom tools untuk dihapus.\e[0m"
    read -p "ENTER..."
    return
  fi

  echo
  echo -e "\e[1;31m🗑️  HAPUS CUSTOM TOOLS\e[0m"
  echo
  local i=1
  for label in "${CUSTOM_TOOLS_LABELS[@]}"; do
    echo -e "  \e[36m[$i]\e[0m $label (\e[90m${CUSTOM_TOOLS_PATHS[$((i-1))]}\e[0m)"
    ((i++))
  done
  echo
  read -p "Pilih nomor untuk dihapus (0 batal): " choice
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ] || [ "$choice" -gt ${#CUSTOM_TOOLS_LABELS[@]} ]; then
    echo "Batal."
    read -p "ENTER..."
    return
  fi

  idx=$((choice-1))
  removed_label="${CUSTOM_TOOLS_LABELS[$idx]}"
  # Hapus dari array
  CUSTOM_TOOLS_LABELS=("${CUSTOM_TOOLS_LABELS[@]:0:$idx}" "${CUSTOM_TOOLS_LABELS[@]:$((idx+1))}")
  CUSTOM_TOOLS_PATHS=("${CUSTOM_TOOLS_PATHS[@]:0:$idx}" "${CUSTOM_TOOLS_PATHS[@]:$((idx+1))}")
  save_custom_tools
  echo -e "\e[32m✅ Dihapus: $removed_label\e[0m"
  read -p "ENTER..."
}

# -------------------------
# Fungsi: Jalankan Custom Tool
# -------------------------
run_custom_tool() {
  local script_path="$1"
  local label="$2"
  echo -e "\e[90m🚀 Menjalankan $label...\e[0m"
  if [ -f "$script_path" ]; then
    bash "$script_path"
  else
    echo -e "\e[31m❌ File tidak ditemukan: $script_path\e[0m"
  fi
  read -p "ENTER..."
}

# -------------------------
# Fungsi: Optimasi RAM (Static 1)
# -------------------------
do_ram() {
  script_ram="$MENU_TX_DIR/ram.sh"
  if [ ! -f "$script_ram" ]; then script_ram="ram.sh"; fi 
  if [ -f "$script_ram" ]; then
    echo -e "\e[90m🚀 Menjalankan Optimasi RAM...\e[0m"
    bash "$script_ram"
  else
    echo -e "\e[31m❌ File ram.sh tidak ditemukan\e[0m"
  fi
  read -p "ENTER..."
}

# -------------------------
# Fungsi: Jalankan ADB (Static 2)
# -------------------------
do_adb() {
  script_adb="$MENU_TX_DIR/adb.sh"
  if [ ! -f "$script_adb" ]; then script_adb="adb.sh"; fi
  if [ -f "$script_adb" ]; then
    echo -e "\e[90m🚀 Menjalankan ADB...\e[0m"
    bash "$script_adb"
  else
    echo -e "\e[31m❌ File adb.sh tidak ditemukan\e[0m"
  fi
  read -p "ENTER..."
}

# -------------------------
# Fungsi: Menu Linux (Static 3)
# -------------------------
do_linux() {
  linux_menu
}

# -------------------------
# Fungsi: Jalankan Python Tool (Dynamic)
# -------------------------
do_python_tool() {
  local folder="$1"
  if [ -d "$HOME/$folder" ]; then
    cd "$HOME/$folder" || return
    echo -e "\e[90m🚀 Menjalankan $folder (main.py)...\e[0m"
    python main.py
  else
    echo -e "\e[31m❌ Folder tidak ditemukan.\e[0m"
  fi
  read -p "ENTER..."
}

# -------------------------
# Fungsi: Helper Clone (Repo)
# -------------------------
run_or_clone() {
  local folder="$1"
  local repo_url="$2"
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
    if [[ "$yn" =~ ^[Yy]$ ]]; then rm -rf "$HOME/$folder"; else return; fi
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
  entry="$folder|$repo"
  if ! grep -Fxq "$entry" "$REPO_LIST"; then echo "$entry" >> "$REPO_LIST"; fi
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
  [ -z "$input" ] && return
  if [[ "$input" = /* ]]; then folder=$(basename "$input"); else folder="$input"; fi
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
  local list_del=()
  for dir in "$HOME"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    case "$name" in .*) continue ;; esac
    [ -f "$HOME/$name/main.py" ] || continue 
    list_del+=("$name")
  done
  if [ -f "$REPO_LIST" ]; then
    while IFS='|' read -r folder repourl; do
       [ -z "$folder" ] && continue
       skip=false
       for e in "${list_del[@]}"; do [ "$e" = "$folder" ] && skip=true && break; done
       $skip && continue
       if [ -d "$HOME/$folder" ] && [ -f "$HOME/$folder/main.py" ]; then list_del+=("$folder"); fi
    done < "$REPO_LIST"
  fi
  if [ ${#list_del[@]} -eq 0 ]; then echo "Tidak ada folder dengan main.py untuk dihapus."; read -p "ENTER..."; return; fi
  local count=1
  for d in "${list_del[@]}"; do echo "  [$count] $d"; ((count++)); done
  echo
  read -p "Pilih nomor yang akan dihapus: " num
  if [[ ! "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt ${#list_del[@]} ]; then echo "❌ Pilihan tidak valid."; read -p "ENTER..."; return; fi
  target="${list_del[$((num-1))]}"
  read -p "⚠️ Hapus folder '$target' dan datanya? (y/n): " konf
  if [[ "$konf" =~ ^[Yy]$ ]]; then rm -rf "$HOME/$target"; sed -i "/^${target}|/d" "$REPO_LIST" 2>/dev/null || true; echo -e "\e[32m✅ Terhapus.\e[0m"; else echo "Batal."; fi
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
# Fungsi: Load custom models (Gemini)
# -------------------------
load_custom_models() {
  CUSTOM_MODELS=()
  if [ -f "$CUSTOM_MODELS_FILE" ]; then
    while IFS= read -r line; do [ -n "$line" ] && CUSTOM_MODELS+=("$line"); done < "$CUSTOM_MODELS_FILE"
  fi
}
save_custom_models() { printf "%s\n" "${CUSTOM_MODELS[@]}" > "$CUSTOM_MODELS_FILE"; }

add_custom_model() {
  echo; echo -e "\e[1;33m[ Tambah Model Kustom ]\e[0m"; echo -e "\e[33mContoh: openrouter/nvidia/nemotron-3-ultra-550b-a55b:free\e[0m"
  read -p "🌐 Masukkan nama model: " model_name
  model_name="${model_name#"${model_name%%[![:space:]]*}"}"; model_name="${model_name%"${model_name##*[![:space:]]}"}"
  [ -z "$model_name" ] && { echo -e "\e[31m❌ Nama model tidak boleh kosong.\e[0m"; read -p "ENTER..."; return; }
  for model in "${CUSTOM_MODELS[@]}"; do [ "$model" = "$model_name" ] && { echo -e "\e[33m⚠️  Model sudah ada.\e[0m"; read -p "ENTER..."; return; }; done
  CUSTOM_MODELS+=("$model_name"); save_custom_models
  echo -e "\e[32m✅ Model kustom ditambahkan: $model_name\e[0m"; read -p "ENTER untuk kembali..."
}
delete_custom_model() {
  [ ${#CUSTOM_MODELS[@]} -eq 0 ] && { echo -e "\e[33mTidak ada model kustom.\e[0m"; read -p "ENTER..."; return; }
  echo; echo -e "\e[1;31m🗑️  HAPUS MODEL KUSTOM\e[0m"; echo
  local i=1
  for model in "${CUSTOM_MODELS[@]}"; do echo -e "  \e[36m[$((9+i-1))]\e[0m $model"; ((i++)); done
  echo; read -p "Pilih nomor (9-$((${#CUSTOM_MODELS[@]}+8))) (0 batal): " del_num
  [ "$del_num" = "0" ] && { echo -e "\e[33mBatal.\e[0m"; read -p "ENTER..."; return; }
  [[ ! "$del_num" =~ ^[0-9]+$ ]] || [ "$del_num" -lt 9 ] || [ "$del_num" -gt $((${#CUSTOM_MODELS[@]}+8)) ] && { echo -e "\e[31m❌ Pilihan tidak valid.\e[0m"; read -p "ENTER..."; return; }
  custom_index=$((del_num-9)); deleted_model="${CUSTOM_MODELS[$custom_index]}"
  CUSTOM_MODELS=("${CUSTOM_MODELS[@]:0:$custom_index}" "${CUSTOM_MODELS[@]:$((custom_index+1))}"); save_custom_models
  echo -e "\e[32m✅ Model dihapus: $deleted_model\e[0m"; read -p "ENTER..."
}

# -------------------------
# Fungsi: Gemini & Coding
# -------------------------
select_gemini_model() {
  local proj_dir="$1"; load_custom_models
  while true; do
    clear
    echo -e "\e[1;36m======================================\e[0m"; echo -e "\e[1;33m          PILIH MODEL GEMINI          \e[0m"; echo -e "\e[1;36m======================================\e[0m"
    echo -e "Project Directory: \e[32m$proj_dir\e[0m"; echo -e "--------------------------------------"
    echo -e "  \e[36m[1]\e[0m Gemini 3.6 Flash (gemini/gemini-3.6-flash)"
    echo -e "  \e[36m[2]\e[0m Gemini 2.5 Flash (gemini/gemini-2.5-flash)"
    echo -e "  \e[36m[3]\e[0m Gemini 2.5 Pro   (gemini/gemini-2.5-pro)"
    echo -e "  \e[36m[4]\e[0m Gemini 1.5 Flash (gemini/gemini-1.5-flash)"
    echo -e "  \e[36m[5]\e[0m Gemini 1.5 Pro   (gemini/gemini-1.5-pro)"
    echo -e "  \e[36m[6]\e[0m Input Custom Model (Sekali Pakai)"
    echo -e "  \e[36m[7]\e[0m Tambah Model Kustom (Tersimpan)"
    echo -e "  \e[36m[8]\e[0m Hapus Model Kustom"
    if [ ${#CUSTOM_MODELS[@]} -gt 0 ]; then
      echo -e "--------------------------------------"; echo -e "\e[33mModel Kustom Tersimpan:\e[0m"
      local i=1
      for model in "${CUSTOM_MODELS[@]}"; do echo -e "  \e[32m[$((9+i-1))]\e[0m $model"; ((i++)); done
    fi
    echo -e "--------------------------------------"
    local max_opt=$((8+${#CUSTOM_MODELS[@]}))
    read -p "Pilih model Gemini [1-$max_opt]: " m_choice
    local model_name=""
    case "$m_choice" in
      1) model_name="gemini/gemini-3.6-flash" ;; 2) model_name="gemini/gemini-2.5-flash" ;;
      3) model_name="gemini/gemini-2.5-pro" ;; 4) model_name="gemini/gemini-1.5-flash" ;;
      5) model_name="gemini/gemini-1.5-pro" ;;
      6) read -p "Masukkan nama model custom: " custom_m; model_name="$custom_m" ;;
      7) add_custom_model; continue ;;
      8) delete_custom_model; continue ;;
      *) [[ "$m_choice" =~ ^[0-9]+$ ]] && [ "$m_choice" -ge 9 ] && [ "$m_choice" -le $((8+${#CUSTOM_MODELS[@]})) ] && { custom_index=$((m_choice-9)); model_name="${CUSTOM_MODELS[$custom_index]}"; } || { echo -e "\e[33mDefault: gemini/gemini-3.6-flash\e[0m"; model_name="gemini/gemini-3.6-flash"; sleep 1; } ;;
    esac
    [ -z "$model_name" ] && model_name="gemini/gemini-3.6-flash"
    echo -e "\e[36m--------------------------------------\e[0m"; echo -e "\e[32m🚀 Menjalankan Aider di Proot Debian...\e[0m"
    echo -e "Directory : $proj_dir"; echo -e "Model     : $model_name"; echo -e "Perintah  : aider --model $model_name --no-stream"; echo -e "\e[36m--------------------------------------\e[0m"
    proot-distro login debian --work-dir "$proj_dir" -- bash -l -c "
source /root/aider/.venv/bin/activate
cd \"$proj_dir\" 2>/dev/null
export PATH=\$PATH:\$HOME/.local/bin:/root/.local/bin:/usr/local/bin
aider --model '$model_name' --no-stream
"
    read -p "ENTER untuk kembali..."; break
  done
}

coding_menu() {
  local current_dir="/data/data/com.termux/files/home/storage/shared"
  [ ! -d "$current_dir" ] && current_dir="$HOME"
  local selected_project_dir=""
  while true; do
    clear; echo -e "\e[1;36m======================================\e[0m"; echo -e "\e[1;33m          PILIH FOLDER PROJECT        \e[0m"; echo -e "\e[1;36m======================================\e[0m"
    echo -e "Lokasi saat ini: \e[32m$current_dir\e[0m"; echo -e "--------------------------------------"
    local subdirs=(); local idx=1
    for d in "$current_dir"/*/; do [ -d "$d" ] && { subdirs+=("$d"); echo -e "  \e[36m[$idx]\e[0m $(basename "$d")"; ((idx++)); }; done
    [ ${#subdirs[@]} -eq 0 ] && echo -e "\e[33m(Tidak ada sub-folder)\e[0m"
    echo -e "--------------------------------------"
    echo -e "Ketik nomor, 'y' untuk pilih ini, 'b' untuk kembali."
    read -p "Pilihan: " input_choice
    if [[ "$input_choice" =~ ^[Yy]$ ]]; then selected_project_dir="$current_dir"; break
    elif [[ "$input_choice" =~ ^[Bb]$ ]]; then return
    elif [[ "$input_choice" =~ ^[0-9]+$ ]] && [ "$input_choice" -ge 1 ] && [ "$input_choice" -le ${#subdirs[@]} ]; then
      local chosen_folder="${subdirs[$((input_choice-1))]%/}"
      echo -e "Folder: \e[32m$(basename "$chosen_folder")\e[0m"
      read -p "Buka folder (n) atau jadikan project (y)? [n/y]: " confirm_choice
      [[ "$confirm_choice" =~ ^[Yy]$ ]] && { selected_project_dir="$chosen_folder"; break; } || current_dir="$chosen_folder"
    else echo -e "\e[31m❌ Pilihan tidak valid!\e[0m"; sleep 1; fi
  done
  select_gemini_model "$selected_project_dir"
}

linux_menu() {
  while true; do
    clear; echo -e "\e[1;36m======================================\e[0m"; echo -e "\e[1;33m              MENU LINUX              \e[0m"; echo -e "\e[1;36m======================================\e[0m"
    echo -e "  \e[36m[1]\e[0m Buka Linux (proot-distro login debian)"; echo -e "  \e[36m[2]\e[0m Coding (Aider Gemini)"; echo -e "  \e[36m[3]\e[0m Kembali ke Menu Utama"; echo -e "======================================"
    read -p "Pilih [1-3]: " opt_linux
    case "$opt_linux" in
      1) echo -e "\e[32m🚀 Membuka proot-distro login debian...\e[0m"; proot-distro login debian; read -p "ENTER..." ;;
      2) coding_menu ;;
      3) return ;;
      *) echo -e "\e[31m❌ Pilihan tidak valid!\e[0m"; sleep 1 ;;
    esac
  done
}

# ==========================================
# MENU UTAMA
# ==========================================
while true; do
  # 1. Load Data
  load_custom_tools
  
  # 2. Build Menu Arrays
  MENU_LABELS=()
  MENU_ACTIONS=() # Stores function name + args as string for eval
  
  # Static Tools (1, 2, 3)
  MENU_LABELS+=("Optimasi RAM 🧹")
  MENU_ACTIONS+=("do_ram")
  
  MENU_LABELS+=("Jalankan ADB 📵")
  MENU_ACTIONS+=("do_adb")
  
  MENU_LABELS+=("Linux 🐧")
  MENU_ACTIONS+=("do_linux")
  
  # Custom Tools (from ~/.termux_custom_tools)
  for i in "${!CUSTOM_TOOLS_LABELS[@]}"; do
    MENU_LABELS+=("${CUSTOM_TOOLS_LABELS[$i]}")
    # Escape path for eval safety
    safe_path=$(printf "%q" "${CUSTOM_TOOLS_PATHS[$i]}")
    MENU_ACTIONS+=("run_custom_tool $safe_path \"${CUSTOM_TOOLS_LABELS[$i]}\"")
  done
  
  # Python Tools (Dynamic scan main.py)
  PY_TOOLS_FOLDERS=()
  for dir in "$HOME"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    case "$name" in .*) continue ;; esac
    if [ -f "$HOME/$name/main.py" ]; then
      PY_TOOLS_FOLDERS+=("$name")
    fi
  done
  # Check REPO_LIST for missing ones
  if [ -f "$REPO_LIST" ]; then
    while IFS='|' read -r folder repourl; do
      [ -z "$folder" ] && continue
      skip=false
      for e in "${PY_TOOLS_FOLDERS[@]}"; do [ "$e" = "$folder" ] && skip=true && break; done
      $skip && continue
      [ -d "$HOME/$folder" ] && [ -f "$HOME/$folder/main.py" ] && PY_TOOLS_FOLDERS+=("$folder")
    done < "$REPO_LIST"
  fi
  
  for folder in "${PY_TOOLS_FOLDERS[@]}"; do
    MENU_LABELS+=("$folder (Python)")
    safe_folder=$(printf "%q" "$folder")
    MENU_ACTIONS+=("do_python_tool $safe_folder")
  done

  # 3. Display Menu
  clear
  echo -e "\e[1;36m╔═══════════════════════════════════════════╗\e[0m"
  echo -e "\e[1;36m║\e[0m             🔥 \e[1;33mMARNEZ TOOLS\e[0m 🔥            \e[1;36m║\e[0m"
  echo -e "\e[1;36m╚═══════════════════════════════════════════╝\e[0m"
  
  echo -e "\e[1;33m# TOOLS MCR & PYTHON\e[0m"
  idx=1
  for label in "${MENU_LABELS[@]}"; do
    printf "  \e[32m[%d]\e[0m ➤ %s\n" "$idx" "$label"
    ((idx++))
  done
  
  max_option=$((idx-1))
  
  echo
  echo -e "  \e[36m----------------------------------------\e[0m"
  echo -e "  \e[33m[a]\e[0m Repo baru      \e[33m[e]\e[0m Tambah .sh ke Tools"
  echo -e "  \e[33m[b]\e[0m Repo manual    \e[33m[f]\e[0m Hapus .sh dari Tools"
  echo -e "  \e[33m[c]\e[0m Hapus repo     \e[36m[x]\e[0m KELUAR MENU"
  echo -e "  \e[33m[d]\e[0m Update repo    \e[36m[q]\e[0m KELUAR TERMUX"
  echo -e "  \e[36m----------------------------------------\e[0m"
  
  read -p "Masukkan pilihan: " pilih

  # 4. Dispatch
  case "$pilih" in
    a|A) add_new_repo ;;
    b|B) add_manual_repo ;;
    c|C) delete_repo ;;
    d|D) update_repo ;;
    e|E) add_custom_tool ;;
    f|F) delete_custom_tool ;;
    x|X) echo -e "\e[36mKeluar menu...\e[0m"; break ;;
    q|Q) echo -e "\e[31mBye bye!\e[0m"; exit 0 ;;
    *)
      if [[ "$pilih" =~ ^[0-9]+$ ]] && [ "$pilih" -ge 1 ] && [ "$pilih" -le "$max_option" ]; then
        action_index=$((pilih-1))
        action_cmd="${MENU_ACTIONS[$action_index]}"
        eval "$action_cmd"
      else
        echo -e "\e[31m❌ Pilihan tidak ada.\e[0m"
        read -p "ENTER..."
      fi
      ;;
  esac
done
