#!/bin/bash

# Bildschirm leeren
clear

printf "\n\nScript zur Deinstallation der automatischen PP openVPN Kaskadierungsdienste"
printf "\n---------------------------------------------------------------------------\n\n"
printf "... der Vorgang dauert weniger als eine Minute.\n\n"

# Dienste stoppen
systemctl stop openvpn-restart-cascading-watchdog.service
systemctl stop openvpn-restart-cascading.service

# Dienste aus dem Autostart nehmen
systemctl disable openvpn-restart-cascading-watchdog.service
systemctl disable openvpn-restart-cascading.service

# aktuelle Verbindungen und Sessions beenden
killall openvpn
killall tmux

# Loeschen der Scripte
rm /etc/systemd/system/openvpn_service_restart_cascading.sh
rm /etc/systemd/system/openvpn_service_restart_cascading_watchdog.sh
rm /etc/openvpn/updown.sh

# Falls noch vorhanden - loeschen von weiteren Verweisen der Scripte
rm /usr/lib/systemd/system/openvpn-restart-cascading.service
rm /usr/lib/systemd/system/openvpn-restart-cascading-watchdog.service

rm /lib/systemd/system/openvpn-restart-cascading.service
rm /lib/systemd/system/openvpn-restart-cascading-watchdog.service

rm /etc/systemd/system/multi-user.target.wants/openvpn-restart-cascading.service
rm /etc/systemd/system/multi-user.target.wants/openvpn-restart-cascading-watchdog.service

# LOG-Verzeichnis entfernen
rm -r /var/log/ovpn_reconnect

# Dienstverwaltung neu starten und bereinigen
systemctl daemon-reload
systemctl reset-failed

# Statusausgabe

printf "\n------------------------------------------------"
printf "\nDeinstallation ERFOLGREICH abgeschlossen!"
printf "\n------------------------------------------------"
printf "\n\nEs wurden saemtliche Dateien entfernt, welche zu den PP openVPN Kaskadierungsdiensten gehören"
printf "\n\nBitte das System neustarten!\n\n"
