# PODSafe Test Data Setup - PowerShell Wrapper
# This script checks for prerequisites and runs the Node.js setup script

Write-Host "`n🧪 PODSafe Test Data Setup`n" -ForegroundColor Cyan

# Check for service account key
if (-not (Test-Path "service-account-key.json")) {
    Write-Host "❌ ERROR: service-account-key.json not found!`n" -ForegroundColor Red
    Write-Host "Please download your Firebase service account key:`n" -ForegroundColor Yellow
    Write-Host "1. Go to: https://console.firebase.google.com/" -ForegroundColor White
    Write-Host "2. Select your PODSafe project" -ForegroundColor White
    Write-Host "3. Click ⚙️ → Project Settings → Service Accounts" -ForegroundColor White
    Write-Host "4. Click 'Generate New Private Key'" -ForegroundColor White
    Write-Host "5. Save as: service-account-key.json in this directory`n" -ForegroundColor White
    exit 1
}

Write-Host "✅ Service account key found" -ForegroundColor Green

# Check for Node.js
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Check for dependencies
if (-not (Test-Path "node_modules/firebase-admin")) {
    Write-Host "⚠️  Installing dependencies..." -ForegroundColor Yellow
    npm install
}

Write-Host "`n🚀 Running test data setup...`n" -ForegroundColor Cyan
Write-Host "=" * 60

# Run the setup script
node setup_test_data.js

$exitCode = $LASTEXITCODE

Write-Host "`n" ("=" * 60)

if ($exitCode -eq 0) {
    Write-Host "`n✅ Test data setup complete!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Run: node test_security_rules.js" -ForegroundColor White
    Write-Host "  2. Open: security_test.html in browser for visual testing" -ForegroundColor White
    Write-Host "  3. Read: SECURITY_MANUAL_TEST_GUIDE.md for comprehensive tests`n" -ForegroundColor White
} else {
    Write-Host "`n❌ Test data setup failed. Check errors above.`n" -ForegroundColor Red
    exit 1
}
