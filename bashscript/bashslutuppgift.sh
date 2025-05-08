#!/bin/bash
# slutuppgift.sh - Övervakning och loggning av en Linux-server
 
#Syfte:skapar Bash-skript som övervakar och analyserar säkerhetsloggar på en Ubuntu Server (/var/log/auth.log och /var/log/syslog) för att identifiera, rapportera och reagera på misstänkt aktivitet.
#Skapd av: Matej Nakovski
#Datum: 2025, april
 
# 1. Konfiguration
readonly REPORT="security_report_$(date +%Y%m%d).txt"      # Skapar rapportfil med dagens datum i filnamnet
readonly ACTION_LOG="/var/log/security_actions.log"        # Loggfil för åtgärder
readonly BACKUP_DIR="/backup/logs"                         # Mapp där gamla loggfiler sparas
 
echo "Varning: Startar säkerhetsanalys: $(date)"             # Skriver ut när analysen startar
 
# 2. Säkerhetsåtgärder
set -e     # Avslutar skriptet vid fel
set -u     # Avslutar skriptet om du försöker använda en variabel som inte är definierad
trap 'echo "Skript Avbrutet!" >&2; exit 1' INT TERM        
 
# 3. Hämta säkerhetsrelaterade loggar från igår.
grep -E "Failed password|Invalid user|Accepted password|session opened" /var/log/auth.log /var/log/syslog 2>/dev/null |  # Hämta loggar för misslyckade inloggningar och öppnade sessioner
grep "$(date --date="yesterday" '+%b %e')" > /tmp/security.log || true   # Sparar bara loggar från gårdagen i /tmp/security.log
 
# 4. Om inga loggar hittades då avslutas skriptet och skriver en enkel rapport
if [ ! -s /tmp/security.log ]; then
  echo "Säkerhetsrapport - $(date)" > "$REPORT"
  echo "Varning: Inga säkerhetsloggar hittades från igår." >> "$REPORT"
  echo "Varning: Inga misstänkta händelser eller IP adresser upptäckta." >> "$REPORT"
  echo "Varning: Färdig! Inga hot hittades. Rapport skapad."
  exit 1
fi
 
# 5. Hitta IP-adresser från misslyckade inloggningar
grep -E "Failed password|Invalid user" /tmp/security.log | \             # Välj bara rader med misslyckade försök
grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \                       # Plocka ut IP "from 123.456.78.90"
cut -d ' ' -f2 | \                                                       # Ta bara själva IP-adressen
sort | uniq -c > /tmp/iplist.txt                                         # Räkna antal per IP
 
# 6. Skapa rapportfil
echo "Säkerhetsrapport - $(date)" > "$REPORT"                            # Rubrik i rapporten
cat /tmp/security.log >> "$REPORT"                                       # Lägg till alla loggrader
echo "" >> "$REPORT"                                                     # Tom rad för att öka läsbarheten i rapporten
echo "Hög risk IP (mer än 20 försök):" >> "$REPORT"                      # Rubrik för högrisk
 
# 7. Blockera IP-adresser som försökt mer än 20 gånger
risk_found=false                                                         # Flagga för om något blockeras
 
while read COUNT IP; do
    if [ "$COUNT" -gt 20 ]; then                                         # Om IP förekommer mer än 20 gånger
      echo "[BLOCK] $IP - $COUNT försök"                                 # Skriv till terminalen
      echo "$IP - $COUNT försök" >> "$REPORT"                            # Skriv till rapporten
      ufw deny from "$IP" >> /dev/null                                   # Blockera IP i brandväggen
      echo "$(date): Blockerade $IP" >> "$ACTION_LOG"                    # Logga åtgärden i loggfil
      risk_found=true                                                    # Sätt flagga att något blockades
    fi
done < /tmp/iplist.txt
 
# Om inga IP:n blev blockerade, skriv det i rapporten
if [ "$risk_found" = false ]; then
  echo "Varning: Inga högrisk-IP:n upptäckta." >> "$REPORT"
fi
 
# 8. Arkivera gamla loggfiler som är äldre än 7 dagar
# Variabel för backupmapp
BACKUP_DIR="/backup/logs"

# Skapa backupmappen om den inte finns
mkdir -p "$BACKUP_DIR"

# Skapa tar-arkiv och ta bort loggar äldre än 7 dagar
find /var/log -type f \( -name "auth.log*" -o -name "syslog*" \) -mtime +7 -print0 | \
  tar --null -rvf "$BACKUP_DIR/logs_$(date +%Y%m%d).tar" --files-from=-

# Radera originalfilerna efter backup
find /var/log -type f \( -name "auth.log*" -o -name "syslog*" \) -mtime +7 -exec rm -f {} \;                                                       # Radera originalfilerna efter de har sparats
 
# 9. Ta bort temporära filer
rm -f /tmp/security.log /tmp/iplist.txt
 
# Slutmeddelande
echo "Varning: Färdig! Rapport skapad och åtgärder utförda: $(date)"
exit 1