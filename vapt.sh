#!/bin/bash
# Cek apakah script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root. Usage: sudo ./masternmap.sh"
  exit 1
fi

# Menanyakan metode input IP
echo "Pilih metode input IP:"
echo "1. Masukkan segmen IP (contoh: 192.168.88.0/24)"
echo "2. Gunakan file daftar IP yang sudah ada"
read -p "Masukkan pilihan Anda (1 atau 2): " pilihan

# Mengambil input berdasarkan pilihan pengguna
if [ "$pilihan" -eq 1 ]; then
    read -p "Silakan masukkan segmen IP (contoh: 192.168.88.0/24): " IP_SEGMENT
elif [ "$pilihan" -eq 2 ]; then
    read -p "Silakan masukkan nama file daftar IP: " IP_LIST_FILE
    # Cek apakah file daftar IP ada
    if [ ! -f "$IP_LIST_FILE" ]; then
        echo "File $IP_LIST_FILE tidak ditemukan. Pastikan file ini ada dan berisi daftar IP yang ingin discan."
        exit 1
    fi
else
    echo "Pilihan tidak valid. Harap masukkan 1 atau 2."
    exit 1
fi

# Membuat folder yang diperlukan jika belum ada
mkdir -p server db report

# Menghapus file lama jika ada
rm -f server/webserver_with_title.txt

# Fungsi untuk menjalankan scan berdasarkan IP segment atau list IP
scan_ports() {
    local ip=$1
    # Scan untuk port yang berkaitan dengan webserver
    echo "Melakukan scan untuk webserver ports pada IP $ip..."
    nmap -Pn -p 80,443,8010,8080 -oN scan_webserver_$ip.txt --open --max-retries 1 -T4 -n --disable-arp-ping "$ip"

    # Memproses hasil pemindaian untuk setiap host dengan port terbuka yang relevan
    awk '
    /^Nmap scan report/ { ip=$NF; gsub("[()]", "", ip) }
    /80\/tcp open/ { print "http://" ip } 
    /443\/tcp open/ { print "https://" ip }
    /8010\/tcp open/ { print ip ":8010" }
    /8080\/tcp open/ { print ip ":8080" }
    ' scan_webserver_$ip.txt >> server/webserver.txt

    rm scan_webserver_$ip.txt
}

# Scan berdasarkan metode yang dipilih
if [ "$pilihan" -eq 1 ]; then
    # Jika memilih segmen IP, scan langsung pada segmen IP yang diberikan
    scan_ports "$IP_SEGMENT"
else
    # Jika memilih file daftar IP, loop melalui setiap IP dalam file
    while read -r ip; do
        scan_ports "$ip"
    done < "$IP_LIST_FILE"
fi

echo "URL berhasil tersimpan dalam server/webserver.txt"

# Fungsi untuk mengambil title dari URL
get_title() {
    url=$1
    # Menggunakan curl dengan timeout agar tidak hang
    response=$(curl -s --max-time 5 -o /dev/null -w "%{http_code} %{redirect_url}" "$url")
    http_code=$(echo "$response" | cut -d' ' -f1)
    redirect_url=$(echo "$response" | cut -d' ' -f2-)

    # Jika ada redirect, update URL
    if [[ $http_code == "301" || $http_code == "302" ]]; then
        echo "Redirect detected: $url -> $redirect_url"
        url=$redirect_url
    fi

    # Mengambil title dari halaman
    title=$(curl -s --max-time 5 "$url" | grep -o '<title>[^<]*' | sed 's/<title>//')
    echo "$url - $title"
}

# Menambahkan title untuk setiap URL di server/webserver.txt
echo "Menambahkan title untuk setiap URL..."
while read -r url; do
    get_title "$url" >> server/webserver_with_title.txt
done < server/webserver.txt
echo "Title berhasil ditambahkan di server/webserver_with_title.txt"

# Scan untuk port yang berkaitan dengan server
if [ "$pilihan" -eq 1 ]; then
    echo "Melakukan scan untuk server ports pada segmen IP $IP_SEGMENT..."
    nmap -Pn -p 21,22,23,139,445 -oN scan_server.txt --open --max-retries 1 -T4 -n --disable-arp-ping "$IP_SEGMENT"
else
    while read -r ip; do
        echo "Melakukan scan untuk server ports pada IP $ip..."
        nmap -Pn -p 21,22,23,139,445 -oN scan_server_$ip.txt --open --max-retries 1 -T4 -n --disable-arp-ping "$ip"
    done < "$IP_LIST_FILE"
fi

echo "Server ports berhasil tersimpan dalam folder server"

# Scan untuk port yang berkaitan dengan database
if [ "$pilihan" -eq 1 ]; then
    echo "Melakukan scan untuk database ports pada segmen IP $IP_SEGMENT..."
    nmap -Pn -p 1433,3306,1521,5432 -oN scan_db.txt --open --max-retries 1 -T4 -n --disable-arp-ping "$IP_SEGMENT"
else
    while read -r ip; do
        echo "Melakukan scan untuk database ports pada IP $ip..."
        nmap -Pn -p 1433,3306,1521,5432 -oN scan_db_$ip.txt --open --max-retries 1 -T4 -n --disable-arp-ping "$ip"
    done < "$IP_LIST_FILE"
fi

echo "Database ports berhasil tersimpan dalam folder db"

# Menjalankan XRAY jika tersedia
if [ -d "/home/kali/simulasi/vapt-main/xray" ]; then
    echo "Menjalankan XRAY..."
    cd /home/kali/simulasi/vapt-main/xray
    random_filename=$(date +%H%M).html
    ./scanxray ws --url-file ../server/webserver.txt --html-output "../report/$random_filename"
    echo "XRAY scan selesai. Hasil tersimpan di report/$random_filename"
else
    echo "Folder XRAY tidak ditemukan, lewati langkah XRAY."
fi

# Menjalankan custom.sh jika tersedia
if [ -f "/home/kali/simulasi/vapt-main/customVA/custom.sh" ]; then
    echo "Menjalankan custom.sh..."
    cd /home/kali/simulasi/vapt-main/customVA
    mkdir -p output
    ./custom.sh
    echo "custom.sh selesai dijalankan."
else
    echo "Script custom.sh tidak ditemukan, lewati langkah custom.sh."
fi

echo "Script selesai dijalankan."