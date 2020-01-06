#!/bin/bash
#
### Variablen deklarieren ###
#
# Pfad zur Ablage saemtlicher Logfiles des Hauptscripts
folder_logpath=/var/log/ovpn_reconnect/
#
# Logfile fuer dieses Watchdog-Script
logfile_watchdog=/var/log/watchdog_openvpn_reconnect.log
#
# Checkfile fuer den Watchdog-Service
checkfile_watchdog=/var/log/ovpn_reconnect/exitnode.log
#
### ENDE Variablen deklarieren ###
#
### Definition von Funktionen ###
#
function get_state {
	current_state=$(cat $checkfile_watchdog)
	sleep 5
}
function check_inactivity {
	grep "Inactivity timeout (--ping-restart), restarting" "$folder_logpath"log.vpnhop*
	if [ $? -eq "0" ];
	then
		echo -e '\n''----------'ACHTUNG'----------' >> $logfile_watchdog
		echo -e Es ist jetzt $(date) >> $logfile_watchdog
		echo -e Mindestens ein Server der Kaskade ist nicht mehr erreichbar'!' >> $logfile_watchdog
		echo -e Dienste nun neustarten, damit ein sicherer Zustand wiederhergestellt werden kann'!' >> $logfile_watchdog
		kill_primary_process
		sudo rm $checkfile_watchdog
	fi
}
function check_state {
	wget -q -O - https://checkip.perfect-privacy.com/csv | grep -i $current_state >> /dev/null
	RET=$?
	sleep 30
}
function cleanup {
	sudo killall openvpn
	sleep 2
	sudo tmux kill-server
	sleep 2
}
function kill_primary_process {
	cleanup
	PID=$(sudo systemctl --property="MainPID" show openvpn-restart-cascading.service | cut -d '=' -f 2)
	sleep 0.5
	sudo kill -9 -$( ps opgid= $PID | tr -d ' ' )
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
			echo -e '\n''\n'Checkfile existiert seit':''\t''\t'$(date) >> $logfile_watchdog
			echo -e mit Ausgangsknoten':''\t''\t''\t'$current_state >> $logfile_watchdog
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
				echo -e '\n''----------'ACHTUNG'----------' >> $logfile_watchdog
				echo -e Es ist jetzt $(date) >> $logfile_watchdog
				echo -e Austrittsknoten hat sich geaendert'!' >> $logfile_watchdog
				echo -e Dienste nun neustarten, damit ein sicherer Zustand wiederhergestellt werden kann'!' >> $logfile_watchdog
				kill_primary_process
				sudo rm $checkfile_watchdog
			fi
		fi
	done
done
