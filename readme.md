# OpenVPN Kaskadierungs-Script

Die installierte Anwendung besteht aus insg. 3 Scripten und 2 Services welche ermöglichen, bei Nutzung eines kompatiblen VPN-Anbieters, eine automatische Kaskadierung auszuführen.
Folgende Anbieter sind bekannt:

* [Perfect Privacy](https://www.perfect-privacy.com) --> getestet
* [oVPN](https://vcp.ovpn.to/) --> ungetestet
* [ZorroVPN](https://zorrovpn.com/) --> ungetestet


Durch Angabe einer maximalen Hopanzahl und einer min- sowie maxtime, können die Verbindungsparameter beinflusst werden.

Innerhalb der Variablendeklaration können viele Parameter eigens angepasst werden.

## Durchführung

Die folgende Anleitung beschreibt die Abhängigkeiten, Installation, Verzeichnisse sowie Anpassungsmöglichkeiten der Scripte und Dienste.

### Abhängigkeiten

Grundsätzlich werden bei der Ausführung des Installationsscripts sämtliche, benötigte Pakete auf vorhandensein überprüft und bei Bedarf installiert.
Dabei handelt es sich um folgende Pakete.

```
tmux
openvpn
resolvconf
psmisc
bc
```

### Installation

Mit nur einem Befehl wird das Installationsscript gestartet - der Rest geschieht von ganz allein.

```
sudo bash -c "$(wget -qO - https://raw.githubusercontent.com/PrivateMemberPP/PP_openVPN_cascade/master/install_ovpn_cascading.sh)"
```
#### Erstinstallation
Wenn es sich um eine Erstinstallation handelt, müssen die Hinweise im Terminalfenster beachtet werden.

#### Updateausführung
Bei einem Update kann das Script genau wie bereits beschrieben ausgeführt werden.
Es wird, anhand des Vorhandenseins des Hauptscripts, erkannt, dass es sich um ein Update handelt.
Sämtliche Variablendeklaration werden aus dem bisher produktiven Script übernommen und in das neue eingetragen.
Im Anschluss werden die Dienste wieder gestartet.

### Deinstallation
Auch die Deinstallation kann mit nur einem Befehl ausgeführt werden.
Am Ende sind keine Verweise, Dienste oder Informationen (LOG's...) mehr vorhanden.

```
sudo bash -c "$(wget -qO - https://raw.githubusercontent.com/PrivateMemberPP/PP_openVPN_cascade/master/uninstall_ovpn_cascading.sh)"
```

## Steuerung 

### Dienstverwaltung
Es gibt zwei Dienste für die folgenden Scripte:
* Hauptscript
* Watchdog-Script

Steuerung des Hauptscripts über folgenden Dienstnamen:
```
openvpn-restart-cascading.service
```

Steuerung des Watchdog-Scripts über folgenden Dienstnamen:
```
openvpn-restart-cascading-watchdog.service
```

### Variablen deklarieren
Es müssen lediglich die Variablen am Anfang des Hauptscripts definiert werden.
Sämtliche Variablen, welche für das Watchdog-Script abhängig sind, werden beim Start des Scripts/Dienstes automatisch übernommen.
Im Anschluss wird immer der Watchdog-Dienst neugestartet.

Das Hauptscript kann z.B. mit nano editiert werden:
```
sudo nano /etc/systemd/system/openvpn_service_restart_cascading.sh
```

Damit die Änderungen angewendet werden, muss der Dienst des Hauptscripts neugestartet werden, dies geschieht mit:
```
sudo systemctl restart openvpn-restart-cascading.service
```

Im Anschluss immer das LOG prüfen um zu sehen, dass die neuen Verbindungen aufgebaut werden:
```
less /var/log/ovpn_reconnect/vpnlog_restart.log
```

## Built With

* NotePad++
* Love ♥


## Donate

Möchtest du meine Arbeit unterstützen?
Über eine kleine Donation an folgende PayPal.me-Adresse würde ich mich sehr freuen:

[PayPal.me](https://www.paypal.me/patricklwl)
