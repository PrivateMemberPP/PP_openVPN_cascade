#!/bin/bash
#
### Variablen deklarieren ###
#
# Pfad zur Ablage saemtlicher Logfiles dieses Scripts
folder_logpath=/var/log/ovpn_reconnect/
#
# Logfilename fuer dieses Script (nur den Namen anpassen!)
logfile_script="$folder_logpath"vpnlog_restart.log
#
# Pfad zu den OpenVPN-Configs, welche genutzt werden sollen
path_ovpn_conf=/etc/openvpn/connections/
#
# Pfad zum updown-Kaskadierungsscript
path_ovpn_cascade_script=/etc/openvpn/updown.sh
#
# Checkfile fuer den Watchdog-Service (nur den Namen anpassen!)
checkfile_watchdog="$folder_logpath"exitnode.log
#
# Pfad zur Watchdog-Script-Datei (openvpn_service_restart_cascading_watchdog.sh)
scriptfile_watchdog=/etc/systemd/system/openvpn_service_restart_cascading_watchdog.sh
#
# minimale Verbindungsdauer in Sekunden
mintime=20000
#
# maximale Verbindungsdauer in Sekunden
maxtime=30000
#
# Wie viele HOPs sollen verbunden werden?
maxhop=2
#
# Timeout-Counter (in Sekunden) zum Verbindungsaufbau (Wert wird je HOP um 10 Sekunden verlaengert)
# HINWEIS: die erste Verbindung benoetigt i.d.R. '16' Sekunden
timeoutcount=20
#
# Dateiname dieses Scripts OHNE Pfad
my_name=${0##*/}
#
# Dateiname Watchdog-Skript OHNE Pfad
wd_name=${scriptfile_watchdog##*/}
#
### ENDE Variablen deklarieren ###

### Definition von Funktionen ###

function cleanup {
	killall openvpn > /dev/null
	sleep 2
	tmux kill-server > /dev/null
	sleep 0.5
	rm -rf "$folder_logpath"log.vpnhop* > /dev/null
	sleep 0.2
}
function kill_primary_process {
	cleanup
	PID=$(pgrep -f "$my_name")
	sleep 0.5
	sudo kill -9 "$PID" > /dev/null
}
function kill_watchdog_process {
	PID=$(pgrep -f "$wd_name")
	sleep 0.5
	sudo kill -9 "$PID" > /dev/null
}
function ermittle_server {
	mapfile -t server_list < <(eval ls -1 "$path_ovpn_conf"'*.conf' | sed 's/,//g' | rev |  cut -d '/' -f 1 | rev)
	server_list_count="${#server_list[@]}"
}
function remux_server_list {
	server_count="${#server_list[@]}"
	random=$(shuf -i 0-$((server_count-1)) -n 1)
	naechster_server=${server_list[$random]}
	server_name=$(echo "$naechster_server" | cut -d '.' -f1)
	unset 'server_list[$random]'
	server_list_temp=("${server_list[@]}")
	server_list=("${server_list_temp[@]}")
	unset server_list_temp
}
function incr_time {
	inc_timeout=$(("$inc_timeout"+"10"))
}
function get_last_gw {
	# das Gateway der vorherigen Verbindung ermitteln
	gw_vorheriger_hop=$(grep 'VPN: gateway:' "$folder_logpath"'log.vpnhop'"$((hopnr-1))" | sed -e 's/^.\{,36\}//')
	# letztes Gateway wurde ermittelt und in eine Variable gespeichert
}
function write_timestamp {
	echo -e "Es ist jetzt:\t\t$(date)" >> $logfile_script
}
function get_cur_tim {
	curtim_dat=$(date +"%Y-%m-%dT%H:%M:%S")
	curtim_sec=$(date --date="$curtim_dat" +%s)
}
function get_end_tim {
	curtim_dat=$(date +"%Y-%m-%dT%H:%M:%S")
	curtim_sec=$(date --date="$curtim_dat" +%s)
	endtim_sec=$((curtim_sec+timer))
	endtim_dat=$(date -d @$endtim_sec +"%a %b %e %H:%M:%S %Z %Y")
}
function vpn_connect_initial_one {
	echo -e "\nVPN-Verbindung Nr. $hopnr wird aufgebaut nach:\t\t$server_name" >> $logfile_script
	tmux new -d -s vpnhop"$hopnr" openvpn --config $path_ovpn_conf"$naechster_server" --script-security 2 --route remote_host --persist-tun --up $path_ovpn_cascade_script --down $path_ovpn_cascade_script --route-noexec \; pipe-pane -o "cat > $folder_logpath'log.#S'"

	# warten, bis der Suchstring im Anschluss der erfolgreichen Verbindung gefunden wurde
	until grep 'Initialization Sequence Completed' "$folder_logpath"'log.vpnhop'"$hopnr" >> /dev/null;
	do
		sleep 0.2;

		if (( $(echo "$errorcount > $inc_timeout" | bc -l) ));
		then
			echo -e "TIMEOUT: Verbindung zum $hopnr. HOP Server: $server_name NICHT erfolgreich, erneut versuchen!" >> $logfile_script
			return=1
			return
		fi
		errorcount=$(echo "$errorcount+0.2" | bc)
	done
	# Verbindung erfolgreich aufgebaut
	echo -e "VPN-Verbindung Nr. $hopnr erfolgreich aufgebaut nach:\t$server_name\n" >> $logfile_script
	return=0
}
function vpn_connect_following_n {
	echo -e "\nVPN-Verbindung Nr. $hopnr wird aufgebaut nach:\t\t$server_name" >> $logfile_script
	tmux new -d -s vpnhop"$hopnr" openvpn --config $path_ovpn_conf"$naechster_server" --script-security 2 --route remote_host --persist-tun --up $path_ovpn_cascade_script --down $path_ovpn_cascade_script --route-noexec --setenv hopid "$hopnr" --setenv prevgw "$gw_vorheriger_hop" \; pipe-pane -o "cat > $folder_logpath'log.#S'"

	# warten, bis der Suchstring im Anschluss der erfolgreichen Verbindung gefunden wurde
	until grep 'Initialization Sequence Completed' "$folder_logpath"'log.vpnhop'"$hopnr" >> /dev/null;
	do
		sleep 0.2;

		if (( $(echo "$errorcount > $inc_timeout" | bc -l) ));
		then
			echo -e "TIMEOUT: Verbindung zum $hopnr. HOP Server: $server_name NICHT erfolgreich, erneut versuchen!" >> $logfile_script
			return=1
			return
		fi
		errorcount=$(echo "$errorcount+0.2" | bc)
	done
	# Verbindung zu HOP erfolgreich aufgebaut
	echo -e "VPN-Verbindung Nr. $hopnr erfolgreich aufgebaut nach:\t$server_name\n" >> $logfile_script
	return=0
}
#
### ENDE Definition von Funktionen ###
#
### HAUPTPROGRAMM ###

# so lange noch keine Verbindung besteht, einen Wartecode fuer den Watchdog schreiben
echo "Warten" > $checkfile_watchdog

# im Watchdog-Script den selben Pfad zum Checkfile eintragen wie in diesem Script
sed -i "/checkfile_watchdog=/c checkfile_watchdog=$checkfile_watchdog" $scriptfile_watchdog
sleep 0.2

# das Watchdog-Script soll auch im selben Verzeichnis sein LOG ablegen, wie das Hauptscript
sed -i "/logfile_watchdog=/c logfile_watchdog=${folder_logpath}watchdog_openvpn_reconnect.log" $scriptfile_watchdog
sleep 0.2

# das Watchdog-Script soll auch wissen, in welchem Pfad dieses Script die LOG's ablegt
sed -i "/folder_logpath=/c folder_logpath=${folder_logpath}" $scriptfile_watchdog
sleep 0.2

# den Watchdog-Service neustarten, damit dieser den neuen Pfad kennt und fehlerfrei laeuft
kill_watchdog_process
sleep 2

# wir benoetigen das vorhandene Logverzeichnis, dieses anlegen, falls nicht schon vorhanden
if [[ ! -d "$folder_logpath" ]];
then
	mkdir $folder_logpath
fi

# Anzahl maximaler HOP's in das Perfect-Privacy-Script uebernehmen
sed -i "/MAX_HOPID=/c MAX_HOPID=$maxhop" $path_ovpn_cascade_script

# ueberpruefen, ob mehr Verbindungen erwuenscht sind, als Configs vorhanden
# so wird auch schon Mal das Array mit saemtlichen Verbindungen angelegt
ermittle_server

if [ "$maxhop" -gt "$server_list_count" ];
then
	{
		echo -e "Maximale HOPs:\t\t\t$maxhop"
		echo -e "Anzahl Configs im Array:\t$server_list_count"
		echo "MaxHOP muss kleiner oder gleich Anzahl der Configs sein!!!"
		echo "Script wird nun laufend neugestartet, bis die Anzahl Configs passt! Bitte anpassen und den Dienst neu starten!"
		echo "Die Configs muessen sich hier befinden: $path_ovpn_conf"
	} >> $logfile_script
	sleep 20
	exit 1
fi
# Ueberpruefung abgeschlossen

### Beginn aeussere Schleife - Endlosschleife ###
while true
do
	# 'k' ist die Zaehlvariable fuer das Array, welches sich unsere Verbindungen merkt
	k=0

	# Aufraeumen, bevor es mit den Verbindungen losgeht
	cleanup

	# Endtime vorerst zuruecksetzen, damit die Schleife aufgerufen wird
	endtim_sec=0

	# Flag setzen welches mitteilt, dass KEINE Verbindung zu Beginn der Schleife besteht
	connected_check=0

	# Dauer der Verbindung ermitteln
	timer=$(shuf -i "$mintime"-"$maxtime" -n 1)

	# Timeout-Variable fuer diese Verbindungssitzung aus der Variablendeklaration uebernehmen
	inc_timeout=$timeoutcount

	{
		echo -e "\n\n------------------------------------------------------------------"
		echo "Die folgende Verbindung bleibt fuer $timer Sekunden bestehen"
		echo "------------------------------------------------------------------"
	} >> $logfile_script

	write_timestamp

	### Beginn innere Schleife ###
	while [[ "$endtim_sec" -eq "0" ]] || [[ "$curtim_sec" -le "$endtim_sec" ]]
	do
		# aktuellen Verbindungsstatus aus dem Checkfile lesen und in eine Variable speichern
		current_state=$(cat $checkfile_watchdog)

		# pruefen, eine Verbindung besteht / der Ausgangsserver verwendet wird
		if wget -O - -q --tries=3 --timeout=20 https://checkip.perfect-privacy.com/json | cut -d '"' -f 8 | grep "$current_state" >> /dev/null
		then
			# 10 Sekunden warten, bevor erneut geprueft wird
			sleep 10
			get_cur_tim
		else
			if [ "$connected_check" -eq "0" ];
			then
				hopnr=1
				errorcount=0

				# Serverliste muss erneut eingelesen werden
				ermittle_server

				# den ersten Server ermitteln und das Array konsolidieren
				remux_server_list

				# die initiale Verbindung aufbauen
				vpn_connect_initial_one

				# falls Verbindungsaufbau NICHT OK -> mit neuen Server versuchen
				while [ ! "$return" -eq "0" ]
				do
					if [ "$(("${#server_list[@]}"-"$maxhop"+"hopnr"))" -gt "0" ];
					then
						tmux kill-session -t vpnhop"$hopnr"
						rm -rf "$folder_logpath"log.vpnhop"$hopnr"
						errorcount=0

						# den ersten Server erneut ermitteln und das Array konsolidieren
						remux_server_list

						# die initiale Verbindung erneut versuchen aufzubauen
						vpn_connect_initial_one
					else
						echo -e "\n\nVerbindungsproblem!" >> $logfile_script
						echo -e "-------------------" >> $logfile_script
						write_timestamp
						echo -e "\nEs bleiben keine funktionalen Server uebrig!\n" >> $logfile_script
						echo -e "Nun komplett von vorne beginnen!" >> $logfile_script
						exit 1
					fi
				done
				# Initiale Verbindung steht

				# Servernamen der Verbindung in einem Array speichern
				con_servers[$k]=$server_name
				k=$((k+1))
				hopnr=$((hopnr+1))

				# sollen nun weitere Verbindungen aufgebaut werden?
				# Falls maxhop > 1, dann los!
				if [ "$maxhop" -gt "1" ];
				then
					echo -e "==> MaxHOP auf $maxhop festgelegt, nun folgen/folgt $((maxhop-1)) Verbindung(en)!\n" >> $logfile_script

					while [ "$hopnr" -le "$maxhop" ]
					do
						errorcount=0

						# wir benoetigen fuer die folgenden Verbindungen jeweils das vorherige Gateway
						get_last_gw

						echo -e "Das Gateway von HOP Nr. $((hopnr-1)) lautet:\t\t\t$gw_vorheriger_hop\n" >> $logfile_script

						# fuer jeden weiteren Hop soll das Timeout inkrementiert werden
						incr_time

						# den jeweils naechsten Server ermitteln und im Anschluss das Array konsolidieren
						remux_server_list

						# nun die jeweils folgende Verbindung aufbauen
						vpn_connect_following_n

						# falls Verbindungsaufbau NICHT OK -> mit neuen Server versuchen
						while [ ! "$return" -eq "0" ]
						do
							if [ "$(("${#server_list[@]}"-"$maxhop"+"hopnr"))" -gt "0" ];
							then
								tmux kill-session -t vpnhop"$hopnr"
								rm -rf "$folder_logpath"log.vpnhop"$hopnr"
								errorcount=0

								# den jeweils naechten Server erneut ermitteln und das Array konsolidieren
								remux_server_list

								# die naechste Verbindung erneut versuchen aufzubauen
								vpn_connect_following_n
							else
								echo -e "\n\nVerbindungsproblem!" >> $logfile_script
								echo -e "-------------------" >> $logfile_script
								write_timestamp
								echo -e "\nEs bleiben keine funktionalen Server uebrig!\n" >> $logfile_script
								echo -e "Nun komplett von vorne beginnen!" >> $logfile_script
								exit 1
							fi
						done

						# Servernamen der jeweiligen Verbindungen in einem Array speichern
						con_servers[$k]='==>'
						k=$((k+1))
						con_servers[$k]=$server_name
						k=$((k+1))
						hopnr=$((hopnr+1))
					done
				else
					echo -e "MaxHOP auf $maxhop festgelegt, keine weiteren Verbindungen benoetigt!" >> $logfile_script
				fi

				# in das Watchdog-Checkfile unsere Ausgangs-IP abspeichern
				wget -O - -q --tries=3 --timeout=20 https://checkip.perfect-privacy.com/json | cut -d '"' -f 8 > $checkfile_watchdog

				if [ "$maxhop" -gt "1" ];
				then
					echo -e "Kaskade besteht jetzt wie folgt:" >> $logfile_script
					echo "${con_servers[*]}" >> $logfile_script
				fi

				# ermitteln der Endzeit (Zeitpunkt JETZT + ermittelter Random-Wert)
				get_end_tim

				echo -e "\n\nVerbindungsstart:\t$(date)" >> $logfile_script
				echo -e "Verbindungsablauf:\t$endtim_dat" >> $logfile_script

				# nun sind wir endgueltig verbunden und setzen als Merker ein Flag
				connected_check=1
			else
				# falls das Flag fuer connected_check auf 1 gesetzt ist und wir hier rein rutschen, stimmt irgendetwas mit der Verbindung nicht
				echo -e "\n\nVerbindungsproblem!" >> $logfile_script
				echo -e "-------------------" >> $logfile_script
				write_timestamp
				echo -e "\nWarten auf Watchdog-Dienst, bis Prozesse neugestartet werden!" >> $logfile_script
				sleep 20

				# ACHTUNG: falls der Watchdog nicht laeuft, einfach ab hier beenden
				exit 1
			fi
		fi
	done
	# raus aus der Schleife, da der Countdown abgelaufen ist, nun alles abbauen und danach wieder zum Schleifenanfang (aeussere Schleife) gehen
	### ENDE innere Schleife ###

	# dem Watchdog mitteilen, dass wieder bis zum naechsten Connect gewartet werden muss
	echo "Warten" > $checkfile_watchdog

	echo "Zeit abgelaufen! Die Verbindungen werden jetzt abgebaut!" >> $logfile_script

	# Wenn das LOG groesser als 20MB ist, dieses leeren
	if [[ "$(wc -c $logfile_script | cut -d ' ' -f 1)" -gt "20480" ]];
	then
		echo "" > $logfile_script
	fi

	# das Array mit den gespeicherten Servern loeschen
	unset con_servers

# nun geht es wieder zurueck zum Anfang der aeusseren Schleife
done
### ENDE aeussere Schleife ###
