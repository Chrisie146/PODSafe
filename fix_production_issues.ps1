#!/usr/bin/env pwsh

# PODSafe Production Fixes Script
# Automates common production readiness fixes

Write-Host "🔧 PODSafe Production Fixes" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$fixes = @()

# ============================================================================
# Backup current state
# ============================================================================
Write-Host "📦 Creating backup..." -ForegroundColor Yellow

$backupDir = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

try {
    # Copy lib directory
    Copy-Item -Path "lib" -Destination "$backupDir\lib" -Recurse
    $fixes += "✅ Created backup in $backupDir"
} catch {
    $errors += "❌ Failed to create backup: $_"
    exit 1
}

# ============================================================================
# Fix 1: Update print statements (conditional on environment)
# ============================================================================
Write-Host "`n1. Analyzing print statements..." -ForegroundColor Yellow

$dartFiles = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" -Exclude "*_test.dart"
$printCount = 0
$filesWithPrint = @()

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match "print\(") {
        $matches = [regex]::Matches($content, "print\(")
        $printCount += $matches.Count
        $filesWithPrint += $file.FullName
    }
}

Write-Host "   Found $printCount print statements in $($filesWithPrint.Count) files" -ForegroundColor Gray

# Create a report file instead of modifying (safer approach)
$reportPath = "production_print_statements_report.txt"
"PODSafe Print Statements Report" | Out-File $reportPath
"Generated: $(Get-Date)" | Out-File $reportPath -Append
"" | Out-File $reportPath -Append
"Files with print() statements:" | Out-File $reportPath -Append
"================================" | Out-File $reportPath -Append
"" | Out-File $reportPath -Append

foreach ($file in $filesWithPrint) {
    $relativePath = $file.Replace((Get-Location).Path + "\", "")
    $content = Get-Content $file -Raw
    $matches = [regex]::Matches($content, "print\([^)]+\)")
    
    $relativePath | Out-File $reportPath -Append
    foreach ($match in $matches) {
        "  - $($match.Value)" | Out-File $reportPath -Append
    }
    "" | Out-File $reportPath -Append
}

$fixes += "✅ Created print statements report: $reportPath"

# ============================================================================
# Fix 2: Check for TODO and FIXME comments
# ============================================================================
Write-Host "`n2. Checking for TODO/FIXME comments..." -ForegroundColor Yellow

$todoCount = 0
$fixmeCount = 0

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $todoMatches = [regex]::Matches($content, "//\s*TODO")
    $fixmeMatches = [regex]::Matches($content, "//\s*FIXME")
    
    $todoCount += $todoMatches.Count
    $fixmeCount += $fixmeMatches.Count
}

if ($todoCount -gt 0) {
    Write-Host "   ⚠️  Found $todoCount TODO comments" -ForegroundColor Yellow
}
if ($fixmeCount -gt 0) {
    Write-Host "   ⚠️  Found $fixmeCount FIXME comments" -ForegroundColor Yellow
}

$fixes += "✅ Checked for TODO ($todoCount) and FIXME ($fixmeCount) comments"

# ============================================================================
# Fix 3: Verify environment configuration
# ============================================================================
Write-Host "`n3. Verifying environment configuration..." -ForegroundColor Yellow

if (Test-Path "lib/config/environment.dart") {
    $envContent = Get-Content "lib/config/environment.dart" -Raw
    
    if ($envContent -match "current\s*=\s*Environment\.development") {
        $fixes += "✅ Environment set to development (correct for local builds)"
    } elseif ($envContent -match "current\s*=\s*Environment\.production") {
        Write-Host "   ⚠️  WARNING: Environment set to production!" -ForegroundColor Red
        Write-Host "   Make sure this is intentional" -ForegroundColor Red
        $fixes += "⚠️  Environment set to production - verify this is correct"
    }
} else {
    $errors += "❌ lib/config/environment.dart not found"
}

# ============================================================================
# Fix 4: Check for hardcoded credentials
# ============================================================================
Write-Host "`n4. Checking for hardcoded credentials..." -ForegroundColor Yellow

$credentialPatterns = @(
    "password\s*[:=]\s*['\`"][^'\`"]+['\`"]",
    "api[_-]?key\s*[:=]\s*['\`"][^'\`"]+['\`"]",
    "secret\s*[:=]\s*['\`"][^'\`"]+['\`"]",
    "token\s*[:=]\s*['\`"][^'\`"]+['\`"]"
)

$foundCredentials = @()

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    
    foreach ($pattern in $credentialPatterns) {
        if ($content -match $pattern) {
            $relativePath = $file.FullName.Replace((Get-Location).Path + "\", "")
            $foundCredentials += $relativePath
            break
        }
    }
}

if ($foundCredentials.Count -gt 0) {
    Write-Host "   ⚠️  Potential hardcoded credentials found in $($foundCredentials.Count) files" -ForegroundColor Red
    $fixes += "⚠️  Review potential hardcoded credentials in: $($foundCredentials -join ', ')"
} else {
    $fixes += "✅ No obvious hardcoded credentials found"
}

# ============================================================================
# Fix 5: Check .gitignore
# ============================================================================
Write-Host "`n5. Verifying .gitignore..." -ForegroundColor Yellow

if (Test-Path ".gitignore") {
    $gitignoreContent = Get-Content ".gitignore" -Raw
    
    $requiredPatterns = @(
        "\.env",
        "google-services\.json",
        "GoogleService-Info\.plist",
        "firebase-debug\.log"
    )
    
    $missing = @()
    foreach ($pattern in $requiredPatterns) {
        if ($gitignoreContent -notmatch $pattern) {
            $missing += $pattern
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "   ⚠️  .gitignore missing patterns: $($missing -join ', ')" -ForegroundColor Yellow
        
        # Add missing patterns
        foreach ($pattern in $missing) {
            Add-Content ".gitignore" "`n# Production security"
            Add-Content ".gitignore" $pattern
        }
        $fixes += "✅ Updated .gitignore with security patterns"
    } else {
        $fixes += "✅ .gitignore has all required patterns"
    }
} else {
    $errors += "❌ .gitignore not found"
}

# ============================================================================
# Fix 6: Create production environment template
# ============================================================================
Write-Host "`n6. Creating production environment template..." -ForegroundColor Yellow

if (-not (Test-Path ".env.example")) {
    $envExample = @"
# PODSafe Environment Configuration Template
# Copy this to .env.development or .env.production

# Environment
ENVIRONMENT=development

# Firebase
FIREBASE_PROJECT_ID=podsafe-staging
FIREBASE_API_KEY=YOUR_API_KEY_HERE
FIREBASE_APP_ID=YOUR_APP_ID_HERE

# Features
ENABLE_DEBUG_LOGGING=true
ENABLE_CRASHLYTICS=false
ENABLE_ANALYTICS=true

# Optional Services
GOOGLE_MAPS_API_KEY=YOUR_MAPS_KEY_HERE
SENTRY_DSN=YOUR_SENTRY_DSN_HERE
"@
    
    $envExample | Out-File ".env.example"
    $fixes += "✅ Created .env.example template"
} else {
    $fixes += "✅ .env.example already exists"
}

# ============================================================================
# Fix 7: Generate production checklist
# ============================================================================
Write-Host "`n7. Generating production deployment checklist..." -ForegroundColor Yellow

$checklistPath = "PRODUCTION_DEPLOYMENT_CHECKLIST_$(Get-Date -Format 'yyyyMMdd').md"
$checklist = @"
# Production Deployment Checklist
**Date:** $(Get-Date -Format 'yyyy-MM-dd')
**Version:** 1.0.0

## Pre-Deployment

### Code Quality
- [ ] All tests passing: ``flutter test``
- [ ] No analyzer errors: ``flutter analyze``
- [ ] Print statements removed or conditioned
- [ ] TODO/FIXME comments addressed
- [ ] Code reviewed and approved

### Environment
- [ ] Environment set to production in ``lib/config/environment.dart``
- [ ] Production Firebase project created
- [ ] Production Firebase credentials configured
- [ ] Environment variables secured
- [ ] No hardcoded credentials in code

### Build Configuration
- [ ] Android: Version code/name updated
- [ ] iOS: Version updated in Info.plist
- [ ] Signing certificates configured
- [ ] ProGuard/R8 enabled for Android
- [ ] Code obfuscation enabled

### Security
- [ ] Firestore security rules tested
- [ ] Storage security rules tested
- [ ] API keys in environment variables
- [ ] .gitignore updated for sensitive files
- [ ] SSL/TLS enabled for all endpoints

### Testing
- [ ] Tested on real Android devices
- [ ] Tested on real iOS devices
- [ ] Tested offline functionality
- [ ] Load tested with realistic data
- [ ] Security tested (penetration testing)

## Deployment

### Firebase
- [ ] Switch to production project: ``firebase use podsafe-production``
- [ ] Deploy Firestore rules: ``firebase deploy --only firestore:rules``
- [ ] Deploy Storage rules: ``firebase deploy --only storage``
- [ ] Deploy Cloud Functions: ``firebase deploy --only functions``

### Android
- [ ] Build release APK: ``flutter build apk --release``
- [ ] Test APK on multiple devices
- [ ] Upload to Google Play Console
- [ ] Create internal testing release
- [ ] Promote to production (gradual rollout)

### iOS
- [ ] Build release IPA: ``flutter build ios --release``
- [ ] Archive and validate in Xcode
- [ ] Upload to App Store Connect
- [ ] Create TestFlight build
- [ ] Submit for App Store review

### Web
- [ ] Build release: ``flutter build web --release``
- [ ] Test build locally
- [ ] Deploy to Firebase Hosting: ``firebase deploy --only hosting``
- [ ] Verify custom domain (if applicable)

## Post-Deployment

### Monitoring (First 24 Hours)
- [ ] Monitor Crashlytics for crashes
- [ ] Monitor Firebase Analytics for usage
- [ ] Check error rates in console
- [ ] Monitor performance metrics
- [ ] Review user feedback

### Week 1
- [ ] Daily monitoring checks
- [ ] Review crash reports
- [ ] Address critical issues
- [ ] Monitor user retention
- [ ] Collect user feedback

### Rollback Plan
- [ ] Document rollback procedure
- [ ] Keep previous version available
- [ ] Have team ready for hotfixes
- [ ] Communication plan for issues

## Sign-off

- [ ] **Developer:** ___________________________ Date: __________
- [ ] **QA Lead:** ____________________________ Date: __________
- [ ] **DevOps:** _____________________________ Date: __________
- [ ] **Product Owner:** _______________________ Date: __________

---
**Notes:**
"@

$checklist | Out-File $checklistPath
$fixes += "✅ Created deployment checklist: $checklistPath"

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "PRODUCTION FIXES SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($fixes.Count -gt 0) {
    Write-Host "✅ FIXES APPLIED ($($fixes.Count)):" -ForegroundColor Green
    foreach ($fix in $fixes) {
        Write-Host "   $fix"
    }
    Write-Host ""
}

if ($errors.Count -gt 0) {
    Write-Host "❌ ERRORS ($($errors.Count)):" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "   $err"
    }
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Review: $reportPath" -ForegroundColor White
Write-Host "2. Complete: $checklistPath" -ForegroundColor White
Write-Host "3. Fix: Address print statements manually or with IDE" -ForegroundColor White
Write-Host "4. Test: Run validate_production.ps1 again" -ForegroundColor White
Write-Host "5. Deploy: Follow PRODUCTION_DEPLOYMENT_GUIDE.md" -ForegroundColor White
Write-Host ""
Write-Host "✨ Production fixes completed!" -ForegroundColor Green
Write-Host "⚠️  Backup saved in: $backupDir" -ForegroundColor Yellow
