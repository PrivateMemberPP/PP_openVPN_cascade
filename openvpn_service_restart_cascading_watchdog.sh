#!/bin/bash
#
### Variablen deklarieren ###
#
# Pfad zur Ablage saemtlicher Logfiles des Hauptscripts
folder_logpath=/var/log/ovpn_reconnect/
#
# Logfile fuer dieses Watchdog-Script
logfile_watchdog=/var/log/ovpn_reconnect/watchdog_openvpn_reconnect.log
#
# Checkfile fuer den Watchdog-Service
checkfile_watchdog=/var/log/ovpn_reconnect/exitnode.log
#
### ENDE Variablen deklarieren ###
#
### Definition von Funktionen ###
#
function checkfile {
        if [ -f "$checkfile_watchdog" ];
        then
                chkfl="1"
        else
                chkfl="0"
        fi
}
function get_state {
        sleep 4
        current_state=$(cat $checkfile_watchdog)
        sleep 0.1
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
        fi
}
function check_state {
        wget -O - -q --tries=3 --timeout=20 https://checkip.perfect-privacy.com/json | cut -d '"' -f 8 | grep "$current_state" >> /dev/null
        RET=$?
        pub_ip=$(wget -O - -q --tries=3 --timeout=20 https://checkip.perfect-privacy.com/json | cut -d '"' -f 8)
        sleep 1
}
function cleanup {
        sudo killall openvpn
        sudo tmux kill-server
}
function kill_primary_process {
        cleanup
        PID=$(sudo systemctl --property="MainPID" show openvpn-restart-cascading.service | cut -d '=' -f 2)
        sudo kill -9 "$(ps -o pgid= "$PID" | grep -o '[0-9]*')" > /dev/null
}
function log_delete {
        if [[ "$(wc -c $logfile_watchdog | cut -d ' ' -f 1)" -gt "20480" ]];
        then
                echo "" > $logfile_watchdog
        fi
}
function continuously_check {
        while [ -f "$checkfile_watchdog" ]
        do
                # aktuellen Dateiinhalt in eine Variable speichern
                get_state

                echo -e "\n\nVerbindung besteht seit:\t\t$(date)" >> $logfile_watchdog
                echo -e "mit oeffentlicher IP:\t\t\t$current_state" >> $logfile_watchdog

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
                                echo -e "Oeffentliche IP hat sich geaendert!"
                                echo -e "Dienste nun neustarten, damit ein sicherer Zustand wiederhergestellt werden kann!"
                        } >> $logfile_watchdog
                        kill_primary_process
                        sudo rm $checkfile_watchdog
                fi
                return
        done
}
#
### ENDE Definition von Funktionen ###
#
### HAUPTPROGRAMM ###
timeout=0

while true
do
        # Wenn das LOG groesser als 20MB ist, dieses leeren
        log_delete

        checkfile

        case "$chkfl" in
                # Datei existiert und kann kontinuierlich ausgewertet werden
                1)
                        get_state
                        case "$current_state" in
                                Warten)
                                        sleep 0.1
                                        timeout=0
                                        ;;
                                *)
                                        continuously_check
                                        timeout=0
                                        ;;
                        esac
                        ;;

                # Datei existiert noch nicht, erneut pruefen
                0)

                        sleep 0.1
                        timeout=$(("timeout" + "0.1"))

                        # falls nach einem gewissen Counter die Datei noch nicht existiert, stimmt irgendwas nicht
                        # fuer diesen Fall den primaeren Prozess neustarten
                        if [ "$timeout" -eq "10" ]
                        then
                                kill_primary_process
                        fi
                        ;;
        esac
done
