<#
.SYNOPSIS
    Ultimate AI Audio Transcription Environment Setup
.DESCRIPTION
    ������ ���������� ������� ��� ������ � Whisper � Pyannote:
    - �������������� ��������� ���� ������������
    - ����� �������� �����������
    - ��������� GPU/CUDA
    - ��������� �����
#>

#region Initial Setup
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# �������� ���� ��������������
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[������] ��������� ����� ��������������!`n��������� ������ �� ����� ��������������." -ForegroundColor Red
    exit 1
}

# �������� �����
$colors = @{
    "header" = "Cyan"
    "success" = "Green"
    "warning" = "Yellow"
    "error" = "Red"
    "info" = "Gray"
}
#endregion

#region Helper Functions
function Test-CommandExists($command) {
    try { return (Get-Command $command -ErrorAction Stop) -ne $null }
    catch { return $false }
}

function Test-PythonPackageInstalled($package) {
    try { return (pip show $package -ErrorAction Stop) -ne $null }
    catch { return $false }
}

function Get-GPUInfo {
    try {
        $gpu = (Get-WmiObject Win32_VideoController).Name | Where-Object { $_ -notmatch "Microsoft Basic Display" }
        return @{
            HasGPU = [bool]$gpu
            IsNVIDIA = $gpu -match "NVIDIA"
            Info = if ($gpu) { $gpu -join ", " } else { "�� ���������" }
        }
    }
    catch { return @{ HasGPU = $false; IsNVIDIA = $false; Info = "������ ��������" } }
}

function Get-CUDAVersion {
    try {
        if (Test-Path "$env:CUDA_PATH\bin\nvcc.exe") {
            $version = & "$env:CUDA_PATH\bin\nvcc.exe" --version | Select-String -Pattern "release (\d+\.\d+)"
            return $version.Matches.Groups[1].Value
        }
        return $null
    }
    catch { return $null }
}
#endregion

#region Main Installation
Write-Host "`n=== ��������� ����� �����-������������� ===`n" -ForegroundColor $colors.header

# 1. Chocolatey Setup
Write-Host "[1/5] �������� CHOCOLATEY..." -ForegroundColor $colors.header
if (-not (Test-CommandExists "choco")) {
    Write-Host "��������� Chocolatey..." -ForegroundColor $colors.warning
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex (New-Object Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')
    refreshenv
}
Write-Host "Chocolatey �����" -ForegroundColor $colors.success

# 2. System Dependencies
Write-Host "`n[2/5] ��������� �����������..." -ForegroundColor $colors.header

$apps = @(
    @{ Name = "ffmpeg"; Test = { Test-Path "$env:ProgramFiles\FFmpeg\bin\ffmpeg.exe" } }
    @{ Name = "cmake"; Version = "3.31.6"; Test = { Test-CommandExists "cmake" }; Params = 'ADD_CMAKE_TO_PATH=System' }
)

foreach ($app in $apps) {
    if (-not (& $app.Test)) {
        Write-Host "��������� $($app.Name)..." -ForegroundColor $colors.warning
        $args = @("-y")
        if ($app.Version) { $args += "--version=$($app.Version)" }
        if ($app.Params) { $args += "--params=`"$($app.Params)`"" }
        choco install $app.Name @args
    }
    Write-Host "$($app.Name) �����" -ForegroundColor $colors.success
}

# 3. Environment Path
Write-Host "`n[3/5] ��������� ���������� �����..." -ForegroundColor $colors.header
$ffmpegPath = "$env:ProgramFiles\FFmpeg\bin"
if ($env:Path -notmatch [regex]::Escape($ffmpegPath)) {
    [Environment]::SetEnvironmentVariable("Path", "$env:Path;$ffmpegPath", "Machine")
    $env:Path += ";$ffmpegPath"
}
Write-Host "PATH ��������" -ForegroundColor $colors.success

# 4. Python Environment
Write-Host "`n[4/5] PYTHON � ����������..." -ForegroundColor $colors.header

# GPU Detection
$gpu = Get-GPUInfo
$cuda = Get-CUDAVersion
Write-Host "GPU: $($gpu.Info)" -ForegroundColor $colors.info
Write-Host "CUDA: $(if ($cuda) { $cuda } else { '�� �������' })" -ForegroundColor $colors.info

$torchArgs = if ($gpu.IsNVIDIA -and $cuda) {
    "--index-url https://download.pytorch.org/whl/cu$($cuda.Replace('.',''))"
} else {
    "--index-url https://download.pytorch.org/whl/cpu"
}

# Python Packages
$packages = @(
    "torch", "torchaudio", "ffmpeg-python", "librosa>=0.10.0",
    "openai-whisper>=20231106", "pyannote.audio>=3.1", "soundfile"
)

foreach ($pkg in $packages) {
    $pkgName = $pkg -replace "[>=].*", ""
    if (-not (Test-PythonPackageInstalled $pkgName)) {
        Write-Host "��������� $pkg..." -ForegroundColor $colors.warning
        $installArgs = if ($pkgName -eq "torch" -or $pkgName -eq "torchaudio") {
            "$pkg $torchArgs"
        } else {
            $pkg
        }
        pip install $installArgs
    }
    Write-Host "$pkgName �����" -ForegroundColor $colors.success
}
#endregion

#region Final Verification
Write-Host "`n[5/5] �������� ���������..." -ForegroundColor $colors.header

$results = @()
$checks = @(
    @{ Name = "FFmpeg"; Test = { Test-CommandExists "ffmpeg" } }
    @{ Name = "CMake"; Test = { Test-CommandExists "cmake" } }
    @{ Name = "Python"; Test = { Test-CommandExists "python" } }
    @{ Name = "PyTorch"; Test = { Test-PythonPackageInstalled "torch" } }
    @{ Name = "Whisper"; Test = { Test-PythonPackageInstalled "whisper" } }
    @{ Name = "Pyannote"; Test = { Test-PythonPackageInstalled "pyannote" } }
)

foreach ($check in $checks) {
    $result = & $check.Test
    $status = if ($result) { "OK" } else { "������" }
    $color = if ($result) { $colors.success } else { $colors.error }
    $results += [PSCustomObject]@{ Component = $check.Name; Status = $status }
    Write-Host "$($check.Name): $status" -ForegroundColor $color
}

# Summary Table
Write-Host "`n=== �������� ����� ===" -ForegroundColor $colors.header
$results | Format-Table -AutoSize

# Additional Info
if ($results.Status -contains "������") {
    Write-Host "`n��������� ���������� �� �����������!" -ForegroundColor $colors.error
    Write-Host "������������:" -ForegroundColor $colors.warning
    Write-Host "1. ������������� �������� � ���������� �����" -ForegroundColor $colors.info
    Write-Host "2. ��� ������� � GPU ���������� CUDA Toolkit" -ForegroundColor $colors.info
    Write-Host "3. ��������� ����������� � ���������" -ForegroundColor $colors.info
} else {
    Write-Host "`n��� ���������� ������� �����������!" -ForegroundColor $colors.success
    Write-Host "������ �� ������ ��������� ���� ������� �������������." -ForegroundColor $colors.info
}

Write-Host "`n�����: ��� ������ ������������������ ����������� GPU � ���������� CUDA" -ForegroundColor $colors.warning
Write-Host "������! ����� ������������� ������������." -ForegroundColor $colors.header
#endregion