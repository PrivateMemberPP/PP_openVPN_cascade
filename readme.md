# OpenVPN Kaskadierungs-Script für PerfectPrivacy

Dieses Repository besteht aus insg. 3 Scripten und 2 Services welche ermöglichen, bei Nutzung des VPN-Anbieters [PerfectPrivacy](https://www.perfect-privacy.com), eine automatische Kaskadierung auszuführen

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

Das Hauptscript befindet sich hier:
```
/etc/systemd/system/openvpn_service_restart_cascading.sh
```

## Built With

* NotePad++
* Love ♥

## Autoren

* **Patrick Meinhardt**

## Donate

Möchtest du meine Arbeit unterstützen?
Über eine kleine Donation an folgende PayPal.me-Adresse würde ich mich sehr freuen:

[PayPal.me](https://www.paypal.me/patricklwl)
