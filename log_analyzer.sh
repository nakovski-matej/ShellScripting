#!/bin/bash
# Matej Nakovski, 6 april 2025
#Ett skript för att analysera loggfiler och generera rapport


#Sökväg till loggfilen som ska analyseras
LOG_FILE="/var/log/syslog"

#Fil där analysrapporten sparas
REPORT_FILE="log_report.txt"

# Läser användarinput för att bestämma hur många rader som ska analyseras
echo "Ange max antal rader att analysera: "
read MAX_LINES

#Kontrollerar om loggfilen finns och är läsbar
if [ ! -r "$LOG_FILE" ]; then
   echo "Loggfilen hittades inte!"
   exit 1
fi

#Validerar att MAX_LINES är ett positivt heltal
if ! [[ "$MAX_LINES" =~ ^[0-9]+$ ]] || [ "$MAX_LINES" -le 0 ]; then 
   echo "Ogiltigt antal rader, ange ett positivt heltal!"
   exit 1
fi

#Loppar igenom de första MAX_LINES raderna i loggfilen
ERRO_COUNT=0
head -n "$MAX_LINES" "$LOG_FILE" | while read -r line; do
  ERRO_COUNT=$((ERRO_COUNT + $(echo "$line" | grep -c "eror")))
done

#Funktion för att generera en rapport baserat på logganalysen
generate_report() {
    > "$REPORT_FILE"
    echo "Logganalysrapport - $(date)" >> "REPORT_FILE"
    echo "Antal felmeddelande: $ERROR_COUNT" >> "$REPORT_FILE"
}

#Anropar rapportfuntionen
generaate_report

#Visar en sammanfattning av analyser för användaren
echo "Analysen är klar. $ERROR_COUNT fel hittades. Rapport sparad i $REPORT_FILE."
