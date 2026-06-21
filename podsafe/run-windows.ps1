# Flutter Windows Build Helper Script
# This script initializes the Visual Studio build environment before running Flutter

Write-Host "Initializing Visual Studio Build Environment..." -ForegroundColor Cyan

# Initialize Visual Studio Build Tools 2022 environment
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

if (Test-Path $vsPath) {
    # Run vcvars64.bat and capture environment variables
    $envVars = cmd /c "`"$vsPath`" x64 >NUL 2>&1 && set"
    
    foreach ($line in $envVars) {
        if ($line -match '^([^=]+)=(.*)$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            Set-Item -Path "env:$varName" -Value $varValue -Force
        }
    }
    Write-Host "Visual Studio environment initialized successfully!" -ForegroundColor Green
} else {
    Write-Host "Visual Studio Build Tools not found at expected location!" -ForegroundColor Red
    exit 1
}

Write-Host "`nRunning Flutter for Windows..." -ForegroundColor Cyan
Write-Host "This may take several minutes on first build...`n" -ForegroundColor Yellow

flutter run -d windows
