# PODSafe Play Store Upload Setup Script
# This script automates the preparation steps for Play Store upload

param(
    [string]$CompanyDomain = "",
    [string]$KeystorePassword = "",
    [switch]$CreateKeystore = $false,
    [switch]$UpdateConfigs = $false,
    [switch]$BuildAAB = $false,
    [switch]$FullSetup = $false
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Yellow
}

# Validate current directory
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error "Not in Flutter project root. Please run from project directory."
    exit 1
}

Write-Header "PODSafe Play Store Setup"

# Step 1: Create Keystore if requested
if ($CreateKeystore -or $FullSetup) {
    Write-Header "Step 1: Creating Release Signing Key"
    
    if (-not $KeystorePassword) {
        $KeystorePassword = Read-Host "Enter a strong keystore password"
    }
    
    $keystorePath = "android\app\release.keystore"
    
    if (Test-Path $keystorePath) {
        Write-Info "Keystore already exists at $keystorePath"
    } else {
        Write-Info "Generating keystore (this creates a 10-year valid key)..."
        
        $fullName = Read-Host "Enter your full name"
        $organization = Read-Host "Enter organization name"
        $city = Read-Host "Enter city"
        $state = Read-Host "Enter state/province"
        $country = Read-Host "Enter country code (e.g., US)"
        
        $keystoreCmd = @(
            "keytool",
            "-genkey",
            "-v",
            "-keystore", $keystorePath,
            "-keyalg", "RSA",
            "-keysize", "2048",
            "-validity", "10000",
            "-alias", "podsafe-release",
            "-dname", "CN=$fullName, OU=$organization, L=$city, ST=$state, C=$country",
            "-storepass", $KeystorePassword,
            "-keypass", $KeystorePassword
        )
        
        & $keystoreCmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Keystore created successfully"
        } else {
            Write-Error "Failed to create keystore"
            exit 1
        }
    }
    
    # Create key.properties file
    Write-Info "Creating key.properties file..."
    $keyPropsContent = @"
storePassword=$KeystorePassword
keyPassword=$KeystorePassword
keyAlias=podsafe-release
storeFile=./app/release.keystore
"@
    
    Set-Content -Path "android\key.properties" -Value $keyPropsContent -Force
    Write-Success "key.properties created"
}

# Step 2: Update Application ID if provided
if ($CompanyDomain -or $FullSetup) {
    Write-Header "Step 2: Updating Application ID"
    
    if (-not $CompanyDomain) {
        $CompanyDomain = Read-Host "Enter company domain (e.g., com.mycompany.podsafe)"
    }
    
    # Validate domain format
    if ($CompanyDomain -match "^com\.[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*$") {
        Write-Info "Updating android/app/build.gradle.kts..."
        
        $buildGradleFile = "android\app\build.gradle.kts"
        $content = Get-Content $buildGradleFile -Raw
        $content = $content -replace 'applicationId = "com\.example\.podsafe"', "applicationId = `"$CompanyDomain`""
        Set-Content -Path $buildGradleFile -Value $content -Force
        
        Write-Success "Application ID updated to $CompanyDomain"
    } else {
        Write-Error "Invalid domain format. Must be like: com.company.appname"
        exit 1
    }
}

# Step 3: Update Version to Production
if ($UpdateConfigs -or $FullSetup) {
    Write-Header "Step 3: Updating Version to Production"
    
    Write-Info "Updating pubspec.yaml..."
    $pubspecFile = "pubspec.yaml"
    $content = Get-Content $pubspecFile -Raw
    $content = $content -replace 'version: 1\.0\.0-beta\.1\+1', "version: 1.0.0+1"
    Set-Content -Path $pubspecFile -Value $content -Force
    
    Write-Success "Version updated to 1.0.0+1"
}

# Step 4: Build AAB if requested
if ($BuildAAB -or $FullSetup) {
    Write-Header "Step 4: Building Release App Bundle"
    
    Write-Info "Cleaning and getting dependencies..."
    & flutter clean
    & flutter pub get
    
    Write-Info "Building app bundle for Play Store..."
    & flutter build appbundle --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "App bundle built successfully!"
        Write-Info "Location: build\app\outputs\bundle\release\app-release.aab"
    } else {
        Write-Error "Failed to build app bundle"
        exit 1
    }
}

# Show summary
Write-Header "Setup Summary"

$steps = @(
    "✓ Keystore created (if requested)"
    "✓ Application ID updated (if provided)"
    "✓ Version set to production (if requested)"
    "✓ App bundle built (if requested)"
)

foreach ($step in $steps) {
    Write-Host $step -ForegroundColor Green
}

Write-Info "Next steps:"
Write-Info "1. Review PLAYSTORE_UPLOAD_GUIDE.md for full instructions"
Write-Info "2. Create app listing in Google Play Console"
Write-Info "3. Upload app bundle: build\app\outputs\bundle\release\app-release.aab"
Write-Info "4. Complete store listing with screenshots and details"
Write-Info "5. Submit for review"

Write-Host ""
