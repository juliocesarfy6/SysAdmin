function Install-OpenSSHServer {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}

function Start-OpenSSHService {
    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd
}

function Configure-FirewallSSH {
    if (-Not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -Name "OpenSSH-Server-In-TCP" `
            -DisplayName "OpenSSH Server (TCP 22)" `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22
    }
}

function Check-SSHStatus {
    Get-Service sshd
}
