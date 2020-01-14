# OpenVPN Kaskadierungs-Script für PerfectPrivacy

Dieses Repository besteht aus insg. 3 Scripten und 2 Services welche ermöglichen, bei Nutzung des VPN-Anbieters [PerfectPrivacy](https://www.perfect-privacy.com), eine automatische Kaskadierung auszuführen

Durch Angabe einer maximalen Hopanzahl und einer min- sowie maxtime, können die Verbindungsparameter beinflusst werden.

Innerhalb der Variablendeklaration können viel Parameter eigens angepasst werden.

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
Bei einem Update kann das Script genau wie bereits beschrieben ausgführt werden.
Es wird anhand des vorhandenseins des Hauptscript erkannt, dass es sich um ein Update handelt.
Sämtliche Variablendeklaration werden aus dem bisher produktiven Script übernommen und in das neue eingetragen.
Im Anschluss werden die Dienste wieder gestartet.

## Steuerung 

### Dienstverwaltung

### Variablen deklarieren

## Built With

* NotePad++
* Love ♥

## Autoren

* **Patrick Meinhardt**

## Donate

Möchtest du meine Arbeit unterstützen?
Über eine kleine Donation an folgende PayPal.me-Adresse wuerde ich mich sehr freuen:

[PayPal.me](https://www.paypal.me/patricklwl)

