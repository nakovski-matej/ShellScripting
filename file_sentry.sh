#!/bin/bash
#file_sentry.sh - Övervakar en katalog för misstänka filer
# Skapat av: Matej Nakovski, April 7 2025

readonly LOG_FILE="$HOME/file_sentry.log" # Loggfil i hemmappen
readonly TEMP_FILE="/tmp/file.sentry.log_$$.tmp" # Temporär fil med unikt namn
readonly SIZE_THRESHOLD=1048576 # 1 MB i bytes
readonly TARGET_DIR="$1" #Första argumentet är katalogen

#readonly gör variablerna skrivskyddade för säkerhet.
# $$ är process-ID för att undvika konfikter i temporära filer.
# $1 tar katalogen från kommandoraden

#Lägg till säkerhetsåtgärder

set -e #Avsluta vid fel
set -u #Fel om odefinierade variable används
trap 'echo "Skript avbrutet!"; rm -f "$TEMP_FILE"; exit 1' INT TERM EXIT # Detta skyddar mot öväntade problem och rensar upp vid avbrott

#Skapa en loggningsfunktion
# Lägg till en funktion för att logga meddelande
log_message() {
    local level="$1" #INFO, WARNING, ERROR
    local message="$2"
    printf "%s [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$LOG_FILE"
}
# Funktionen skriver tidstämplar och nivåer till loggfilen- viktigt för spårbarhet.

# Kontrollera att användaren angav en katalog och att den existerar:
if [[ -z "$TARGET_DIR" ]]; then
     log_message "EROR" "Ingen katalog angiven. Använd: ./file_sentry.sh <katalog>"
     echo "Fel: Ange en katalog!" >&2
     exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    log_message "EROR" "$TARGET_DIR är inte en katalog."
    echo "Fel: $TARGET_DIR finns inte eller är ingen katalog!" >&2
    exit
fi
