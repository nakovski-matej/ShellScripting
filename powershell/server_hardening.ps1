# Skript för att härda en Windows-server genom att förbättra säkerheten.
# Det aktiverar brandvägg, kontrollerar Windows Defender, hanterar användare, 
# inaktiverar osäkra protokoll, stoppar onödiga tjänster, hanterar diskar och aktiverar BitLocker.

# Skapar en loggfil för att spara alla åtgärder
$logFile = "security_hardening_$(Get-Date -Format 'yyyyMMdd').log"
function Log {
    param ($msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $logFile -Append
}

Log "--- Startar säkerhetsgranskning och härdning ---"

# 1. Aktivera Windows-brandvägg för alla profiler (Domain, Private, Public)
foreach ($profile in ('Domain', 'Private', 'Public')) {
    Set-NetFirewallProfile -Profile $profile -Enabled True
    Log "Aktiverade brandvägg för $profile-profil."
}

# Rensar brandväggsregler och tillåter endast RDP (3389) och HTTPS (443)
Get-NetFirewallRule | Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' -and $_.Protocol -ne 'TCP' -and $_.LocalPort -notin 443, 3389 } | Remove-NetFirewallRule
Log "Rensade brandväggsregler, tillåter endast RDP och HTTPS."

# 2. Kontrollera och aktivera Windows Defender
$defender = Get-MpComputerStatus
if (-not $defender.AntispywareEnabled) {
    Set-MpPreference -DisableRealtimeMonitoring $false
    Log "Aktiverade Windows Defender."
}
Update-MpSignature  # Uppdaterar Defender-signaturer
Start-MpScan -ScanType FullScan  # Kör en fullständig skanning
Log "Kör fullständig Defender-skanning."

# 3. Hantera administratörsgruppsanvändare
# Tar bort användare från Administrators-gruppen som inte finns i approved_users.txt
$approvedUsers = Get-Content .\approved_users.txt
$adminGroup = Get-LocalGroupMember -Group "Administrators"
foreach ($user in $adminGroup) {
    if ($approvedUsers -notcontains $user.Name) {
        Remove-LocalGroupMember -Group "Administrators" -Member $user.Name
        Log "Tog bort icke-godkänd användare: $($user.Name) från Administrators-gruppen."
    }
}

# Inaktiverar användarkonton som varit inaktiva i mer än 90 dagar
$threshold = (Get-Date).AddDays(-90)
Get-LocalUser | Where-Object { $_.LastLogon -lt $threshold -and $_.Enabled } | ForEach-Object {
    Disable-LocalUser -Name $_.Name
    Log "Inaktiverade användare inaktiva i >90 dagar: $($_.Name)"
}

# 4. Inaktivera SMBv1 (osäkert protokoll)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0 -Force
Log "Inaktiverade SMBv1 via registret."

# 5. Stoppa onödiga tjänster (t.ex. Telnet och FTP)
$unneededServices = @('Telnet', 'FTPSVC')
foreach ($svc in $unneededServices) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Stop-Service -Name $svc -Force
        Set-Service -Name $svc -StartupType Disabled
        Log "Inaktiverade tjänst: $svc"
    }
}

# 6. Kontrollera diskar och frigör utrymme om det är mindre än 15% ledigt
$drives = Get-PSDrive -PSProvider FileSystem
foreach ($drive in $drives) {
    $free = ($drive.Free / $drive.Used) * 100
    if ($free -lt 15) {
        $archivePath = "$($drive.Root)temp_archive"
        New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
        Get-ChildItem "$($drive.Root)\Temp" -Recurse | Move-Item -Destination $archivePath -Force
        Log "Flyttade temporära filer till arkiv på $($drive.Root)"
    }
}

# 7. Aktivera BitLocker om det inte redan är aktiverat
$bitlockerStatus = Get-BitLockerVolume -MountPoint C:
if ($bitlockerStatus.ProtectionStatus -ne 'On') {
    Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256 -UsedSpaceOnly -TpmProtector
    Log "Aktiverade BitLocker på systemdisken."
}

Log "--- Härdning slutförd ---"
Write-Output "Säkerhetshärdning är klar. Se $logFile för detaljer."