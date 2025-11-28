#!/bin/bash
# ==========================================
# 🌟 TERMUX MENU BY CORRODEDVOMIT 
# 🙏 EDIT BY MARNEZ (perbaikan lengkap)
# ==========================================

REPO_LIST="$HOME/.termux_repos"

# Pastikan REPO_LIST ada
touch "$REPO_LIST" 2>/dev/null || {
  echo -e "\e[31m❌ Gagal membuat atau mengakses $REPO_LIST\e[0m"
  exit 1
}

# Aktifkan nullglob agar loop tidak memproses literal jika tidak ada folder
shopt -s nullglob

# -------------------------
# Fungsi: Jalankan atau clone jika belum ada
# -------------------------
run_or_clone() {
  local folder="$1"
  local repo_url="$2"

  cd "$HOME" || { echo -e "\e[31m❌ Gagal akses $HOME\e[0m"; return; }

  if [ ! -d "$HOME/$folder" ]; then
    echo -e "\e[33m🔍 Folder $folder belum ada, cloning dari $repo_url ...\e[0m"
    if ! git clone "$repo_url" "$HOME/$folder"; then
      echo -e "\e[31m❌ Gagal clone repo $repo_url\e[0m"
      read -p "ENTER untuk kembali..."
      return
    fi

    # Jalankan setup.sh jika ada
    if [ -f "$HOME/$folder/setup.sh" ]; then
      echo -e "\e[36m🛠 Menjalankan setup.sh (hanya pertama kali)...\e[0m"
      (cd "$HOME/$folder" && bash setup.sh) || echo -e "\e[31m❌ setup.sh gagal dijalankan.\e[0m"
    fi
  fi

  cd "$HOME/$folder" || {
    echo -e "\e[31m❌ Gagal masuk ke folder $folder\e[0m"
    read -p "ENTER..."
    return
  }

  if [ -f "main.py" ]; then
    echo -e "\e[90m🚀 Menjalankan: python main.py\e[0m"
    python main.py
  else
    echo -e "\e[31m❌ File main.py tidak ditemukan di $folder\e[0m"
  fi

  read -p "ENTER untuk kembali ke menu..."
}

# -------------------------
# Fungsi: Tambah Repo baru + langsung clone & setup (dengan sanitasi input)
# -------------------------
add_new_repo() {
  echo
  read -p "🌐 Masukkan URL Git repo: " repo_raw
  # Trim leading/trailing spaces
  repo_raw="${repo_raw#"${repo_raw%%[![:space:]]*}"}"
  repo_raw="${repo_raw%"${repo_raw##*[![:space:]]}"}"

  # Hapus awalan "git clone " atau "git "
  repo="${repo_raw#git clone }"
  repo="${repo#git clone}"
  repo="${repo#git }"

  # Hapus tanda kutip jika ada
  repo="${repo%\"}"
  repo="${repo#\"}"
  repo="${repo%\'}"
  repo="${repo#\'}"

  # Hapus trailing slash
  repo="${repo%/}"

  # Validasi sederhana: harus mulai dengan http(s) atau git@
  if [[ -z "$repo" ]] || ! [[ "$repo" =~ ^(https?://|git@) ]]; then
    echo -e "\e[31m❌ URL repo tidak valid. Masukkan URL seperti https://github.com/user/repo.git atau git@github.com:user/repo.git\e[0m"
    read -p "ENTER..."
    return
  fi

  folder=$(basename "$repo" .git)
  if [ -z "$folder" ]; then
    echo -e "\e[31m❌ Gagal menentukan nama folder dari URL.\e[0m"
    read -p "ENTER..."
    return
  fi

  echo -e "\e[33m🔍 Meng-clone repo '$folder' dari $repo ...\e[0m"

  # Hapus folder lama kalau ada (konfirmasi)
  if [ -d "$HOME/$folder" ]; then
    read -p "Folder $folder sudah ada. Hapus dan lanjut clone? (y/n): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      rm -rf "$HOME/$folder"
    else
      echo "Dibatalkan."
      read -p "ENTER..."
      return
    fi
  fi

  # Clone repo
  if ! git clone "$repo" "$HOME/$folder"; then
    echo -e "\e[31m❌ Gagal clone repo $repo\e[0m"
    read -p "ENTER..."
    return
  fi

  # Jalankan setup.sh jika ada
  if [ -f "$HOME/$folder/setup.sh" ]; then
    echo -e "\e[36m🛠 Menjalankan setup.sh...\e[0m"
    (cd "$HOME/$folder" && bash setup.sh) || echo -e "\e[31m❌ setup.sh gagal dijalankan.\e[0m"
  fi

  # Jalankan main.py jika ada
  if [ -f "$HOME/$folder/main.py" ]; then
    echo -e "\e[90m🚀 Menjalankan: python main.py\e[0m"
    (cd "$HOME/$folder" && python main.py)
  fi

  # Tambah ke REPO_LIST jika belum ada
  entry="$folder|$repo"
  if ! grep -Fxq "$entry" "$REPO_LIST"; then
    echo "$entry" >> "$REPO_LIST"
  fi

  echo -e "\e[32m✅ Repo '$folder' berhasil ditambahkan, di-setup, dan dijalankan!\e[0m"
  read -p "ENTER untuk kembali ke menu..."
}

# -------------------------
# Fungsi: Tambah manual repo (register folder lokal ke REPO_LIST)
# -------------------------
add_manual_repo() {
  echo
  read -p "📁 Masukkan nama folder atau path folder (contoh: XWan atau /data/data/com.termux/files/home/XWan): " input
  # trim sederhana
  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"
  [ -z "$input" ] && echo "❌ Input kosong." && read -p "ENTER..." && return

  # Jika user memasukkan path absolut, ambil basename sebagai folder
  if [[ "$input" = /* ]]; then
    folder=$(basename "$input")
    path="$input"
  else
    folder="$input"
    path="$HOME/$folder"
  fi

  if [ ! -d "$path" ]; then
    echo -e "\e[31m❌ Folder '$path' tidak ditemukan.\e[0m"
    read -p "ENTER..."
    return
  fi

  if [ ! -f "$path/main.py" ]; then
    echo -e "\e[33m⚠️  Tidak ditemukan main.py di '$path'. Menu biasanya menampilkan folder yang memiliki main.py.\e[0m"
    read -p "Lanjut mendaftarkan folder tanpa main.py? (y/n): " yn
    if [[ ! "$yn" =~ ^[Yy]$ ]]; then
      echo "Dibatalkan."
      read -p "ENTER..."
      return
    fi
  fi

  # Jika REPO_LIST belum ada, buat
  touch "$REPO_LIST" 2>/dev/null || { echo -e "\e[31m❌ Gagal akses $REPO_LIST\e[0m"; read -p "ENTER..."; return; }

  # Jika folder sudah ada di REPO_LIST, jangan duplikat
  if grep -Fq "^$folder|" "$REPO_LIST"; then
    echo -e "\e[33m⚠️  Folder '$folder' sudah terdaftar di $REPO_LIST.\e[0m"
    read -p "ENTER..."
    return
  fi

  # Simpan entry; gunakan placeholder 'manual' untuk URL
  echo "$folder|manual" >> "$REPO_LIST"
  echo -e "\e[32m✅ Folder '$folder' berhasil didaftarkan ke menu.\e[0m"
  read -p "ENTER untuk kembali ke menu..."
}

# -------------------------
# Fungsi: Hapus Repo
# -------------------------
delete_repo() {
  echo
  echo -e "\e[1;31m🗑️  Hapus Repository dari menu:\e[0m"
  echo
  dirs=()
  for d in "$HOME"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    dirs+=("$name")
  done
  IFS=$'\n' sorted=($(sort <<<"${dirs[*]}"))
  unset IFS

  if [ ${#sorted[@]} -eq 0 ]; then
    echo "Tidak ada folder yang bisa dihapus."
    read -p "ENTER..."
    return
  fi

  i=1
  for d in "${sorted[@]}"; do
    echo "  [$i] $d"
    ((i++))
  done

  echo
  read -p "Pilih nomor folder yang ingin dihapus: " num
  [[ ! "$num" =~ ^[0-9]+$ ]] && echo "❌ Pilihan tidak valid." && read -p "ENTER..." && return
  [[ $num -lt 1 || $num -gt ${#sorted[@]} ]] && echo "❌ Nomor di luar jangkauan." && read -p "ENTER..." && return

  target="${sorted[$((num-1))]}"
  echo
  read -p "⚠️ Yakin ingin menghapus folder '$target'? (y/n): " konfirm
  if [[ "$konfirm" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/$target"
    # Hapus dari REPO_LIST jika ada entri terkait
    sed -i "/^${target}|/d" "$REPO_LIST" 2>/dev/null || true
    echo -e "\e[32m✅ Folder '$target' berhasil dihapus.\e[0m"
  else
    echo "Dibatalkan."
  fi
  read -p "ENTER untuk kembali ke menu..."
}

# -------------------------
# Fungsi: Update semua repo
# -------------------------
update_repo() {
  echo -e "\n\e[36m🔄 Memperbarui semua repo Git di menu...\e[0m"
  for dir in "$HOME"/*/; do
    [ -d "$dir" ] || continue
    # pastikan ini repo git
    if [ -d "${dir}.git" ] || [ -d "$dir/.git" ]; then
      echo -e "\n\e[33m📦 Memperbarui $(basename "$dir")...\e[0m"
      (cd "$dir" && git pull --rebase) || echo -e "\e[31m❌ Gagal update $(basename "$dir")\e[0m"
    fi
  done
  echo -e "\n\e[32m✅ Semua repo selesai diperbarui!\e[0m"
  read -p "ENTER untuk kembali ke menu..."
}

# -------------------------
# Menu Utama repo
# -------------------------
while true; do
  clear
  echo -e "\e[1;36m╔════════════════════════════════════════════════╗\e[0m"
  echo -e "\e[1;36m║\e[0m             🔥 \e[1;33mMARNEZ MOD MENU TERMUX\e[0m 🔥         \e[1;36m║\e[0m"
  echo -e "\e[1;36m║\e[0m                 \e[90mBY MARNEZ CREATION\e[0m             \e[1;36m║\e[0m"
  echo -e "\e[1;36m╚════════════════════════════════════════════════╝\e[0m"
  echo
  echo -e "\e[1;33m📂 💉 PILIH DOR SESUAI KEBUTUHAN 🔐:\e[0m"

  echo -e "  \e[33m[1]\e[0m ➤ Jalankan anomali-xl"
  echo -e "  \e[33m[2]\e[0m ➤ Jalankan me-cli"
  echo -e "  \e[33m[3]\e[0m ➤ Jalankan xldor"
  echo -e "  \e[33m[4]\e[0m ➤ Jalankan dor8"
  echo -e "  \e[33m[5]\e[0m ➤ Jalankan reedem"
  echo
  echo -e "\e[1;36m☣️ MARNEZ TOOLS ☣️\e[0m"
  echo -e "  \e[36m[6]\e[0m ➤ Jalankan RISK ☠️"
  echo -e "  \e[36m[7]\e[0m ➤ Jalankan adb 📵"
  echo -e "  \e[36m[8]\e[0m ➤ Optimasi Ram 🧹"

  EXCLUDE_SET=" anomali-xl me-cli xldor dor8 reedem "
  DYN_NAMES=()
  n=9

  # 1) Scan folder di $HOME
  for dir in "$HOME"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    case "$name" in .*) continue ;; esac
    [[ " $EXCLUDE_SET " == *" $name "* ]] && continue
    [ -f "$HOME/$name/main.py" ] || continue
    DYN_NAMES+=("$name")
    printf "  \e[32m[%d]\e[0m ➤ Jalankan %s\n" "$n" "$name"
    n=$((n+1))
  done

  # 2) Tambahkan entri dari REPO_LIST jika belum ada di DYN_NAMES
  if [ -f "$REPO_LIST" ]; then
    while IFS='|' read -r folder repourl; do
      [ -z "$folder" ] && continue
      # skip jika sudah ada di DYN_NAMES
      skip=false
      for e in "${DYN_NAMES[@]}"; do
        if [ "$e" = "$folder" ]; then skip=true; break; fi
      done
      $skip && continue
      # tampilkan hanya jika folder ada dan memiliki main.py
      if [ -d "$HOME/$folder" ] && [ -f "$HOME/$folder/main.py" ]; then
        DYN_NAMES+=("$folder")
        printf "  \e[32m[%d]\e[0m ➤ Jalankan %s\n" "$n" "$folder"
        n=$((n+1))
      fi
    done < "$REPO_LIST"
  fi

  echo
  max_option=$((n-1))
  echo -e "  \e[33m[a]\e[0m ➤ Tambah repo baru (clone)"
  echo -e "  \e[33m[r]\e[0m ➤ Tambah repo manual (register folder lokal)"
  echo -e "  \e[33m[d]\e[0m ➤ Hapus repo dari menu"
  echo -e "  \e[33m[u]\e[0m ➤ Update semua repo"
  echo -e "  \e[33m[m]\e[0m ➤ Keluar menu (masuk shell biasa)"
  echo -e "  \e[36m[q]\e[0m ➤ Keluar Termux"
  echo

  read -p "Masukkan pilihan [1-${max_option}/a/r/d/u/m/q]: " pilih

  case "$pilih" in
    1) run_or_clone "anomali-xl" "https://saus.gemail.ink/anomali/anomali-xl.git" ;;
    2) run_or_clone "me-cli" "https://github.com/purplemashu/me-cli.git" ;;
    3) run_or_clone "xldor" "https://github.com/baloenk/xldor.git" ;;
    4) run_or_clone "dor8" "https://github.com/barbexid/dor8.git" ;;
    5) run_or_clone "reedem" "https://github.com/kejuashuejia/reedem.git" ;;
    6)
      echo -e "\e[90m🚀 Menjalankan: su -c risk\e[0m"
      su -c risk
      read -p "ENTER untuk kembali ke menu..."
      ;;
    7)
      if [ -f "$HOME/MenuTx/adb.sh" ]; then
        echo -e "\e[90m🚀 Menjalankan: ./adb.sh\e[0m"
        bash "$HOME/MenuTx/adb.sh"
      else
        echo -e "\e[31m❌ File adb.sh tidak ditemukan di $HOME/MenuTx\e[0m"
      fi
      read -p "ENTER untuk kembali ke menu..."
      ;;
    8)
      if [ -f "$HOME/MenuTx/ram.sh" ]; then
        echo -e "\e[90m🚀 Menjalankan: ./ram.sh\e[0m"
        bash "$HOME/MenuTx/ram.sh"
      else
        echo -e "\e[31m❌ File ram.sh tidak ditemukan di $HOME/MenuTx\e[0m"
      fi
      read -p "ENTER untuk kembali ke menu..."
      ;;
    a|A) add_new_repo ;;
    r|R) add_manual_repo ;;
    d|D) delete_repo ;;
    u|U) update_repo ;;
    m|M)
      echo -e "\n\e[36mKeluar dari menu. Berjalan di shell biasa! 🧑‍💻\e[0m"
      break
      ;;
    q|Q)
      echo -e "\n\e[31mMenutup Termux... sampai jumpa! 👋\e[0m"
      exit 0
      ;;
    *)
      # Jika input numerik, coba jalankan dynamic entry
      if [[ "$pilih" =~ ^[0-9]+$ ]]; then
        if [ "$pilih" -ge 9 ] && [ "$pilih" -le "$max_option" ]; then
          index=$((pilih - 9))
          if [ $index -ge 0 ] && [ $index -lt ${#DYN_NAMES[@]} ]; then
            cd "$HOME/${DYN_NAMES[$index]}" || {
              echo -e "\e[31m❌ Gagal masuk folder.\e[0m"
              read -p "ENTER..."
              continue
            }
            echo -e "\e[90mMenjalankan: python main.py\e[0m"
            python main.py
            read -p "ENTER untuk kembali ke menu..."
          else
            echo -e "\e[31m❌ Nomor tidak valid.\e[0m"
            read -p "ENTER..."
          fi
        else
          echo -e "\e[31m❌ Nomor tidak valid.\e[0m"
          read -p "ENTER..."
        fi
      else
        echo -e "\e[31m❌ Pilihan tidak dikenali.\e[0m"
        read -p "ENTER untuk kembali ke menu..."
      fi
      ;;
  esac
done
