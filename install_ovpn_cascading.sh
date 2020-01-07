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

# Paketdaten und Repository aktualisieren
apt-get update

### notwendige Pakete installieren
# pruefen, ob 'tmux' installiert ist -> falls nein, installieren!
dpkg-query -l | grep tmux > /dev/null

if [ $? -eq "1" ];
then
	apt-get install tmux -qq > /dev/null
fi

# pruefen, ob 'openvpn-client' installiert ist -> falls nein, installieren!
dpkg-query -l | grep openvpn > /dev/null

if [ $? -eq "1" ];
then
	apt-get install openvpn -qq > /dev/null
fi

# pruefen, ob 'resolvconf' installiert ist -> falls nein, installieren!
dpkg-query -l | grep resolvconf > /dev/null

if [ $? -eq "1" ];
then
	apt-get install resolvconf -qq > /dev/null
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

# die Dateien in den Zielverzeichnissen ablegen
mv $curdir'/OVPN_SWITCH/'$FILE_DL_PRIM_SCR $scriptpath
mv $curdir'/OVPN_SWITCH/'$FILE_DL_WATC_SCR $scriptpath
mv $curdir'/OVPN_SWITCH/'$FILE_DL_PRIM_SRV $servicepath
mv $curdir'/OVPN_SWITCH/'$FILE_DL_WATC_SRV $servicepath
mv $curdir'/OVPN_SWITCH/'$FILE_DL_CASC_SCR $scriptpath_PP

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
mkdir $path_ovpn_conf

printf "\n\n------------------------------------------------"
printf "\nInstallation ERFOLGREICH abgeschlossen!"
printf "\nInstallierte Dienste noch NICHT gestartet!"
printf "\n------------------------------------------------"
printf "\n\nPerfectPrivacy Konfigurationen bitte im folgenden Verzeichnis hinterlegen:\n==> $path_ovpn_conf"
printf "\nHinweis: es werden saemtliche Konfigurationen (*.conf) verwendet, welche sich in diesem Verzeichnis befinden!"
printf "\n\nWeitere Schritte notwendig!"
printf "\n--------------------------"
printf "\nBitte folgende Anleitung aufrufen:\n==> https://www.perfect-privacy.com/de/manuals/linux_openvpn_terminal"
printf "\nEs muessen, laut dieser Anleitung, lediglich noch folgende Schritte ausgefuehrt werden:"
printf "\n\t- Herunterladen der PerfectPrivacy Konfigurationen"
printf "\n\t- Erstellen der 'password.txt' und anschlißendes eintragen der Anmeldedaten"
printf "\n\t- Die 'password.txt' in den heruntergeladenen Konfigurationen eintragen"
printf "\n\t- Neustarten, damit die soeben installierten Dienste gestartet werden"
printf "\n\nDie Dienste heißen 'openvpn-restart-cascading.service' und 'openvpn-restart-cascading-watchdog.service'"
printf "\nDienstverwaltung über folgende Befehle:"
printf "\n\t- sudo systemctl start/stop/restart openvpn-restart-cascading.service"
printf "\n\t- sudo systemctl start/stop/restart openvpn-restart-cascading-watchdog.service"
printf "\n\nDas Logverzeichnis befindet sich hier: $folder_logpath"
printf "\n\n------------------------------------------------\n\n"
