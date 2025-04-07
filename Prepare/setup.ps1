<#
.SYNOPSIS
    Ultimate AI Audio Transcription Environment Setup
.DESCRIPTION
    Полная подготовка системы для работы с Whisper и Pyannote:
    - Автоматическая установка всех зависимостей
    - Умная проверка компонентов
    - Поддержка GPU/CUDA
    - Подробный отчет
#>

#region Initial Setup
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Проверка прав администратора
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ОШИБКА] Требуются права администратора!`nЗапустите скрипт от имени администратора." -ForegroundColor Red
    timeout /t 5
    exit 1
}

# Цветовая схема
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
    try { 
        $installed = pip list --format=json | ConvertFrom-Json | Where-Object { $_.name -eq $package }
        return [bool]$installed
    }
    catch { return $false }
}

function Get-GPUInfo {
    try {
        $gpu = (Get-WmiObject Win32_VideoController).Name | Where-Object { $_ -notmatch "Microsoft Basic Display" }
        return @{
            HasGPU = [bool]$gpu
            IsNVIDIA = $gpu -match "NVIDIA"
            Info = if ($gpu) { $gpu -join ", " } else { "Не обнаружен" }
        }
    }
    catch { return @{ HasGPU = $false; IsNVIDIA = $false; Info = "Ошибка проверки" } }
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
Write-Host "`n=== УСТАНОВКА СРЕДЫ АУДИО-ТРАНСКРИБАЦИИ ===`n" -ForegroundColor $colors.header

# 1. Chocolatey Setup
Write-Host "[1/5] ПРОВЕРКА CHOCOLATEY..." -ForegroundColor $colors.header
if (-not (Test-CommandExists "choco")) {
    Write-Host "Установка Chocolatey..." -ForegroundColor $colors.warning
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        refreshenv
        Write-Host "Chocolatey успешно установлен" -ForegroundColor $colors.success
    }
    catch {
        Write-Host "Ошибка установки Chocolatey: $_" -ForegroundColor $colors.error
        timeout /t 10
        exit 1
    }
}
else {
    Write-Host "Chocolatey уже установлен" -ForegroundColor $colors.info
}

# 2. System Dependencies
Write-Host "`n[2/5] СИСТЕМНЫЕ ЗАВИСИМОСТИ..." -ForegroundColor $colors.header

$apps = @(
    @{ Name = "ffmpeg"; Test = { Test-Path "$env:ProgramFiles\FFmpeg\bin\ffmpeg.exe" } }
    @{ Name = "cmake"; Version = "3.31.6"; Test = { Test-CommandExists "cmake" }; Params = 'ADD_CMAKE_TO_PATH=System' }
)

foreach ($app in $apps) {
    if (-not (& $app.Test)) {
        Write-Host "Установка $($app.Name)..." -ForegroundColor $colors.warning
        $args = @("-y")
        if ($app.Version) { $args += "--version=$($app.Version)" }
        if ($app.Params) { $args += "--params=`"$($app.Params)`"" }
        
        try {
            Start-Process -FilePath "choco" -ArgumentList $args -Wait -NoNewWindow
            Write-Host "$($app.Name) успешно установлен" -ForegroundColor $colors.success
        }
        catch {
            Write-Host "Ошибка установки $($app.Name): $_" -ForegroundColor $colors.error
        }
    }
    else {
        Write-Host "$($app.Name) уже установлен" -ForegroundColor $colors.info
    }
}

# 3. Environment Path
Write-Host "`n[3/5] НАСТРОЙКА ПЕРЕМЕННЫХ СРЕДЫ..." -ForegroundColor $colors.header
$ffmpegPath = "$env:ProgramFiles\FFmpeg\bin"
if ($env:Path -notmatch [regex]::Escape($ffmpegPath)) {
    try {
        [Environment]::SetEnvironmentVariable("Path", "$env:Path;$ffmpegPath", "Machine")
        $env:Path += ";$ffmpegPath"
        Write-Host "PATH успешно обновлен" -ForegroundColor $colors.success
    }
    catch {
        Write-Host "Ошибка обновления PATH: $_" -ForegroundColor $colors.error
    }
}
else {
    Write-Host "PATH уже содержит FFmpeg" -ForegroundColor $colors.info
}

# 4. Python Environment
Write-Host "`n[4/5] PYTHON И БИБЛИОТЕКИ..." -ForegroundColor $colors.header

# GPU Detection
$gpu = Get-GPUInfo
$cuda = Get-CUDAVersion
Write-Host "GPU: $($gpu.Info)" -ForegroundColor $colors.info
Write-Host "CUDA: $(if ($cuda) { $cuda } else { 'Не найдена' })" -ForegroundColor $colors.info

$torchIndex = if ($gpu.IsNVIDIA -and $cuda) {
    "https://download.pytorch.org/whl/cu$($cuda.Replace('.',''))"
} else {
    "https://download.pytorch.org/whl/cpu"
}

# Python Packages
$packages = @(
    @{Name = "torch"; ExtraArgs = "--index-url $torchIndex"},
    @{Name = "torchaudio"; ExtraArgs = "--index-url $torchIndex"},
    @{Name = "ffmpeg-python"},
    @{Name = "librosa"; Version = ">=0.10.0"},
    @{Name = "openai-whisper"; Version = ">=20231106"},
    @{Name = "pyannote.audio"; Version = ">=3.1"},
    @{Name = "soundfile"}
)

foreach ($pkg in $packages) {
    $pkgName = $pkg.Name
    $pkgVersion = if ($pkg.Version) { $pkg.Version } else { "" }
    $fullPkgName = "$pkgName$pkgVersion"
    
    if (-not (Test-PythonPackageInstalled $pkgName)) {
        Write-Host "Установка $fullPkgName..." -ForegroundColor $colors.warning
        $installCmd = "pip install $fullPkgName"
        if ($pkg.ExtraArgs) { $installCmd += " $($pkg.ExtraArgs)" }
        
        try {
            Invoke-Expression $installCmd
            Write-Host "$pkgName успешно установлен" -ForegroundColor $colors.success
        }
        catch {
            Write-Host "Ошибка при установке $pkgName : $($_.Exception.Message)" -ForegroundColor $colors.error
        }
    }
    else {
        Write-Host "$pkgName уже установлен" -ForegroundColor $colors.info
    }
}

# 5. Special handling for Whisper if previous installation failed
if (-not (Test-PythonPackageInstalled "whisper")) {
    Write-Host "Попытка альтернативной установки Whisper..." -ForegroundColor $colors.warning
    try {
        pip install git+https://github.com/openai/whisper.git
        Write-Host "Whisper успешно установлен из GitHub" -ForegroundColor $colors.success
    }
    catch {
        Write-Host "Не удалось установить Whisper: $($_.Exception.Message)" -ForegroundColor $colors.error
    }
}
#endregion

#region Final Verification
Write-Host "`n[5/5] ПРОВЕРКА УСТАНОВКИ..." -ForegroundColor $colors.header

$results = @()
$checks = @(
    @{ Name = "FFmpeg"; Test = { Test-CommandExists "ffmpeg" } }
    @{ Name = "CMake"; Test = { Test-CommandExists "cmake" } }
    @{ Name = "Python"; Test = { Test-CommandExists "python" } }
    @{ Name = "PyTorch"; Test = { Test-PythonPackageInstalled "torch" } }
    @{ Name = "Whisper"; Test = { Test-PythonPackageInstalled "whisper" } }
    @{ Name = "Pyannote"; Test = { Test-PythonPackageInstalled "pyannote.audio" } }
)

foreach ($check in $checks) {
    $result = & $check.Test
    $status = if ($result) { "OK" } else { "ОШИБКА" }
    $color = if ($result) { $colors.success } else { $colors.error }
    $results += [PSCustomObject]@{ Component = $check.Name; Status = $status }
    Write-Host "$($check.Name): $status" -ForegroundColor $color
}

# Summary Table
Write-Host "`n=== ИТОГОВЫЙ ОТЧЕТ ===" -ForegroundColor $colors.header
$results | Format-Table -AutoSize

# Additional Info
if ($results.Status -contains "ОШИБКА") {
    Write-Host "`nНекоторые компоненты не установлены!" -ForegroundColor $colors.error
    Write-Host "Рекомендации:" -ForegroundColor $colors.warning
    Write-Host "1. Перезапустите терминал и попробуйте снова" -ForegroundColor $colors.info
    Write-Host "2. Для проблем с GPU установите CUDA Toolkit" -ForegroundColor $colors.info
    Write-Host "3. Проверьте подключение к интернету" -ForegroundColor $colors.info
} else {
    Write-Host "`nВсе компоненты успешно установлены!" -ForegroundColor $colors.success
    Write-Host "Теперь вы можете запускать ваши скрипты транскрибации." -ForegroundColor $colors.info
}

Write-Host "`nСовет: Для лучшей производительности используйте GPU с поддержкой CUDA" -ForegroundColor $colors.warning
Write-Host "Готово! Может потребоваться перезагрузка." -ForegroundColor $colors.header

# Ожидание нажатия клавиши перед закрытием
Write-Host "`nНажмите любую клавишу для выхода..." -ForegroundColor $colors.header
try {
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
catch {
    # Если ReadKey не доступен (например, в ISE)
    Write-Host "Для выхода закройте это окно" -ForegroundColor $colors.warning
    timeout /t 30
}
#endregion
