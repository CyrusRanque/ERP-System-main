# Allow Flutter phone / emulator to reach erp-server on this PC.
# Run once in PowerShell as Administrator:
#   powershell -ExecutionPolicy Bypass -File C:\ERP-System-main\erp-server\scripts\open-firewall-windows.ps1

$rules = @(
  @{
    Name = 'ERP Mobile API TCP 8000'
    Protocol = 'TCP'
    Port = 8000
  },
  @{
    Name = 'ERP Mobile API UDP 8001'
    Protocol = 'UDP'
    Port = 8001
  }
)

foreach ($rule in $rules) {
  $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Host "Rule already exists: $($rule.Name)"
    continue
  }
  New-NetFirewallRule `
    -DisplayName $rule.Name `
    -Direction Inbound `
    -Action Allow `
    -Protocol $rule.Protocol `
    -LocalPort $rule.Port `
    -Profile Private,Public,Domain | Out-Null
  Write-Host "Added: $($rule.Name)"
}

Write-Host 'Done. Phone should reach http://YOUR_PC_IP:8000/api/mobile/health on the same Wi-Fi.'
