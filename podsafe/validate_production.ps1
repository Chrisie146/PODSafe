#!/usr/bin/env pwsh

# Production Pre-Launch Validation Script
# 
# This script performs comprehensive checks before launching to production.
# Run this to verify everything is ready.
# 
# Usage: powershell -ExecutionPolicy Bypass -File validate_production.ps1

Write-Host "🚀 PODSafe Production Pre-Launch Validation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()
$passes = @()

# ============================================================================
# Check 1: Flutter Environment
# ============================================================================
Write-Host "1. Checking Flutter Environment..." -ForegroundColor Yellow

try {
    $flutterVersion = flutter --version
    if ($flutterVersion -match "3\.[8-9]|[4-9]\.") {
        $passes += "✅ Flutter version is 3.8+"
    } else {
        $errors += "❌ Flutter version is too old, need 3.8+"
    }
} catch {
    $errors += "❌ Flutter not found in PATH"
}

try {
    dart --version | Out-Null
    $passes += "✅ Dart is installed"
} catch {
    $errors += "❌ Dart not found in PATH"
}

# ============================================================================
# Check 2: Code Quality
# ============================================================================
Write-Host "2. Checking Code Quality..." -ForegroundColor Yellow

Write-Host "   Running flutter analyze..." -ForegroundColor Gray
$analyzeOutput = flutter analyze 2>&1 | Out-String
if ($analyzeOutput -match "No issues found") {
    $passes += "✅ No analyzer issues found"
} else {
    $warnings += "⚠️  Analyzer issues found - review before launch"
}

# ============================================================================
# Check 3: Test Suite
# ============================================================================
Write-Host "3. Running Tests..." -ForegroundColor Yellow

Write-Host "   Running flutter test..." -ForegroundColor Gray
$testOutput = flutter test 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    $passes += "✅ All tests passing"
} else {
    $errors += "❌ Some tests are failing"
}

# ============================================================================
# Check 4: Build Verification
# ============================================================================
Write-Host "4. Checking Build Configuration..." -ForegroundColor Yellow

# Check pubspec.yaml
if (Test-Path "pubspec.yaml") {
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    
    if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)") {
        $version = $matches[1]
        $passes += "✅ Version set to $version"
    }
    
    if ($pubspecContent -match "publish_to:\s*'none'") {
        $passes += "✅ Publish disabled (private package)"
    }
} else {
    $errors += "❌ pubspec.yaml not found"
}

# ============================================================================
# Check 5: Environment Configuration
# ============================================================================
Write-Host "5. Checking Environment Configuration..." -ForegroundColor Yellow

if (Test-Path "lib/config/environment.dart") {
    $envContent = Get-Content "lib/config/environment.dart" -Raw
    
    if ($envContent -match "enableDebugLogging.*isProduction\s*?false") {
        $passes += "✅ Debug logging disabled in production"
    } else {
        $warnings += "⚠️  Verify debug logging is disabled in production"
    }
    
    if ($envContent -match "enableCrashlytics.*isProduction\s*?true") {
        $passes += "✅ Crashlytics enabled for production"
    } else {
        $warnings += "⚠️  Verify Crashlytics is enabled in production"
    }
} else {
    $warnings += "⚠️  lib/config/environment.dart not found"
}

# ============================================================================
# Check 6: Firebase Configuration
# ============================================================================
Write-Host "6. Checking Firebase Configuration..." -ForegroundColor Yellow

if (Test-Path ".firebaserc") {
    $firebaserc = Get-Content ".firebaserc" -Raw | ConvertFrom-Json
    if ($firebaserc.projects.default) {
        $passes += "✅ Firebase project configured: $($firebaserc.projects.default)"
    } else {
        $warnings += "⚠️  Firebase project not set as default"
    }
} else {
    $errors += "❌ .firebaserc not found"
}

if (Test-Path "firestore.rules") {
    $rulesContent = Get-Content "firestore.rules" -Raw
    if ($rulesContent -match "isAuthenticated\(\)|isSignedIn\(\)|request\.auth\s*!=\s*null") {
        $passes += "✅ Firestore rules have authentication checks"
    } else {
        $errors += "❌ Firestore rules missing proper auth checks"
    }
} else {
    $errors += "❌ firestore.rules not found"
}

if (Test-Path "storage.rules") {
    $passes += "✅ Storage rules file exists"
} else {
    $errors += "❌ storage.rules not found"
}

# ============================================================================
# Check 7: Critical Files Presence
# ============================================================================
Write-Host "7. Checking Critical Files..." -ForegroundColor Yellow

$criticalFiles = @(
    "lib/main.dart",
    "lib/firebase_options.dart",
    "lib/config/environment.dart",
    "android/app/build.gradle.kts",
    "ios/Runner.xcodeproj/project.pbxproj",
    "web/index.html"
)

foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        $passes += "✅ $file exists"
    } else {
        $errors += "❌ $file missing"
    }
}

# ============================================================================
# Check 8: Documentation
# ============================================================================
Write-Host "8. Checking Documentation..." -ForegroundColor Yellow

$docs = @(
    "PRODUCTION_READINESS_CHECKLIST.md",
    "PRODUCTION_DEPLOYMENT_GUIDE.md",
    "PRODUCTION_MONITORING_INCIDENT_RESPONSE.md",
    "PRODUCTION_FIREBASE_SETUP.md"
)

foreach ($doc in $docs) {
    if (Test-Path $doc) {
        $passes += "✅ $doc exists"
    } else {
        $warnings += "⚠️  $doc not found"
    }
}

# ============================================================================
# Check 9: Git Status
# ============================================================================
Write-Host "9. Checking Git Status..." -ForegroundColor Yellow

try {
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        $uncommittedCount = ($gitStatus | Measure-Object).Count
        $warnings += "⚠️  $uncommittedCount uncommitted changes"
    } else {
        $passes += "✅ All changes committed"
    }
    
    $branch = git rev-parse --abbrev-ref HEAD
    $passes += "✅ On branch: $branch"
} catch {
    $warnings += "⚠️  Could not check git status"
}

# ============================================================================
# Check 10: Output Summary
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "VALIDATION RESULTS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($passes.Count -gt 0) {
    Write-Host "✅ PASSED CHECKS ($($passes.Count)):" -ForegroundColor Green
    foreach ($pass in $passes) {
        Write-Host "   $pass"
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠️  WARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "   $warning"
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

# ============================================================================
# Final Decision
# ============================================================================
Write-Host "============================================" -ForegroundColor Cyan

if ($errors.Count -eq 0 -and $warnings.Count -le 2) {
    Write-Host "🚀 READY FOR PRODUCTION" -ForegroundColor Green
    Write-Host "   All critical checks passed!"
    Write-Host "   Address any warnings before launch"
    exit 0
} elseif ($errors.Count -eq 0) {
    Write-Host "🟡 READY WITH CAUTIONS" -ForegroundColor Yellow
    Write-Host "   Critical checks passed but review warnings"
    exit 0
} else {
    Write-Host "❌ NOT READY FOR PRODUCTION" -ForegroundColor Red
    Write-Host "   Must fix $($errors.Count) critical error(s) first"
    exit 1
}
