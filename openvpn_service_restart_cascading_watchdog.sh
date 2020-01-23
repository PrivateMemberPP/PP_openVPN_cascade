#!/bin/bash
#
### Variablen deklarieren ###
#
# Pfad zur Ablage saemtlicher Logfiles des Hauptscripts
folder_logpath=/var/log/ovpn_reconnect/
#
# Logfile fuer dieses Watchdog-Script
logfile_watchdog="$folder_logpath"watchdog_openvpn_reconnect.log
#
# Checkfile fuer den Watchdog-Service
checkfile_watchdog="$folder_logpath"exitnode.log
#
### ENDE Variablen deklarieren ###
#
### Definition von Funktionen ###
#
function get_state {
	current_state=$(cat $checkfile_watchdog)
	sleep 1
}
function check_inactivity {
	if grep "Inactivity timeout (--ping-restart), restarting" "$folder_logpath"log.vpnhop*
	then
		{
			echo -e "\n----------ACHTUNG----------"
			echo -e "Es ist jetzt $(date)"
			echo -e "Mindestens ein Server der Kaskade ist nicht mehr erreichbar!"
			echo -e "Dienste nun neustarten, damit ein sicherer Zustand wiederhergestellt werden kann!"
		} >> $logfile_watchdog
		kill_primary_process
		sudo rm $checkfile_watchdog
	fi
}
function check_state {
	wget -q -O - https://checkip.perfect-privacy.com/csv | grep -i "$current_state" >> /dev/null
	RET=$?
	sleep 8
}
function cleanup {
	sudo killall openvpn
	sleep 2
	sudo tmux kill-server
	sleep 0.5
}
function kill_primary_process {
	cleanup
	PID=$(sudo systemctl --property="MainPID" show openvpn-restart-cascading.service | cut -d '=' -f 2)
	sleep 0.2
	sudo kill -9 -"$(ps -o pgid= "$PID" | grep -o '[0-9]*')" > /dev/null
}
#
### ENDE Definition von Funktionen ###
#
### HAUPTPROGRAMM ###
while true
do
	# erstmal warten, bis die Datei erstellt wurde
	while [ ! -f "$checkfile_watchdog" ]
	do
		sleep 5
	done

	# Datei existiert und kann kontinuierlich ausgewertet werden
	while [ -f "$checkfile_watchdog" ]
	do
		# aktuellen Dateiinhalt in eine Variable speichern
		get_state

		if [ "$current_state" == "Warten" ];
		then
			sleep 5
		else
			sleep 5
			echo -e "\n\nVerbindung besteht seit:\t\t$(date)" >> $logfile_watchdog
			echo -e "mit Ausgangsknoten:\t\t\t$current_state" >> $logfile_watchdog
			sleep 5

			check_inactivity
			check_state

			while [ $RET -eq "0" ]
			do
				check_inactivity
				get_state
				check_state
			done

			get_state
			if [ ! "$current_state" == "Warten" ];
			then
				{
					echo -e "\n----------ACHTUNG----------"
					echo -e "Es ist jetzt $(date)"
					echo -e "Austrittsknoten hat sich geaendert!"
					echo -e "Dienste nun neustarten, damit ein sicherer Zustand wiederhergestellt werden kann!"
				} >> $logfile_watchdog
				kill_primary_process
				sudo rm $checkfile_watchdog
			fi
		fi
		# Wenn das LOG groesser als 20MB ist, dieses leeren
		if [[ "$(wc -c $logfile_watchdog | cut -d ' ' -f 1)" -gt "20480" ]];
		then
			echo "" > $logfile_watchdog
		fi
	done
done
