# GearCheck

GearCheck prüft Skillung, Ausrüstung, Sockel und Verzauberungen des aktuellen Ziels oder der Gruppe. Das AddOn ist für World of Warcraft **3.3.5** (Interface `30300`) gedacht und spricht Deutsch und Englisch. Andere Client-Sprachen fallen auf Englisch zurück.

Die Rolle ergibt sich aus den Talentbäumen. Daraufhin werden Gegenstände, Edelsteine, Verzauberungen und Relikte daraufhin bewertet, ob ihre Werte zu Tank, Schaden, Zauberer oder Heiler passen.

## Installation

1. Den Ordner `GearCheck` nach `Interface/AddOns/` kopieren. Im Ordner müssen `GearCheck.toc` und die Lua-Dateien direkt liegen.
2. Im Charakterauswahlbildschirm das AddOn aktivieren.
3. Im Spiel `/gc` eingeben. Das Fenster öffnet sich.

Der Ordner `references/` gehört nicht zum AddOn und muss nicht mitinstalliert werden.

## Benutzung

Das Fenster lässt sich ziehen. Die Position wird in `GearCheckDB` gespeichert und beim nächsten Login wiederhergestellt. Escape schließt das Fenster.

| Aktion | Befehl |
| --- | --- |
| Fenster öffnen oder schließen | `/gc` oder `/gearcheck` |
| Ziel prüfen | `/gc ziel` oder `/gc target` |
| Gruppe oder Schlachtzug prüfen | `/gc gruppe`, `/gc group` oder `/gc raid` |
| Befunde flüstern | `/gc flüstern` oder `/gc whisper` |

Dieselben Aktionen liegen im Fenster auf den Schaltflächen **Ziel prüfen**, **Gruppe prüfen** und **Fehler flüstern**.

Oben fasst eine Zeile die Gruppe zusammen, etwa „22/25 Loot OK · 2 mit Befunden · 1 nicht prüfbar“. Der Balken darunter zeigt den Fortschritt der Prüfung. **Nur Probleme** blendet alle aus, die Loot OK sind; **Befunde zuerst** sortiert die Liste danach. Beide Schalter bleiben gespeichert.

Links steht die Spielerliste. Vor jedem Namen zeigt ein Häkchen, Kreuz oder eine Sanduhr das Loot-Urteil, danach folgen Klassen- und Rollen-Icon. Rechts steht `Loot OK` oder `Loot` mit der Zahl der Loot-Befunde; ein gelbes `+N` zählt die Hinweise. Ein Klick auf einen Namen öffnet die Details: Klasse, Stufe, durchschnittliche Gegenstandsstufe, Talentverteilung, die Ausrüstung und darunter die Abschnitte Loot, Hinweise, Meta-Edelstein und Verteidigung. Die Maus über einem Slot zeigt den Gegenstandstooltip und den Stand der Verzauberung. Umschalt-Klick fügt den Gegenstandslink in den Chat ein.

Beim Betrachten eines anderen Charakters sitzt rechts direkt am Betrachten-Fenster ein weiteres Fenster. Darin stehen Loot-Berechtigung, Rolle, Talentverteilung, Gegenstandsstufe und die Befunde. Der Pfeil oben klappt es ein und aus; die Wahl bleibt gespeichert. Gibt es Loot-Befunde, liegt unten **Fehler flüstern**. Die Nachfrage schickt sie nur an diesen Spieler.

An jedem Slot:

- Der Rahmen um das Icon hat die Qualitätsfarbe des Gegenstands.
- Unter der Gegenstandsstufe stehen kleine Icons: zuerst die Verzauberung (weiß: verzaubert, gelb: kleinere Fassung, rot: fehlt), dann die gesockelten Edelsteine und leere Sockel.
- Rot hinterlegt: der Slot hat einen Loot-Befund. Gelb hinterlegt: nur ein Hinweis.

Die Rolle neben der Gegenstandsstufe ist eingefärbt:

- Grün: der Gegenstand passt zur erkannten Rolle.
- Gelb: die Werte passen, gehören aber zu einer anderen Rolle.
- Rot: die Werte passen nicht.
- Grau: keine eindeutige Zuordnung, oder der Slot ist leer.

## Was geprüft wird

GearCheck inspiziert nur befreundete, verbundene und lebende Spieler in Reichweite. Der eigene Charakter wird ohne Inspect gelesen. Im Kampf pausiert die Warteschlange. Der Client lässt etwa sechs Inspects in zehn Sekunden zu; das AddOn hält einen kleinen Puffer ein und wartet danach von selbst.

Die Rolle kommt aus dem Talentbaum mit den meisten Punkten. Liegen dort weniger als 10 Punkte, oder führen zwei Bäume gleichauf, bleibt die Skillung unklar. Dann entfällt die Rollenprüfung; Sockel und Verzauberungen werden trotzdem geprüft. Blut-Todesritter und Bären-Druiden teilen sich den Baum mit der Schadens-Skillung; hier zählen zusätzliche Tank-Talente.

Bewertet werden Kopf, Hals, Schulter, Umhang, Brust, Handgelenke, Hände, Gürtel, Beine, Füße, beide Ringe, beide Schmuckstücke, Waffenhand, Schildhand und Fernkampf. Hemd und Wappenrock entfallen.

Es gibt zwei Arten von Befunden. **Loot-Befunde** verletzen die Loot-Regel „maximal gesockelt und verzaubert“ und gelten ab Stufe 80:

- Leere Sockel, auch der Meta-Sockel, und inaktive Meta-Edelsteine.
- Edelsteine und Verzauberungen unter der höchsten Fassung. Drachenaugen, die Alptraumträne und Berufsverzauberungen über der normalen Fassung gelten mit. Verzauberungen mit Zusatzeffekt (etwa Lauftempo oder Resistenz) gelten nicht als kleiner.
- Fehlende Verzauberung und fehlende Gürtelschnalle.
- Lücken bei Berufsboni. Berufe sieht man beim Betrachten nicht; GearCheck erkennt nur, wenn ein Bonus halb da ist: ein Ring verzaubert, der andere nicht (Verzauberer); Zusatzsockel an Handgelenken oder Händen, aber nicht an beiden (Schmied); ein oder zwei statt drei Drachenaugen (Juwelier).

**Hinweise** stehen gelb darunter und ändern nichts am Loot-Urteil:

- Gegenstand, Edelstein, Verzauberung oder Relikt passt nicht zur Rolle, oder stammt aus dem PvP.
- Meta-Edelstein passt nicht zur Rolle.
- Krieger- und Paladin-Tanks ohne Schild.
- Jäger ohne Fernkampfwaffe.
- Stufe-80-Tanks ohne Crit-Immunität. In den Details steht die Verteidigung; Abhärtung zählt mit, auch die Große Inschrift des Gladiators auf den Schultern. Die Runen des Steinhautgargoyles und des nerubischen Panzers zählen als Verteidigung, nicht als Wertung. Bären sind mit Überleben des Stärkeren 3/3 immun.

Fehlende Verzauberungen gelten für Kopf, Schulter, Umhang, Brust, Handgelenke, Hände, Beine, Füße und die Waffenhand. Die Schildhand nur, wenn dort ein Schild oder eine Waffe liegt, auch die Zweihandwaffe beim Titanengriff. Die Fernkampfwaffe nur bei Jägern.

## Flüstern

**Fehler flüstern** schickt die Loot-Befunde an alle geprüften Mitspieler, die welche haben. Hinweise werden nicht geflüstert. Der eigene Charakter ist ausgenommen. Vor dem Senden erscheint eine Bestätigung. Nachrichten beginnen mit `GearCheck:` und gehen im Abstand von etwa 1,5 Sekunden raus, damit das Chat-Limit nicht reißt. Längere Texte werden auf mehrere Flüstern aufgeteilt.

## Hinweise

- Leere Sockel, kleinere Edelsteine, kleinere Verzauberungen und fehlende Verzauberungen werden erst ab Stufe 80 gemeldet. Falsche Edelsteine und Verzauberungen gelten auf jeder Stufe.
- Manche Item-Links enthalten die Edelsteine erst nach kurzer Wartezeit. GearCheck wartet darauf. Bleiben alle Sockel leer, erscheint ein Hinweis, dass die Daten vom Server fehlen können.
- Die Liste zeigt höchstens 40 Spieler.
- Die Bewertung folgt festen Wertungsregeln für Tank, physischen Schaden, Zauberer und Heiler. Hybrid-Ausrüstung kann deshalb gelb oder rot markiert werden, auch wenn sie absichtlich gemischt ist.
