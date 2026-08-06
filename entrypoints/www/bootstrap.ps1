<#
.SYNOPSIS
  Public bootstrap entrypoint for provisioning new Windows machines with my personal configuration.

.DESCRIPTION
  Nix does not run natively on Windows, so on this platform "install nix" from the top-level plan
  becomes "install a NixOS-based WSL distribution". This script:
    1. Installs Tailscale and joins the home tailnet (headscale.mmrh.nl).
    2. Enables WSL2 and provisions a NixOS-WSL distribution.
    3. Hands the rest of the provisioning over to that distribution.

  Invoked as:
    irm https://mmrh.nl/bootstrap.ps1 | iex

  Because it runs from memory (no local script file), it cannot resume itself across a reboot.
  Every step below checks whether its target state is already reached before acting, so if a
  reboot is required (enabling WSL features), just re-run the same command afterwards and it
  will continue where it left off.

.PARAMETER Preset
  Which WSL distribution to provision:
    - wsl-default : pre-built image from the private gitea (gitea.mmrh.nl), requires Tailscale.
    - wsl-minimal : pre-built image from the private gitea (gitea.mmrh.nl), requires Tailscale.
    - nixos-wsl   : latest official NixOS-WSL release from GitHub.

.PARAMETER DistroName
  Name to register the WSL distribution under. Defaults to the preset name.

.PARAMETER Unattended
  Skip interactive prompts. -Preset must be supplied.
#>
[CmdletBinding()]
param(
    [ValidateSet('wsl-default', 'wsl-minimal', 'nixos-wsl')]
    [string]$Preset,

    [string]$DistroName,

    [string]$TailnetTestHost = 'headscale.mmrh.nl',

    [switch]$Unattended
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BootstrapUrl = 'https://mmrh.nl/bootstrap.ps1'
$LinuxBootstrapUrl = 'https://mmrh.nl/bootstrap.sh'
$HeadscaleUrl = 'https://headscale.mmrh.nl'

$PresetSources = @{
    'wsl-default' = 'https://gitea.mmrh.nl/roelhem/generic/wsl-default/main/wsl-default.wsl'
    'wsl-minimal' = 'https://gitea.mmrh.nl/roelhem/generic/wsl-minimal/main/wsl-minimal.wsl'
}

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# STEP 0: Re-launch elevated. Everything below (Windows features, winget installs, .wslconfig)
# needs Administrator rights, and failing halfway through a feature install is painful to unwind.
function Assert-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Step 'Not running elevated, relaunching as Administrator...'
        $psArgs = @('-NoExit', '-Command', "irm $BootstrapUrl | iex")
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $psArgs
        exit 0
    }
}

# STEP 1: Gather system information and fail fast with a clear message instead of failing deep
# inside a feature install.
function Assert-SystemSupported {
    Write-Step 'Checking system requirements...'
    $build = [Environment]::OSVersion.Version.Build
    if ($build -lt 19041) {
        throw "Windows build $build is too old for WSL2 (need build 19041 / Windows 10 2004 or later)."
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget was not found. Install "App Installer" from the Microsoft Store, then re-run this script.'
    }
    $virtualization = (Get-ComputerInfo -Property HyperVRequirementVirtualizationFirmwareEnabled).HyperVRequirementVirtualizationFirmwareEnabled
    if ($virtualization -eq $false) {
        Write-Warning 'Virtualization does not appear to be enabled in firmware. Enable it in BIOS/UEFI if WSL install fails below.'
    }
}

# STEP 2: Ask for installation options (skipped if -Preset was passed, e.g. for unattended use).
function Select-Preset {
    if ($Preset) { return $Preset }
    if ($Unattended) { throw '-Preset is required when running with -Unattended.' }

    Write-Host ''
    Write-Host 'Which WSL preset should be installed?'
    Write-Host '  1) wsl-default  - pre-built config from the private gitea'
    Write-Host '  2) wsl-minimal  - pre-built minimal config from the private gitea'
    Write-Host '  3) nixos-wsl    - latest official NixOS-WSL release'
    $choice = Read-Host 'Enter 1, 2 or 3'
    switch ($choice) {
        '1' { return 'wsl-default' }
        '2' { return 'wsl-minimal' }
        '3' { return 'nixos-wsl' }
        default { throw "Unrecognized choice '$choice'." }
    }
}

# STEP 3: Install Tailscale if it isn't already.
function Install-Tailscale {
    if (Get-Command tailscale -ErrorAction SilentlyContinue) {
        Write-Step 'Tailscale is already installed.'
        return
    }
    Write-Step 'Installing Tailscale...'
    winget install --id Tailscale.Tailscale --exact --silent --accept-package-agreements --accept-source-agreements
}

# STEP 4: Log in to the home tailnet via headscale (no-op if already logged in).
function Connect-Tailscale {
    $status = & tailscale status --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($status -and $status.BackendState -eq 'Running') {
        Write-Step 'Tailscale is already connected.'
        return
    }
    Write-Step "Logging in to $HeadscaleUrl (follow the browser prompt)..."
    & tailscale up --login-server $HeadscaleUrl
}

# STEP 5: Verify the home network is actually reachable before relying on it to fetch anything.
function Test-HomeNetwork {
    Write-Step "Checking connectivity to $TailnetTestHost..."
    $result = Test-NetConnection -ComputerName $TailnetTestHost -Port 443 -WarningAction SilentlyContinue
    if (-not $result.TcpTestSucceeded) {
        throw "Could not reach $TailnetTestHost over Tailscale. Check 'tailscale status' and try again."
    }
}

# STEP 6: Enable WSL2. This can require a reboot on a fresh machine; if so, tell the user how to
# resume and stop, rather than trying to auto-resume a script that only exists in memory.
function Enable-Wsl {
    Write-Step 'Enabling WSL...'
    & wsl.exe --install --no-distribution | Out-Null

    $rebootPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    if ($rebootPending) {
        Write-Host ''
        Write-Host 'A reboot is required to finish enabling WSL.' -ForegroundColor Yellow
        Write-Host "Reboot, then re-run:  irm $BootstrapUrl | iex" -ForegroundColor Yellow
        exit 0
    }
}

# STEP 6.5: By default a WSL2 guest is NATed behind Windows and cannot see the host's Tailscale
# peers. Mirrored networking (Windows 11 22H2+) makes the guest share the host's network
# interfaces, including the Tailscale adapter, so the private gitea/nix flakes stay reachable
# from inside the distro too.
function Set-WslMirroredNetworking {
    $build = [Environment]::OSVersion.Version.Build
    if ($build -lt 22621) {
        Write-Warning 'Windows 11 22H2+ is required for WSL mirrored networking; skipping. The WSL guest may not be able to reach the tailnet directly.'
        return
    }

    $configPath = Join-Path $env:USERPROFILE '.wslconfig'
    $desiredLine = 'networkingMode=mirrored'
    $content = if (Test-Path $configPath) { Get-Content $configPath -Raw } else { '' }

    if ($content -match [regex]::Escape($desiredLine)) {
        return
    }

    Write-Step 'Configuring WSL mirrored networking...'
    if ($content -match '(?m)^\[wsl2\]') {
        $content = $content -replace '(?m)^\[wsl2\]', "[wsl2]`n$desiredLine"
    }
    else {
        $content += "`n[wsl2]`n$desiredLine`n"
    }
    Set-Content -Path $configPath -Value $content.Trim()
    & wsl.exe --shutdown
}

# STEP 7: Install the selected WSL distribution.
function Install-WslDistro {
    param([string]$SelectedPreset, [string]$Name)

    $existing = & wsl.exe --list --quiet 2>$null
    if ($existing -contains $Name) {
        Write-Step "WSL distribution '$Name' already installed."
        return
    }

    if ($SelectedPreset -eq 'nixos-wsl') {
        Write-Step 'Resolving latest NixOS-WSL release...'
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/nix-community/NixOS-WSL/releases/latest'
        $asset = $release.assets | Where-Object { $_.name -like '*.wsl' } | Select-Object -First 1
        if (-not $asset) { throw 'Could not find a .wsl asset in the latest NixOS-WSL release.' }
        $sourceUrl = $asset.browser_download_url
    }
    else {
        $sourceUrl = $PresetSources[$SelectedPreset]
    }

    $downloadPath = Join-Path $env:TEMP "$Name.wsl"
    Write-Step "Downloading $SelectedPreset from $sourceUrl..."
    Invoke-WebRequest -Uri $sourceUrl -OutFile $downloadPath -UseBasicParsing

    Write-Step "Installing WSL distribution '$Name'..."
    & wsl.exe --install --from-file $downloadPath --name $Name
    Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
}

# STEP 8: Hand over the rest of the provisioning to the distribution's own bootstrap.
function Invoke-Handoff {
    param([string]$Name)
    Write-Step "Handing off to WSL distribution '$Name'..."
    & wsl.exe -d $Name -- sh -c "echo 'TODO'"
}

try {
    Assert-Admin
    Assert-SystemSupported

    $selectedPreset = Select-Preset
    if (-not $DistroName) { $DistroName = $selectedPreset }

    Install-Tailscale
    Connect-Tailscale
    Test-HomeNetwork

    Enable-Wsl
    Set-WslMirroredNetworking
    Install-WslDistro -SelectedPreset $selectedPreset -Name $DistroName

    Invoke-Handoff -Name $DistroName

    Write-Step 'Done.'
}
catch {
    Write-Host "Bootstrap failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
