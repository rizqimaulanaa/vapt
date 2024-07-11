#!/bin/bash

#ftp oke
msfconsole -q -r template_msf_ftp_ver | tee output/ftpversion.txt
msfconsole -q -r template_msf_ftp_anon | tee output/ftpanon.txt

#ssh oke
msfconsole -q -r template_msf_ssh_ver | tee output/sshversion.txt
msfconsole -q -r template_msf_ssh_login | tee output/sshlogin.txt

#telnet oke
msfconsole -q -r template_msf_telnet_ver | tee output/telnetversion.txt

#139/445
msfconsole -q -r template_msf_smb_ver | tee output/smbversion.txt
msfconsole -q -r template_msf_smb_guest | tee output/smbguest.txt

#mysql
msfconsole -q -r template_msf_mysql_ver | tee output/mysqlversion.txt
msfconsole -q -r template_msf_mysql_login | tee output/mysqllogin.txt

#mssql oke
msfconsole -q -r template_msf_mssql_ver | tee output/mssqlversion.txt
msfconsole -q -r template_msf_mssql_login | tee output/mssqllogin.txt

#postgre
msfconsole -q -r template_msf_postgre_ver | tee output/postgreversion.txt

#oracle
msfconsole -q -r template_msf_oracle_ver | tee output/oracleversion.txt

