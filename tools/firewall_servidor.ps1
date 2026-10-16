# Libera a porta UDP do servidor no Firewall do Windows. EXECUTE COMO ADMINISTRADOR.
$port = 24600
$name = "Kaido Bakuso servidor"
if (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) {
    Write-Host "A regra '$name' ja existe."
} else {
    New-NetFirewallRule -DisplayName $name -Direction Inbound -Protocol UDP -LocalPort $port -Action Allow -Profile Private | Out-Null
    Write-Host "Regra criada: UDP $port liberada na rede privada."
}
