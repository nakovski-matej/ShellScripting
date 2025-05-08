#!/usr/bin/env python3
# Dokumentation --------------------------
# Skript för att övervaka nätverkstrafik och blockera misstänkta IP-adresser
# Skapat av Matej, Maj 2025.

# Syfte:
# Läsa igenom loggen, leta efter misstänkt port, räkna IP-anslutningar
# Skicka varningsepost av fynd, spara rapporten
# ----------------------------------------------------

# Modulimporteringen ---------------------------------
import os  # För fil- och sökvägshantering
import logging  # För loggning av händelser
import time  # För att hantera tidsfördröjningar
import re  # För reguljära uttryck (används ej i denna kod)
import csv  # För att skriva rapporter i CSV-format
import smtplib  # För att skicka e-post
import subprocess  # För att köra systemkommandon
# ----------------------------------------------------

# Konfiguration --------------------------------------
LOG_FILE = os.path.join("/var/log", "monitor.log")  # Loggfil för skriptets loggning
TRAFFIC_LOG = os.path.join("/var/log/", "network_traffic.log")  # Loggfil för nätverkstrafik
EMAIL_FROM = "avsändare@gmail.com"  # Avsändarens e-postadress
EMAIL_TO = "mottagare@gmail.com"  # Mottagarens e-postadress
EMAIL_PASSWORD = "gmail-lösenord"  # Lösenord för e-postkontot
SUS_PORTS = set(range(1, 1024)) - {22, 80, 443}  # Misstänkta portar (exkluderar vanliga portar som SSH, HTTP, HTTPS)
MAX_CONNECTIONS = 2  # Max antal tillåtna anslutningar per IP
INTERVALL = 1000000  # Ej använd i koden
CSV_REPORT = "/var/log/suspicious_ips.csv"  # Fil för att spara rapporten
# ----------------------------------------------------

# Loggingfunktionaliteten -------------------------------
def setup_logging():
    """Konfigurerar loggning för skriptet."""
    logging.basicConfig(
        filename=LOG_FILE,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

def log_message(level, message):
    """Loggar ett meddelande med angiven nivå."""
    if level == "INFO":
        logging.info(message)
    if level == "WARNING":
        logging.warning(message)
    if level == "ERROR":
        logging.error(message)
# ------------------------------------------------------

def block_ip(ip):
    """Blockerar ett IP-adress med hjälp av UFW."""
    try:
        subprocess.run(["sudo", "ufw", "deny", "from", ip], check=True)
        print(f"[INFO] Blockerat IP: {ip}")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Kunde inte blockera IP {ip}: {e}")

# ------------------------------------------------------
# Startar loggning och kontrollerar om trafikloggen finns
setup_logging()
log_message("INFO", "Startar nätverkskontroll....")

if not os.path.exists(TRAFFIC_LOG):
    log_message("ERROR", "Loggfilen för trafik finns inte!")
    print("ERROR: Loggfilen för trafik saknas")
    exit(1)

try:
    count = 3  # Antal iterationer för kontroll
    while count > 0:
        connections = {}  # Dictionary för att hålla reda på IP-anslutningar

        # Öppnar trafikloggen och läser rader
        with open(TRAFFIC_LOG, "r") as file:
            for line in file:
                parts = line.strip().split(",")  # Delar upp raden i delar
                if len(parts) >= 4:  # Kontrollera att raden har tillräckligt många delar
                    ip = parts[1]  # IP-adressen finns i andra kolumnen
                    try:
                        port = int(parts[2])  # Porten finns i tredje kolumnen
                    except ValueError:
                        continue  # Hoppa över om porten inte är ett heltal

                    # Kontrollera om porten är misstänkt
                    if port in SUS_PORTS:
                        message = f"Hittade misstänkt port: {port} från IP {ip}"
                        log_message("WARNING", message)
                        print("WARNING:", message)

                        # Skicka varning via e-post
                        try:
                            server = smtplib.SMTP("smtp.gmail.com", 587)
                            server.starttls()
                            server.login(EMAIL_FROM, EMAIL_PASSWORD)
                            server.sendmail(
                                EMAIL_FROM,
                                EMAIL_TO,
                                f"Subject: Nätverksvarning\n\nMisstänkt portaktivitet från IP {ip} på port {port}"
                            )
                            server.quit()
                            log_message("INFO", "Skickade epostvarning")
                            print("INFO: Skickade epostvarning")
                        except:
                            log_message("ERROR", "Kunde inte skicka epost!")

                    # Uppdatera antalet anslutningar för IP
                    connections[ip] = connections.get(ip, 0) + 1

                    # Kontrollera om IP har för många anslutningar
                    if connections[ip] > MAX_CONNECTIONS:
                        message = f"IP: {ip} har för många anslutningar"
                        log_message("WARNING", message)
                        print("WARNING:", message)
                        block_ip(ip)  # Blockera IP

        # Skapa CSV-rapport om den inte finns
        if not os.path.exists(CSV_REPORT):
            with open(CSV_REPORT, mode="w", newline="") as csv_file:
                writer = csv.writer(csv_file)
                writer.writerow(["IP", "Antal"])  # Kolumnrubriker

        # Skriv resultaten till CSV-rapporten
        with open(CSV_REPORT, "w") as file:
            file.write("IP,Antal\n")
            for ip, count in connections.items():
                file.write(f"{ip},{count}\n")

        log_message("INFO", "Sparade resultat i csv")
        print("Sparat CSV-rapport")

        # Simulera ett kommando (ej relevant för funktionaliteten)
        try:
            result = subprocess.run(["ls", "/var/log/"], capture_output=True, text=True)
            log_message("INFO", "Simulerar blockering")
        except:
            log_message("ERROR", "Kunde inte köra kommandot")
            print("Kunde inte köra kommandot")

        log_message("INFO", "Klar med en kontroll")
        print("Klar med en kontroll")
        time.sleep(5)  # Vänta 5 sekunder innan nästa iteration
        count -= 1  # Minska antalet iterationer

    log_message("INFO", "Kontroll avklarad")
    print("Kontroll färdigställd")

except Exception as e:
    # Hantera oväntade fel
    log_message("ERROR", f"Något gick fel: {e}")
    print(f"ERROR: Något gick fel: {e}")
    exit(1)