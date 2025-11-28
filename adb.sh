#!/data/data/com.termux/files/usr/bin/bash

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Menu Termux-ADB
clear
echo -e "${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}    MENU TERMUX ADB WIFI (BY MARNEZ)     ${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}\n"
# Direktori default untuk mencari file .apk
APK_DIR="/storage/emulated/0"

# Direktori sementara untuk menyimpan file .apk yang di-pull
TMP_DIR="/data/data/com.termux/files/home/tmp"

# Buat direktori sementara jika belum ada
mkdir -p "$TMP_DIR"

# Periksa izin penyimpanan untuk Termux
if [ ! -d "/storage/emulated/0" ]; then
    echo "Peringatan: Akses ke /storage/emulated/0 tidak tersedia. Jalankan 'termux-setup-storage' untuk memberikan izin."
    echo -n "Tekan Enter untuk melanjutkan..."
    read
fi

while true; do
    echo "1. Aktifkan server ADB"
    echo "2. Sambung ADB via WiFi"
    echo "3. Matikan server ADB"
    echo "4. List perangkat ADB"
    echo "5. Hapus aplikasi"
    echo "6. Hapus aplikasi sistem"
    echo "7. Bersihkan RAM"
    echo "8. Install aplikasi"
    echo "0. Keluar"
    echo -n "Pilih opsi: "
    read choice

    case $choice in
        1)
            echo "Mengaktifkan server ADB..."
            termux-adb start-server
            echo "Server ADB aktif."
            ;;
        2)
            echo -n "Masukkan IP lokal (port otomatis 5555): "
            read ip
            if [ -n "$ip" ]; then
                echo "Menyambung ke $ip:5555..."
                termux-adb connect $ip:5555
            else
                echo "IP tidak valid!"
            fi
            ;;
        3)
            echo "Mematikan server ADB..."
            termux-adb kill-server
            echo "Server ADB dimatikan."
            ;;
        4)
            echo "Daftar perangkat ADB:"
            termux-adb devices -l
            ;;
        5)
            echo "Mengambil daftar aplikasi yang terinstall..."
            packages=$(termux-adb shell pm list packages -3 | cut -d':' -f2)
            if [ -z "$packages" ]; then
                echo "Tidak ada aplikasi pihak ketiga yang terinstall."
            else
                echo "Daftar aplikasi:"
                IFS=$'\n' read -d '' -r -a pkg_array <<< "$packages"
                for i in "${!pkg_array[@]}"; do
                    echo "$((i+1)). ${pkg_array[i]}"
                done
                echo -n "Pilih nomor aplikasi untuk dihapus (0 untuk batal): "
                read app_choice
                if [ "$app_choice" -gt 0 ] && [ "$app_choice" -le "${#pkg_array[@]}" ]; then
                    selected_pkg=${pkg_array[$((app_choice-1))]}
                    echo "Menghapus aplikasi $selected_pkg..."
                    termux-adb shell pm uninstall "$selected_pkg"
                    echo "Aplikasi berhasil dihapus."
                else
                    echo "Pilihan tidak valid atau dibatalkan."
                fi
            fi
            ;;
        6)
            echo "Mengambil daftar aplikasi sistem..."
            packages=$(termux-adb shell pm list packages -s | cut -d':' -f2)
            if [ -z "$packages" ]; then
                echo "Tidak ada aplikasi sistem yang ditemukan."
            else
                echo "Daftar aplikasi sistem:"
                IFS=$'\n' read -d '' -r -a pkg_array <<< "$packages"
                for i in "${!pkg_array[@]}"; do
                    echo "$((i+1)). ${pkg_array[i]}"
                done
                echo -n "Pilih nomor aplikasi sistem untuk dihapus (0 untuk batal): "
                read app_choice
                if [ "$app_choice" -gt 0 ] && [ "$app_choice" -le "${#pkg_array[@]}" ]; then
                    selected_pkg=${pkg_array[$((app_choice-1))]}
                    echo "Pilih metode penghapusan:"
                    echo "1. Tanpa root (pm uninstall -k --user 0)"
                    echo "2. Dengan root (su -c pm uninstall)"
                    echo -n "Pilih metode (1 atau 2): "
                    read root_choice
                    case $root_choice in
                        1)
                            echo "Menghapus aplikasi sistem $selected_pkg tanpa root..."
                            termux-adb shell pm uninstall -k --user 0 "$selected_pkg"
                            echo "Aplikasi sistem berhasil dihapus (atau gagal jika dilindungi sistem)."
                            ;;
                        2)
                            echo "Menghapus aplikasi sistem $selected_pkg dengan root..."
                            termux-adb shell su -c "pm uninstall -k --user 0 $selected_pkg"
                            echo "Aplikasi sistem berhasil dihapus (atau gagal jika tidak ada akses root)."
                            ;;
                        *)
                            echo "Pilihan metode tidak valid!"
                            ;;
                    esac
                else
                    echo "Pilihan aplikasi tidak valid atau dibatalkan."
                fi
            fi
            ;;
        7)
            echo "Membersihkan RAM (menghentikan semua aplikasi pihak ketiga)..."
            packages=$(termux-adb shell pm list packages -3 | cut -d':' -f2)
            if [ -z "$packages" ]; then
                echo "Tidak ada aplikasi pihak ketiga yang berjalan."
            else
                for pkg in $packages; do
                    termux-adb shell am force-stop "$pkg"
                done
                echo "RAM dibersihkan (semua aplikasi pihak ketiga dihentikan)."
            fi
            ;;
        8)
            echo "Pilih sumber penyimpanan untuk file .apk:"
            echo "1. Perangkat (via ADB)"
            echo "2. Penyimpanan lokal"
            echo -n "Pilih sumber (1 atau 2): "
            read storage_choice
            case $storage_choice in
                1)
                    # Ambil daftar perangkat ADB
                    devices=$(termux-adb devices | grep -w device | awk '{print $1}')
                    if [ -z "$devices" ]; then
                        echo "Tidak ada perangkat ADB yang terhubung. Pastikan perangkat terdeteksi dengan 'termux-adb devices'."
                    else
                        echo "Daftar perangkat ADB:"
                        IFS=$'\n' read -d '' -r -a device_array <<< "$devices"
                        for i in "${!device_array[@]}"; do
                            echo "$((i+1)). ${device_array[i]}"
                        done
                        echo -n "Pilih nomor perangkat (0 untuk batal): "
                        read device_choice
                        if [ "$device_choice" -gt 0 ] && [ "$device_choice" -le "${#device_array[@]}" ]; then
                            selected_device=${device_array[$((device_choice-1))]}
                            echo -n "Cari file .apk di subdirektori $APK_DIR? (y/n): "
                            read subdir_choice
                            if [ "$subdir_choice" = "y" ] || [ "$subdir_choice" = "Y" ]; then
                                echo "Mengambil daftar file .apk dari perangkat $selected_device di $APK_DIR (termasuk subdirektori)..."
                                apk_files=$(termux-adb -s "$selected_device" shell find "$APK_DIR" -type f -name "*.apk" 2>/dev/null)
                            else
                                echo "Mengambil daftar file .apk dari perangkat $selected_device di $APK_DIR (hanya direktori utama)..."
                                apk_files=$(termux-adb -s "$selected_device" shell ls "$APK_DIR"/*.apk 2>/dev/null)
                            fi
                            if [ -z "$apk_files" ]; then
                                echo "Tidak ada file .apk ditemukan di $APK_DIR."
                                echo -n "Apakah Anda ingin memasukkan direktori alternatif? (y/n): "
                                read alt_dir_choice
                                if [ "$alt_dir_choice" = "y" ] || [ "$alt_dir_choice" = "Y" ]; then
                                    echo -n "Masukkan direktori (contoh: /storage/emulated/0/Download): "
                                    read alt_dir
                                    if [ -n "$alt_dir" ]; then
                                        echo -n "Cari file .apk di subdirektori $alt_dir? (y/n): "
                                        read alt_subdir_choice
                                        if [ "$alt_subdir_choice" = "y" ] || [ "$alt_subdir_choice" = "Y" ]; then
                                            apk_files=$(termux-adb -s "$selected_device" shell find "$alt_dir" -type f -name "*.apk" 2>/dev/null)
                                        else
                                            apk_files=$(termux-adb -s "$selected_device" shell ls "$alt_dir"/*.apk 2>/dev/null)
                                        fi
                                        if [ -z "$apk_files" ]; then
                                            echo "Tidak ada file .apk ditemukan di $alt_dir."
                                            echo "Coba jalankan 'termux-adb -s $selected_device shell ls $alt_dir' untuk memeriksa."
                                        else
                                            echo "Daftar file .apk di $alt_dir:"
                                            IFS=$'\n' read -d '' -r -a apk_array <<< "$apk_files"
                                            for i in "${!apk_array[@]}"; do
                                                echo "$((i+1)). ${apk_array[i]}"
                                            done
                                            echo -n "Pilih nomor file .apk untuk diinstall (0 untuk batal): "
                                            read apk_choice
                                            if [ "$apk_choice" -gt 0 ] && [ "$apk_choice" -le "${#apk_array[@]}" ]; then
                                                selected_apk=${apk_array[$((apk_choice-1))]}
                                                # Tarik file .apk ke direktori sementara
                                                apk_filename=$(basename "$selected_apk")
                                                local_apk_path="$TMP_DIR/$apk_filename"
                                                echo "Menarik $selected_apk ke $local_apk_path..."
                                                termux-adb -s "$selected_device" pull "$selected_apk" "$local_apk_path" 2>/dev/null
                                                if [ -f "$local_apk_path" ]; then
                                                    echo "Menginstall $local_apk_path ke $selected_device..."
                                                    termux-adb -s "$selected_device" install "$local_apk_path"
                                                    echo "Aplikasi berhasil diinstall (atau gagal jika file tidak valid)."
                                                    # Hapus file sementara setelah instalasi
                                                    rm -f "$local_apk_path"
                                                else
                                                    echo "Gagal menarik file $selected_apk. Pastikan file dapat diakses."
                                                    echo "Coba jalankan 'termux-adb -s $selected_device pull $selected_apk' untuk memeriksa."
                                                fi
                                            else
                                                echo "Pilihan tidak valid atau dibatalkan."
                                            fi
                                        fi
                                    else
                                        echo "Direktori tidak valid atau dibatalkan."
                                    fi
                                else
                                    echo "Coba jalankan 'termux-adb -s $selected_device shell ls $APK_DIR' untuk memeriksa."
                                fi
                            else
                                echo "Daftar file .apk:"
                                IFS=$'\n' read -d '' -r -a apk_array <<< "$apk_files"
                                for i in "${!apk_array[@]}"; do
                                    echo "$((i+1)). ${apk_array[i]}"
                                done
                                echo -n "Pilih nomor file .apk untuk diinstall (0 untuk batal): "
                                read apk_choice
                                if [ "$apk_choice" -gt 0 ] && [ "$apk_choice" -le "${#apk_array[@]}" ]; then
                                    selected_apk=${apk_array[$((apk_choice-1))]}
                                    # Tarik file .apk ke direktori sementara
                                    apk_filename=$(basename "$selected_apk")
                                    local_apk_path="$TMP_DIR/$apk_filename"
                                    echo "Menarik $selected_apk ke $local_apk_path..."
                                    termux-adb -s "$selected_device" pull "$selected_apk" "$local_apk_path" 2>/dev/null
                                    if [ -f "$local_apk_path" ]; then
                                        echo "Menginstall $local_apk_path ke $selected_device..."
                                        termux-adb -s "$selected_device" install "$local_apk_path"
                                        echo "Aplikasi berhasil diinstall (atau gagal jika file tidak valid)."
                                        # Hapus file sementara setelah instalasi
                                        rm -f "$local_apk_path"
                                    else
                                        echo "Gagal menarik file $selected_apk. Pastikan file dapat diakses."
                                        echo "Coba jalankan 'termux-adb -s $selected_device pull $selected_apk' untuk memeriksa."
                                    fi
                                else
                                    echo "Pilihan tidak valid atau dibatalkan."
                                fi
                            fi
                        else
                            echo "Pilihan perangkat tidak valid atau dibatalkan."
                        fi
                    fi
                    ;;
                2)
                    echo -n "Cari file .apk di subdirektori $APK_DIR? (y/n): "
                    read subdir_choice
                    if [ "$subdir_choice" = "y" ] || [ "$subdir_choice" = "Y" ]; then
                        echo "Mengambil daftar file .apk dari penyimpanan lokal ($APK_DIR, termasuk subdirektori)..."
                        apk_files=$(find "$APK_DIR" -type f -name "*.apk" 2>/dev/null)
                    else
                        echo "Mengambil daftar file .apk dari penyimpanan lokal ($APK_DIR, hanya direktori utama)..."
                        apk_files=$(ls "$APK_DIR"/*.apk 2>/dev/null)
                    fi
                    if [ -z "$apk_files" ]; then
                        echo "Tidak ada file .apk ditemukan di $APK_DIR."
                        echo -n "Apakah Anda ingin memasukkan direktori alternatif? (y/n): "
                        read alt_dir_choice
                        if [ "$alt_dir_choice" = "y" ] || [ "$alt_dir_choice" = "Y" ]; then
                            echo -n "Masukkan direktori (contoh: /storage/emulated/0/Download): "
                            read alt_dir
                            if [ -n "$alt_dir" ]; then
                                echo -n "Cari file .apk di subdirektori $alt_dir? (y/n): "
                                read alt_subdir_choice
                                if [ "$alt_subdir_choice" = "y" ] || [ "$alt_subdir_choice" = "Y" ]; then
                                    apk_files=$(find "$alt_dir" -type f -name "*.apk" 2>/dev/null)
                                else
                                    apk_files=$(ls "$alt_dir"/*.apk 2>/dev/null)
                                fi
                                if [ -z "$apk_files" ]; then
                                    echo "Tidak ada file .apk ditemukan di $alt_dir."
                                    echo "Coba jalankan 'ls $alt_dir' untuk memeriksa."
                                else
                                    echo "Daftar file .apk di $alt_dir:"
                                    IFS=$'\n' read -d '' -r -a apk_array <<< "$apk_files"
                                    for i in "${!apk_array[@]}"; do
                                        echo "$((i+1)). ${apk_array[i]}"
                                    done
                                    echo -n "Pilih nomor file .apk untuk diinstall (0 untuk batal): "
                                    read apk_choice
                                    if [ "$apk_choice" -gt 0 ] && [ "$apk_choice" -le "${#apk_array[@]}" ]; then
                                        selected_apk=${apk_array[$((apk_choice-1))]}
                                        echo "Menginstall $selected_apk ke perangkat yang terhubung..."
                                        termux-adb install "$selected_apk"
                                        echo "Aplikasi berhasil diinstall (atau gagal jika file tidak valid)."
                                    else
                                        echo "Pilihan tidak valid atau dibatalkan."
                                    fi
                                fi
                            else
                                echo "Direktori tidak valid atau dibatalkan."
                            fi
                        else
                            echo "Coba jalankan 'ls $APK_DIR' untuk memeriksa."
                        fi
                    else
                        echo "Daftar file .apk:"
                        IFS=$'\n' read -d '' -r -a apk_array <<< "$apk_files"
                        for i in "${!apk_array[@]}"; do
                            echo "$((i+1)). ${apk_array[i]}"
                        done
                        echo -n "Pilih nomor file .apk untuk diinstall (0 untuk batal): "
                        read apk_choice
                        if [ "$apk_choice" -gt 0 ] && [ "$apk_choice" -le "${#apk_array[@]}" ]; then
                            selected_apk=${apk_array[$((apk_choice-1))]}
                            echo "Menginstall $selected_apk ke perangkat yang terhubung..."
                            termux-adb install "$selected_apk"
                            echo "Aplikasi berhasil diinstall (atau gagal jika file tidak valid)."
                        else
                            echo "Pilihan tidak valid atau dibatalkan."
                        fi
                    fi
                    ;;
                *)
                    echo "Pilihan sumber tidak valid!"
                    ;;
            esac
            ;;
        0)
            echo "Menghentikan ADB dan keluar..."
            termux-adb kill-server
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid! Silakan coba lagi."
            ;;
    esac
    echo -n "Tekan Enter untuk kembali ke menu..."
    read
    clear
    echo "=== Menu Termux-ADB ==="
done
