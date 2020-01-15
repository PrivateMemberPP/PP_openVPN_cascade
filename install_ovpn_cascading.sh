#!/bin/bash
#
### Variablen deklarieren
#
# Speicherort fuer dieses Installationslog
install_log=/var/log/install_ovpn_cascade.log
#
# Pfad zur Ablage der Scripte
scriptpath=/etc/systemd/system
#
# Pfad zur Ablage der Service/Dienst-Dateien
servicepath=/lib/systemd/system
#
# Pfad zur Ablage des PP Kaskadierungsscripts
scriptpath_PP=/etc/openvpn
#
# Downloadlink Hauptscript
DL_PRIM_SCR=https://raw.githubusercontent.com/PrivateMemberPP/PP_openVPN_cascade/master/openvpn_service_restart_cascading.sh
#
# Downloadlink Watchdog-Script
DL_WATC_SCR=https://raw.githubusercontent.com/PrivateMemberPP/PP_openVPN_cascade/master/openvpn_service_restart_cascading_watchdog.sh
#
# Downloadlink Hauptscript Service-Datei
DL_PRIM_SRV=https://raw.githubusercontent.com/PrivateMemberPP/PP_openVPN_cascade/master/openvpn-restart-cascading.service
#
# Downloadlink Watchdog-Script Service-Datei
DL_WATC_SRV=https://raw.githubusercontent.com/PrivateMemberPP/PP_openVPN_cascade/master/openvpn-restart-cascading-watchdog.service
#
# Downloadlink PP Kaskadierungsscript
DL_CASC_SCR=https://www.perfect-privacy.com/downloads/updown.sh
#
### ENDE Variablen deklarieren

### Funktionen ###
function search_and_replace {
	line_num=($(grep -n -m 1 $1 $2 | cut -d':' -f 1))
	sed -i ""$line_num"s#.*#"$3"#" $4
}
### ENDE Funktionen ###

# grundsaetzlich davon ausgehen, dass KEIN Update durchgefuehrt wird
update_check=0

# Bildschirm leeren
clear

# LOG loeschen, falls vorhanden
if [[ -f $install_log ]];
then
	rm $install_log
fi

printf "\n\nScript zur Installation der automatischen PP openVPN Kaskadierungsdienste" 2>&1 | tee -a $install_log
printf "\n-------------------------------------------------------------------------\n\n" 2>&1 | tee -a $install_log
printf "... der Vorgang dauert weniger als eine Minute.\n\n" 2>&1 | tee -a $install_log

# Paketdaten und Repository aktualisieren
apt-get update -qq

### notwendige Pakete installieren
# pruefen, ob 'tmux' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "tmux" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install tmux -qq > /dev/null
	printf "==> tmux installiert!\n" 2>&1 | tee -a $install_log
fi

# pruefen, ob 'openvpn-client' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "openvpn" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install openvpn -qq > /dev/null
	printf "==> openvpn installiert!\n" 2>&1 | tee -a $install_log
fi

# pruefen, ob 'resolvconf' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "resolvconf" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install resolvconf -qq > /dev/null
	printf "==> resolvconf installiert!\n" 2>&1 | tee -a $install_log
fi

# pruefen, ob 'psmisc' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "psmisc" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install psmisc -qq > /dev/null
	printf "==> psmisc installiert!\n" 2>&1 | tee -a $install_log
fi

# pruefen, ob 'bc' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "bc" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install bc -qq > /dev/null
	printf "==> bc installiert!\n\n" 2>&1 | tee -a $install_log
fi

### notwendige Pakete installiert

# in welchem Verzeichnis befinden wir uns?
curdir="${PWD}"

# Arbeitsverzeichnis erstellen
mkdir $curdir'/'OVPN_SWITCH

# Download der benoetigten Dateien
# Dateinamen in variablen speichern
wget -q -P $curdir'/OVPN_SWITCH/' $DL_PRIM_SCR > /dev/null
FILE_DL_PRIM_SCR=($(echo $DL_PRIM_SCR | rev | cut -d '/' -f 1 | rev))
wget -q -P $curdir'/OVPN_SWITCH/' $DL_WATC_SCR > /dev/null
FILE_DL_WATC_SCR=($(echo $DL_WATC_SCR | rev | cut -d '/' -f 1 | rev))
wget -q -P $curdir'/OVPN_SWITCH/' $DL_PRIM_SRV > /dev/null
FILE_DL_PRIM_SRV=($(echo $DL_PRIM_SRV | rev | cut -d '/' -f 1 | rev))
wget -q -P $curdir'/OVPN_SWITCH/' $DL_WATC_SRV > /dev/null
FILE_DL_WATC_SRV=($(echo $DL_WATC_SRV | rev | cut -d '/' -f 1 | rev))
wget -q -P $curdir'/OVPN_SWITCH/' $DL_CASC_SCR > /dev/null
FILE_DL_CASC_SCR=($(echo $DL_CASC_SCR | rev | cut -d '/' -f 1 | rev))

# falls ein Update durchgefuehrt wird, erstmal die Dienste beenden
systemctl --full --type service --all | grep -q openvpn-restart-cascading.service
if [ $? -eq "0" ];
then
	systemctl stop openvpn-restart-cascading.service > /dev/null
fi

systemctl --full --type service --all | grep -q openvpn-restart-cascading-watchdog.service
if [ $? -eq "0" ];
then
	systemctl stop openvpn-restart-cascading-watchdog.service > /dev/null
fi

sleep 2

# die Dateien in den Zielverzeichnissen ablegen und zuvor prüfen, ob das Hauptscript schon vorhanden ist (im Falle eines Updates)
# falls vorhanden, die Variablen zuvor in das neuen, heruntergeladene Script erst uebernehmen
if [[ -f "$scriptpath/$FILE_DL_PRIM_SCR" ]];
then
	update_check=1

	cur_folder_logpath=($(grep -m 1 "folder_logpath=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace folder_logpath= $scriptpath/$FILE_DL_PRIM_SCR $cur_folder_logpath $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_logfile_script=($(grep -m 1 "logfile_script=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace logfile_script= $scriptpath/$FILE_DL_PRIM_SCR $cur_logfile_script $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_path_ovpn_conf=($(grep -m 1 "path_ovpn_conf=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace path_ovpn_conf= $scriptpath/$FILE_DL_PRIM_SCR $cur_path_ovpn_conf $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_path_ovpn_cascade_script=($(grep -m 1 "path_ovpn_cascade_script=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace path_ovpn_cascade_script= $scriptpath/$FILE_DL_PRIM_SCR $cur_path_ovpn_cascade_script $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_checkfile_watchdog=($(grep -m 1 "checkfile_watchdog=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace checkfile_watchdog= $scriptpath/$FILE_DL_PRIM_SCR $cur_checkfile_watchdog $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_scriptfile_watchdog=($(grep -m 1 "scriptfile_watchdog=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace scriptfile_watchdog= $scriptpath/$FILE_DL_PRIM_SCR $cur_scriptfile_watchdog $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_mintime=($(grep -m 1 "mintime=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace mintime= $scriptpath/$FILE_DL_PRIM_SCR $cur_mintime $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_maxtime=($(grep -m 1 "maxtime=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace maxtime= $scriptpath/$FILE_DL_PRIM_SCR $cur_maxtime $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_maxhop=($(grep -m 1 "maxhop=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace maxhop= $scriptpath/$FILE_DL_PRIM_SCR $cur_maxhop $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_timeoutcount=($(grep -m 1 "timeoutcount=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace timeoutcount= $scriptpath/$FILE_DL_PRIM_SCR $cur_timeoutcount $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR

	cur_logdelete_count=($(grep -m 1 "logdelete_count=" "$scriptpath"'/'"$FILE_DL_PRIM_SCR"))
	search_and_replace logdelete_count= $scriptpath/$FILE_DL_PRIM_SCR $cur_logdelete_count $curdir/OVPN_SWITCH/$FILE_DL_PRIM_SCR
fi

# die Dateien in den Zielverzeichnissen ablegen
mv -f $curdir'/OVPN_SWITCH/'$FILE_DL_PRIM_SCR $scriptpath
mv -f $curdir'/OVPN_SWITCH/'$FILE_DL_WATC_SCR $scriptpath
mv -f $curdir'/OVPN_SWITCH/'$FILE_DL_PRIM_SRV $servicepath
mv -f $curdir'/OVPN_SWITCH/'$FILE_DL_WATC_SRV $servicepath
mv -f $curdir'/OVPN_SWITCH/'$FILE_DL_CASC_SCR $scriptpath_PP

# die Scripte ausfuehrbar machen
chmod +x $scriptpath'/'$FILE_DL_PRIM_SCR
chmod +x $scriptpath'/'$FILE_DL_WATC_SCR
chmod +x $scriptpath_PP'/'$FILE_DL_CASC_SCR

# die Services ausfuehrbar machen und aktivieren
chmod +x $servicepath'/'$FILE_DL_PRIM_SRV
chmod +x $servicepath'/'$FILE_DL_WATC_SRV

systemctl daemon-reload

systemctl enable $FILE_DL_PRIM_SRV
systemctl enable $FILE_DL_WATC_SRV

# Arbeitsverzeichnis loeschen
rm -r $curdir'/'OVPN_SWITCH

# Statusausgabe

path_ovpn_conf=($(grep -m 1 'path_ovpn_conf=' $scriptpath'/'$FILE_DL_PRIM_SCR | rev | cut -d '=' -f 1 | rev))
folder_logpath=($(grep -m 1 'folder_logpath=' $scriptpath'/'$FILE_DL_PRIM_SCR | rev | cut -d '=' -f 1 | rev))

if [ $update_check -eq "1" ];
then
	printf "\n------------------------------------------------" 2>&1 | tee -a $install_log
	printf "\nUpdate ERFOLGREICH abgeschlossen!" 2>&1 | tee -a $install_log
	printf "\nDienste werden wieder gestartet!" 2>&1 | tee -a $install_log
	printf "\n------------------------------------------------" 2>&1 | tee -a $install_log
	printf "\n\nPerfectPrivacy Konfigurationen befinden sich weiterhin im folgenden Verzeichnis:\n==> $path_ovpn_conf" 2>&1 | tee -a $install_log
	printf "\nHinweis: es werden saemtliche Konfigurationen (*.conf) verwendet, welche sich in diesem Verzeichnis befinden!" 2>&1 | tee -a $install_log
	printf "\n\nKEINE weitere Schritte notwendig!" 2>&1 | tee -a $install_log
	printf "\n---------------------------------" 2>&1 | tee -a $install_log

	printf "\nDienstverwaltung über folgende Befehle:" 2>&1 | tee -a $install_log
	printf "\n\t- sudo systemctl start|stop|restart openvpn-restart-cascading.service" 2>&1 | tee -a $install_log
	printf "\n\t- sudo systemctl start|stop|restart openvpn-restart-cascading-watchdog.service" 2>&1 | tee -a $install_log

	systemctl start openvpn-restart-cascading.service > /dev/null
	systemctl start openvpn-restart-cascading-watchdog.service > /dev/null
else
	eval mkdir -p $path_ovpn_conf
	printf "\n------------------------------------------------" 2>&1 | tee -a $install_log
	printf "\nInstallation ERFOLGREICH abgeschlossen!" 2>&1 | tee -a $install_log
	printf "\nInstallierte Dienste noch NICHT gestartet!" 2>&1 | tee -a $install_log
	printf "\n------------------------------------------------" 2>&1 | tee -a $install_log
	printf "\n\nPerfectPrivacy OpenVPN-Konfigurationen bitte im folgenden Verzeichnis hinterlegen:\n==> $path_ovpn_conf" 2>&1 | tee -a $install_log
	printf "\nHinweis: es werden saemtliche Konfigurationen (*.conf) verwendet, welche sich in diesem Verzeichnis befinden!" 2>&1 | tee -a $install_log
	printf "\n\nJetzt folgende Schritte ausfuehren!" 2>&1 | tee -a $install_log
	printf "\nHinter dem ':' stehen die Befehle" 2>&1 | tee -a $install_log
	printf "\n-----------------------------------" 2>&1 | tee -a $install_log
	printf "\n\nHerunterladen der PerfectPrivacy Konfigurationen" 2>&1 | tee -a $install_log
	printf "\n\t- Wechsel in das Verzeichnis $path_ovpn_conf":" cd $path_ovpn_conf" 2>&1 | tee -a $install_log
	printf "\n\t- Herunterladen der Konfigurationen: sudo wget --content-disposition https://www.perfect-privacy.com/downloads/openvpn/get?system=linux" 2>&1 | tee -a $install_log
	printf "\n\t- Die Dateien entpacken: sudo unzip -j linux_op24_udp_v4_AES256GCM_AU_in_ci.zip" 2>&1 | tee -a $install_log
	printf "\nErzeugen einer Datei mit den Logindaten" 2>&1 | tee -a $install_log
	printf "\n\t- Die Datei im Verzeichnis erstellen, in dem wir uns befinden: sudo nano $path_ovpn_conf"password.txt"" 2>&1 | tee -a $install_log
	printf "\n\t- Logindaten in diese Datei eintragen: erste Zeile NUR den Nutzernamen, zweite Zeile NUR das Passwort" 2>&1 | tee -a $install_log
	printf "\n\t- Datei speichern und schließen: Strg+X -> dann mit 'J' oder 'y' bestaetigen" 2>&1 | tee -a $install_log
	printf "\nEintragen der soeben erstellten 'password.txt' in die heruntergeladenen Configs" 2>&1 | tee -a $install_log
	printf %s "\n\t- Alle Configs mit dem Pfad zur 'password.txt' editieren: sudo find *.conf -type f -exec sed -i "/auth-user-pass/c auth-user-pass $path_ovpn_conf"password.txt"" {} \;" 2>&1 | tee -a $install_log
	printf "\n\\nZum Abschluss muss noch das System neugestartet werden: sudo reboot" 2>&1 | tee -a $install_log
	printf "\n\nDie installierten Dienste heißen 'openvpn-restart-cascading.service' und 'openvpn-restart-cascading-watchdog.service'" 2>&1 | tee -a $install_log
	printf "\nDienstverwaltung über folgende Befehle:" 2>&1 | tee -a $install_log
	printf "\n\t- sudo systemctl start|stop|restart openvpn-restart-cascading.service" 2>&1 | tee -a $install_log
	printf "\n\t- sudo systemctl start|stop|restart openvpn-restart-cascading-watchdog.service" 2>&1 | tee -a $install_log
	printf "\n\nNach dem Neustart befindet sich das Logverzeichnis hier: $folder_logpath" 2>&1 | tee -a $install_log
	printf "\n\nDieses Ausgabelog ist hier zu finden: $install_log" 2>&1 | tee -a $install_log
fi

printf "\n\nMoechtest du meine Arbeit unterstuetzen?" 2>&1 | tee -a $install_log
printf "\nUeber eine kleine Donation an folgende PayPal.me-Adresse wuerde ich mich sehr freuen:" 2>&1 | tee -a $install_log
printf "\n\nhttps://www.paypal.me/patricklwl" 2>&1 | tee -a $install_log
printf "\n\n------------------------------------------------\n\n" 2>&1 | tee -a $install_log
