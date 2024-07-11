#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root usage: sudo ./masternmap.sh"
  exit
fi

mkdir -p server
mkdir -p db
mkdir -p report

rm -f server/webserver_with_title.txt


# Scan untuk port yang berkaitan webserver
nmap -Pn -p 80,443,8010,8080 -oN scan_webserver.txt --open --max-retries 1 -T4 -n --disable-arp-ping 192.168.88.1/24

# Memproses hasil pemindaian untuk setiap host dengan port terbuka yang relevan
awk '
/^Nmap scan report/ { ip=$NF; gsub("[()]", "", ip) }
/80\/tcp open/ { print "http://" ip} 
/443\/tcp open/ { print "https://" ip}
/8010\/tcp open/ { print ip "8010"}
/8080\/tcp open/ { print ip ":8080"}
' scan_webserver.txt > server/webserver.txt

rm scan_webserver.txt

echo "URL berhasil tersimpan dalam server/webserver.txt"

get_title() {
    url=$1
    response=$(curl -s -o /dev/null -w "%{http_code} %{redirect_url}" $url)
    http_code=$(echo $response | cut -d' ' -f1)
    redirect_url=$(echo $response | cut -d' ' -f2-)

    if [[ $http_code == "301" || $http_code == "302" ]]; then
        echo "Redirect detected: $url -> $redirect_url"
        url=$redirect_url
    fi

    title=$(curl -s $url | grep -o '<title>[^<]*' | sed 's/<title>//')
    echo "$url - $title"
}

# Menambahkan title untuk setiap URL di server/webserver.txt
while read url; do
    get_title $url >> server/webserver_with_title.txt
done < server/webserver.txt


# Scan untuk port yang berkaitan server
nmap -Pn -p 21,22,23,139,445 -oN scan_server.txt --open --max-retries 1 -T4 -n --disable-arp-ping 192.168.88.1/24

# Memproses hasil pemindaian untuk setiap host dengan port terbuka yang relevan
awk '
/^Nmap scan report/ { ip=$NF; gsub("[()]", "", ip) }
/21\/tcp open/ { print ip > "server/ftp_port.txt"} 
/22\/tcp open/ { print ip > "server/ssh_port.txt"}
/23\/tcp open/ { print ip > "server/telnet_port.txt"}
/139\/tcp open/ { print ip > "server/smb_port.txt"}
/445\/tcp open/ { print ip > "server/smb2_port.txt"}
' scan_server.txt

rm scan_server.txt

echo "URL berhasil tersimpan dalam folder server"

# Scan untuk port yang berkaitan database
nmap -Pn -p 1433,3306,1521,5432 -oN scan_db.txt --open --max-retries 1 -T4 -n --disable-arp-ping 192.168.88.1/24

# Memproses hasil pemindaian untuk setiap host dengan port terbuka yang relevan
awk '
/^Nmap scan report/ { ip=$NF; gsub("[()]", "", ip) }
/1433\/tcp open/ { print ip > "db/sqlserver_port.txt"} 
/3306\/tcp open/ { print ip > "db/mysql.txt"}
/1521\/tcp open/ { print ip > "db/oracle_port.txt"}
/5432\/tcp open/ { print ip > "db/postgre_port.txt"}
' scan_db.txt

rm scan_db.txt

echo "URL berhasil tersimpan dalam folder DB"

# Menjalankan XRAY
#cd /home/kali/scripting/xray

#random_filename=$(date +%H%M).html

#./scanxray ws --url-file ../server/webserver.txt --html-output "../report/$random_filename"

cd /home/kali/scripting/customVA
mkdir -p output

./custom.sh