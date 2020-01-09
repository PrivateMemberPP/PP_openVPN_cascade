#!/bin/bash
#
### Variablen deklarieren ###
#
# Pfad zur Ablage saemtlicher Logfiles dieses Scripts
folder_logpath=/var/log/ovpn_reconnect/
#
# Logfilename für dieses Script (nur den Namen anpassen!)
logfile_script="$folder_logpath"vpnlog_restart.log
#
# Pfad zu den OpenVPN-Configs, welche genutzt werden sollen
path_ovpn_conf=/etc/openvpn/connections/
#
# Pfad zum Kaskadierungsscript von Perfect-Privacy
path_ovpn_cascade_script=/etc/openvpn/updown.sh
#
# Checkfile fuer den Watchdog-Service (nur den Namen anpassen!)
checkfile_watchdog="$folder_logpath"exitnode.log
#
# Pfad zur Watchdog-Script-Datei (openvpn_service_restart_cascading_watchdog.sh)
scriptfile_watchdog=/etc/systemd/system/openvpn_service_restart_cascading_watchdog.sh
#
# minimale Verbindungsdauer in Sekunden
mintime=7200
#
# maximale Verbindungsdauer in Sekunden
maxtime=10800
#
# Wie viele HOPs sollen verbunden werden?
maxhop=3
#
# Timeout-Counter (in Sekunden) zum Verbindungsaufbau (Wert wird je HOP verdoppelt)
# Bei einem Wert von '10' somit HOP1: 10; HOP2: 20; HOP3: 40; HOP4: 80 usw...
timeoutcount=20
#
# LOGDELETE: Nach wie vielen -erfolgreichen- neuen VPN-Verbindungen soll das LOG geloescht werden? (Schutz, damit dieses nicht den Speicher unendlich vollschreibt)
logdelete_count=20
#
### ENDE Variablen deklarieren ###

### Definition von Funktionen ###

function cleanup {
	sudo killall openvpn
	sleep 2
	sudo tmux kill-server
	sleep 0.5
	eval sudo rm "$folder_logpath"log.vpnhop*
	sleep 0.2
}
function kill_primary_process {
	cleanup
	PID=$(sudo systemctl --property="MainPID" show openvpn-restart-cascading.service | cut -d '=' -f 2)
	sleep 0.5
	sudo kill -9 -$( ps opgid= $PID | tr -d ' ' )
}
function kill_watchdog_process {
	PID=$(sudo systemctl --property="MainPID" show openvpn-restart-cascading-watchdog.service | cut -d '=' -f 2)
	sleep 0.5
	sudo kill -9 -$( ps opgid= $PID | tr -d ' ' )
}
function ermittle_server {
	server_list=($(eval ls -1 "$path_ovpn_conf"'*.conf' | sed 's/,//g' | rev |  cut -d '/' -f 1 | rev))
	server_list_count="${#server_list[@]}"
}
function remux_server_list {
	server_count="${#server_list[@]}"
	random=$(shuf -i 0-$[$server_count-1] -n 1)
	naechster_server=${server_list[$random]}
	server_name=$(echo "$naechster_server" | cut -d '.' -f1)
	unset 'server_list[$random]'
	server_list_temp=("${server_list[@]}")
	server_list=("${server_list_temp[@]}")
	unset server_list_temp
}
function double_time {
	inc_timeout=`expr $inc_timeout \* 2`
}
function write_timestamp {
	echo -e '\n'Es ist jetzt':' $(date) >> $logfile_script
}
function get_cur_tim {
	curtim_dat=$(date +"%Y-%m-%dT%H:%M:%S")
	curtim_sec=$(date --date=$curtim_dat +%s)
}
function get_end_tim {
	curtim_dat=$(date +"%Y-%m-%dT%H:%M:%S")
	curtim_sec=$(date --date=$curtim_dat +%s)
	endtim_sec=$(($curtim_sec+$timer))
	endtim_dat=$(date -d @$endtim_sec +"%a %e. %b %H:%M:%S %Z %Y")
}
function vpn_connect_initial_one {
	cleanup
	hopnr=0
	errorcount=0

	# Verbindung mit HOP-1 aufbauen
	# Einen Server aus dem Array picken, diesen aus dem Array entfernen und Array konsolidieren
	remux_server_list

	echo -e '\n'VPN-Verbindung Nr. "$[$hopnr+1]" wird aufgebaut nach':''\t''\t'"$server_name" >> $logfile_script
	sudo tmux new -d -s vpnhop$[$hopnr+1] openvpn --config $path_ovpn_conf"$naechster_server" --script-security 2 --route remote_host --persist-tun --up $path_ovpn_cascade_script --down $path_ovpn_cascade_script --route-noexec \; pipe-pane -o "cat > "$folder_logpath"'log.#S'"

	# warten, bis der Suchstring im Anschluss der erfolgreichen Verbindung gefunden wurde
	until grep 'Initialization Sequence Completed' "$folder_logpath"'log.vpnhop'"$[$hopnr+1]" >> /dev/null;
	do
		sleep 1;

		if [ $errorcount -eq $inc_timeout ];
		then
			echo -e TIMEOUT':' Verbindung zu HOP Nr. $[$hopnr+1] NICHT erfolgreich, nun von vorne beginnen'!' >> $logfile_script
			sudo echo Warten > $checkfile_watchdog
			kill_primary_process
		fi
		errorcount=$((errorcount+1))
	done
	# Verbindung erfolgreich aufgebaut
	echo -e VPN-Verbindung Nr. "$[$hopnr+1]" erfolgreich aufgebaut nach':''\t'"$server_name"'\n' >> $logfile_script
}
function vpn_connect_following_n {
	errorcount=0

	# bei Bedarf, die Verbindungen zu den weiteren HOPs innerhalb eines Loops
	if [ $maxhop -gt "1" ];
	then
		echo -e '==>' MaxHOP auf "$maxhop" festgelegt, nun folgen'/'folgt "$[$maxhop-1]" Verbindung'('en')''!''\n' >> $logfile_script
		while [ $hopnr -lt $[$maxhop-1] ]
		do
			double_time

			hopnr=$[$hopnr+1]
			# erstmal das zuletzt erhaltene Gateway pruefen, um dieses fuer die zweite Verbindung zu uebergeben
			gw_vorheriger_hop=$(grep 'VPN: gateway:' "$folder_logpath"'log.vpnhop'"$hopnr" | sed -e 's/^.\{,36\}//')
			# letztes Gateway wurde ermittelt und in eine Variable gespeichert
			echo -e Das Gateway von HOP Nr. $hopnr lautet':''\t''\t''\t'"$gw_vorheriger_hop"'\n' >> $logfile_script
			# Verbindung mit naechsten HOP aufbauen

			remux_server_list

			echo -e VPN-Verbindung Nr. "$[$hopnr+1]" wird aufgebaut nach':''\t''\t'"$server_name" >> $logfile_script
			sudo tmux new -d -s vpnhop$[$hopnr+1] openvpn --config $path_ovpn_conf"$naechster_server" --script-security 2 --route remote_host --persist-tun --up $path_ovpn_cascade_script --down $path_ovpn_cascade_script --route-noexec --setenv hopid $[$hopnr+1] --setenv prevgw $gw_vorheriger_hop \; pipe-pane -o "cat > "$folder_logpath"'log.#S'"
			# warten, bis der Suchstring im Anschluss der erfolgreichen Verbindung gefunden wurde
			until grep 'Initialization Sequence Completed' "$folder_logpath"'log.vpnhop'"$[$hopnr+1]" >> /dev/null;
			do
				sleep 1;

				if [ $errorcount -eq $inc_timeout ];
				then
					echo -e TIMEOUT':' Verbindung zu HOP Nr. $[$hopnr+1] NICHT erfolgreich, nun von vorne beginnen'!' >> $logfile_script
					sudo echo Warten > $checkfile_watchdog
					kill_primary_process
				fi
				errorcount=$((errorcount+1))
			done

			# Verbindung erfolgreich aufgebaut
			echo -e VPN-Verbindung Nr. "$[$hopnr+1]" erfolgreich aufgebaut nach':''\t'"$server_name"'\n' >> $logfile_script
		done
		echo -e Kaskade besteht jetzt'\n' >> $logfile_script
		echo $server_name > $checkfile_watchdog
	else
		echo -e MaxHOP auf "$maxhop" festgelegt, keine weiteren Verbindungen benoetigt'!''\n' >> $logfile_script
		echo $server_name > $checkfile_watchdog
	fi
}
#
### ENDE Definition von Funktionen ###
#
### HAUPTPROGRAMM ###

# so lange noch keine Verbindung besteht, einen Wartecode fuer den Watchdog schreiben
sudo echo Warten > $checkfile_watchdog

# im Watchdog-Script den selben Pfad zum Checkfile eintragen wie in diesem Script
sudo sed -i "/checkfile_watchdog=/c checkfile_watchdog=$checkfile_watchdog" $scriptfile_watchdog
sleep 0.2

# das Watchdog-Script soll auch im selben Verzeichnis sein LOG ablegen, wie das Hauptscript
sudo sed -i "/logfile_watchdog=/c logfile_watchdog="$folder_logpath"watchdog_openvpn_reconnect.log" $scriptfile_watchdog
sleep 0.2

# das Watchdog-Script soll auch wissen, in welchem Pfad dieses Script die LOG's ablegt
sudo sed -i "/folder_logpath=/c folder_logpath="$folder_logpath"" $scriptfile_watchdog
sleep 0.2

# den Watchdog-Service neustarten, damit dieser den neuen Pfad kennt und fehlerfrei laeuft
kill_watchdog_process
sleep 2

# wir benötigen das vorhandene Logverzeichnis, dieses anlegen, falls nicht schon vorhanden
sudo mkdir $folder_logpath

# Anzahl maximaler HOP's in das Perfect-Privacy-Script uebernehmen
sudo sed -i "/MAX_HOPID=/c MAX_HOPID=$maxhop" $path_ovpn_cascade_script

# j ist der Counter zum loeschen des LOG's -> Deklaration oben in den Variablendeklarationen (logdelete_count)
j=0

# alte offene VPN-Verbindungen und Terminals beenden + nicht mehr benoetigte LOG's loeschen
cleanup
# Nun laufen keine VPN-Verbindungen und Terminals mehr + unnoetige LOG's geloescht

# ueberpruefen, ob mehr Verbindungen erwuenscht sind, als Configs vorhanden
ermittle_server

if [ $maxhop -gt $server_list_count ];
then
	echo -e Maximale HOPs':''\t''\t''\t'$maxhop >> $logfile_script
	echo -e Anzahl Configs im Array':''\t'$server_list_count >> $logfile_script
	echo MaxHOP muss kleiner oder gleich Anzahl der Configs sein'!!!' >> $logfile_script
	echo Script wird nun laufend neugestartet, bis die Anzahl Configs passt'!' Bitte anpassen und den Dienst neu starten'!' >> $logfile_script
	echo Die Configs muessen sich hier befinden: $path_ovpn_conf >> $logfile_script
	sleep 20
	exit 1
fi
# Ueberpruefung abgeschlossen

### Beginn aeussere Schleife - Endlosschleife ###
while true
do
	# Endtime vorerst zuruecksetzen, damit die Schleife aufgerufen wird
	endtim_sec=0

	# Dauer der Verbindung ermitteln
	timer=$(shuf -i "$mintime"-"$maxtime" -n 1)

	# Timeout-Variable fuer diese Verbindungssitzung aus der Variablendeklaration uebernehmen
	inc_timeout=$timeoutcount

	echo   >> $logfile_script
	echo ------------------------------------------------------------------ >> $logfile_script
	echo Die folgende Verbindung bleibt fuer $timer Sekunden bestehen >> $logfile_script
	echo ------------------------------------------------------------------ >> $logfile_script

	write_timestamp

	### Beginn innere Schleife ###
	while [[ $endtim_sec -eq "0" ]] || [[ $curtim_sec -le $endtim_sec ]]
	do
		# pruefen, ob eine aktive VPN-Verbindung besteht
		wget -q -O - https://checkip.perfect-privacy.com/csv | grep perfect-privacy.com >> /dev/null

		if [ $? -eq "0" ];
		then
			# 10 Sekunden warten, bevor erneut geprueft wird
			sleep 10
			get_cur_tim
		else
			# alle Standort-Configs in einem Array ablegen
			ermittle_server
			# nun sind saemtliche Standort-Configs im Array

			# Erstmal die initiale Verbindung herstellen
			vpn_connect_initial_one
			# Initiale Verbindung steht

			# sollen nun weitere Verbindungen aufgebaut werden?
			# Falls maxhop > 1, dann los!
			vpn_connect_following_n

			get_end_tim

			echo -e Verbindungsstart':''\t'$(date) >> $logfile_script
			echo -e Verbindungsende':''\t'$endtim_dat >> $logfile_script
		fi
	done
	# raus aus der Schleife, da der Countdown abgelaufen ist, nun muessen die neuen Verbindungen aufgebaut werden
	### ENDE innere Schleife ###

	# nun dem Watchdog mitteilen, dass wieder bis zum naechsten Connect gewartet werden muss
	sudo echo Warten > $checkfile_watchdog

	echo Zeit abgelaufen'!' Die Verbindungen werden jetzt abgebaut'!' >> $logfile_script

	# alle VPN-Verbindungen beenden, damit Tunnel abgebaut werden
	cleanup

	# Counter zum leeren des LOG's inkrementieren
	j=$((j+1))

	# Nach n neuen Verbindungen soll das LOG geleert werden
	if [ $j -eq "$logdelete_count" ];
	then
		sudo echo > $logfile_script

		# den Counter nun wieder zuruecksetzen
		j=0
	fi
	# nun geht es wieder zurück zum Anfang der aeusseren Schleife

done
### ENDE aeussere Schleife ###
