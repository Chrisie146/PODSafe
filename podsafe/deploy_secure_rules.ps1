# Security Rules Deployment Script
# Created: November 18, 2025
# Purpose: Deploy hardened security rules with rollback capability

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PODSafe Security Rules Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (!(Test-Path "firestore.rules.secure") -or !(Test-Path "storage.rules.secure")) {
    Write-Host "❌ ERROR: Secure rules files not found!" -ForegroundColor Red
    Write-Host "Make sure you're in the podsafe project directory." -ForegroundColor Yellow
    exit 1
}

# Create backup directory
$backupDir = "security_rules_backups"
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

# Backup current rules
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Write-Host "📦 Creating backup of current rules..." -ForegroundColor Yellow

Copy-Item "firestore.rules" "$backupDir/firestore.rules.backup.$timestamp" -Force
Copy-Item "storage.rules" "$backupDir/storage.rules.backup.$timestamp" -Force

Write-Host "✅ Backup created: $backupDir/*backup.$timestamp" -ForegroundColor Green
Write-Host ""

# Show comparison
Write-Host "📊 CHANGES SUMMARY:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔐 Firestore Rules Changes:" -ForegroundColor Yellow
Write-Host "  • Company creation: Anyone → Cloud Functions only (invite-based)" -ForegroundColor White
Write-Host "  • Company access: Any signed-in user → Company members only" -ForegroundColor White
Write-Host "  • Company codes: Public access → Locked down completely" -ForegroundColor White
Write-Host "  • User updates: Can change role/company → Protected critical fields" -ForegroundColor White
Write-Host "  • All collections: Added company isolation and validation" -ForegroundColor White
Write-Host ""
Write-Host "🗄️  Storage Rules Changes:" -ForegroundColor Yellow
Write-Host "  • Added isActive user checks for all operations" -ForegroundColor White
Write-Host "  • Third-party uploads: Open → Token validation required" -ForegroundColor White
Write-Host "  • Company assets: Improved isolation" -ForegroundColor White
Write-Host "  • File validation: Enhanced size and type checks" -ForegroundColor White
Write-Host ""

# Confirmation
Write-Host "⚠️  WARNING: This will replace your current security rules!" -ForegroundColor Yellow
Write-Host "Current rules have been backed up to: $backupDir" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Do you want to proceed with deployment? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "❌ Deployment cancelled." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "🚀 Deploying secure rules..." -ForegroundColor Cyan

# Replace rules files and deploy
try {
    Copy-Item "firestore.rules.secure" "firestore.rules" -Force
    Copy-Item "storage.rules.secure" "storage.rules" -Force
    
    Write-Host "✅ Rules files updated locally" -ForegroundColor Green
    Write-Host ""
    
    # Deploy to Firebase
    Write-Host "📤 Deploying to Firebase..." -ForegroundColor Cyan
    
    $deployOutput = firebase deploy --only firestore:rules,storage 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Rules deployed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 DEPLOYMENT COMPLETE!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Test authentication and access in dev environment" -ForegroundColor White
        Write-Host "  2. Verify company isolation works correctly" -ForegroundColor White
        Write-Host "  3. Test user creation via Cloud Functions" -ForegroundColor White
        Write-Host "  4. Monitor Firebase Console for any rule violations" -ForegroundColor White
        Write-Host ""
        Write-Host "⚠️  IMPORTANT: Users can no longer create companies directly!" -ForegroundColor Yellow
        Write-Host "   You must create users via Cloud Functions or Firebase Admin SDK" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "❌ Deployment failed!" -ForegroundColor Red
        Write-Host $deployOutput
        Write-Host ""
        Write-Host "🔄 Rolling back to previous rules..." -ForegroundColor Yellow
        
        Copy-Item "$backupDir/firestore.rules.backup.$timestamp" "firestore.rules" -Force
        Copy-Item "$backupDir/storage.rules.backup.$timestamp" "storage.rules" -Force
        
        Write-Host "✅ Rollback complete. Previous rules restored." -ForegroundColor Green
        exit 1
    }

Write-Host ""
Write-Host "📁 Backup location: $backupDir" -ForegroundColor Cyan
Write-Host "To rollback manually, run:" -ForegroundColor Cyan
Write-Host "  firebase deploy --only firestore:rules,storage" -ForegroundColor White
Write-Host ""
    
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔄 Rolling back..." -ForegroundColor Yellow
    
    if (Test-Path "$backupDir/firestore.rules.backup.$timestamp") {
        Copy-Item "$backupDir/firestore.rules.backup.$timestamp" "firestore.rules" -Force
        Copy-Item "$backupDir/storage.rules.backup.$timestamp" "storage.rules" -Force
        Write-Host "✅ Rollback complete." -ForegroundColor Green
    }
    
    exit 1
}
