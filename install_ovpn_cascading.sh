#!/bin/bash
#
### Variablen deklarieren
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

# Bildschirm leeren
clear

printf "\n\nScript zur Installation der automatischen PP openVPN Kaskadierungsdienste"
printf "\n-------------------------------------------------------------------------\n\n"
printf "... der Vorgang dauert weniger als eine Minute.\n\n"

# Paketdaten und Repository aktualisieren
apt-get update -qq

### notwendige Pakete installieren
# pruefen, ob 'tmux' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "tmux" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install tmux -qq > /dev/null
	printf "==> tmux installiert!\n"
fi

# pruefen, ob 'openvpn-client' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "openvpn" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install openvpn -qq > /dev/null
	printf "==> openvpn installiert!\n"
fi

# pruefen, ob 'resolvconf' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "resolvconf" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install resolvconf -qq > /dev/null
	printf "==> resolvconf installiert!\n"
fi

# pruefen, ob 'psmisc' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "psmisc" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install psmisc -qq > /dev/null
	printf "==> psmisc installiert!\n"
fi

# pruefen, ob 'bc' installiert ist -> falls nein, installieren!
dpkg-query -l | grep -w "bc" > /dev/null

if [ $? -eq "1" ];
then
	apt-get install bc -qq > /dev/null
	printf "==> bc installiert!\n\n"
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

# die Dateien in den Zielverzeichnissen ablegen und zuvor prüfen, ob die Scripte schon vorhanden sind
# falls die Scripte vorhanden sind, die Variablen zuvor in die neuen Scripte uebernehmen
if [[ -f "$scriptpath/$FILE_DL_PRIM_SCR" ]];
then
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
path_ovpn_conf=($(grep 'path_ovpn_conf=' $scriptpath'/'$FILE_DL_PRIM_SCR | rev | cut -d '=' -f 1 | rev))
folder_logpath=($(grep 'folder_logpath=' $scriptpath'/'$FILE_DL_PRIM_SCR | rev | cut -d '=' -f 1 | rev))
eval mkdir -p $path_ovpn_conf

printf "\n------------------------------------------------"
printf "\nInstallation ERFOLGREICH abgeschlossen!"
printf "\nInstallierte Dienste noch NICHT gestartet!"
printf "\n------------------------------------------------"
printf "\n\nPerfectPrivacy Konfigurationen bitte im folgenden Verzeichnis hinterlegen:\n==> $path_ovpn_conf"
printf "\nHinweis: es werden saemtliche Konfigurationen (*.conf) verwendet, welche sich in diesem Verzeichnis befinden!"
printf "\n\nWeitere Schritte notwendig!"
printf "\n---------------------------"
printf "\nBitte folgende Anleitung aufrufen:\n==> https://www.perfect-privacy.com/de/manuals/linux_openvpn_terminal"
printf "\nEs muessen, laut dieser Anleitung, lediglich noch folgende Schritte ausgefuehrt werden:"
printf "\n\t- Herunterladen der PerfectPrivacy Konfigurationen"
printf "\n\t- Erstellen der 'password.txt' und anschließendes eintragen der Anmeldedaten"
printf "\n\t- Die 'password.txt' in den heruntergeladenen Konfigurationen eintragen"
printf "\n\t- Neustarten, damit die soeben installierten Dienste gestartet werden"
printf "\n\nDie Dienste heißen 'openvpn-restart-cascading.service' und 'openvpn-restart-cascading-watchdog.service'"
printf "\nDienstverwaltung über folgende Befehle:"
printf "\n\t- sudo systemctl start/stop/restart openvpn-restart-cascading.service"
printf "\n\t- sudo systemctl start/stop/restart openvpn-restart-cascading-watchdog.service"
printf "\n\nNach dem Neustart befindet sich das Logverzeichnis hier: $folder_logpath"

printf "\n\nMoechtest du meine Arbeit unterstuetzen?"
printf "\nUeber eine kleine Donation an folgende PayPal.me-Adresse wuerde ich mich sehr freuen:"
printf "\n\nhttps://www.paypal.me/patricklwl"
printf "\n\n------------------------------------------------\n\n"
