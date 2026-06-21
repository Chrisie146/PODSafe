# Deploy Firestore Indexes
# This script deploys the optimized composite indexes to Firebase

Write-Host "🚀 Deploying Firestore Indexes..." -ForegroundColor Cyan
Write-Host ""

# Check if firebase CLI is installed
try {
    $firebaseVersion = firebase --version
    Write-Host "✅ Firebase CLI found: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not found!" -ForegroundColor Red
    Write-Host "   Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Validate JSON file exists
if (-not (Test-Path "firestore.indexes.json")) {
    Write-Host "❌ firestore.indexes.json not found!" -ForegroundColor Red
    exit 1
}

# Count indexes
$content = Get-Content "firestore.indexes.json" -Raw | ConvertFrom-Json
$totalIndexes = $content.indexes.Count

Write-Host "📊 Index Summary:" -ForegroundColor Cyan
Write-Host "   Total Indexes: $totalIndexes" -ForegroundColor White
$content.indexes | Group-Object collectionGroup | ForEach-Object {
    Write-Host "   - $($_.Name): $($_.Count) indexes" -ForegroundColor White
}
Write-Host ""

# Confirm deployment
$confirmation = Read-Host "Deploy these indexes to Firebase? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "❌ Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "🔄 Deploying to Firebase..." -ForegroundColor Cyan

# Deploy indexes
firebase deploy --only firestore:indexes

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Indexes deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Check Firebase Console → Firestore → Indexes" -ForegroundColor White
    Write-Host "   2. Wait 2-5 minutes for indexes to build" -ForegroundColor White
    Write-Host "   3. Look for 'Enabled' status on all indexes" -ForegroundColor White
    Write-Host "   4. Test your queries in the app" -ForegroundColor White
    Write-Host ""
    Write-Host "🔗 Firebase Console:" -ForegroundColor Cyan
    Write-Host "   https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes" -ForegroundColor Blue
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "   Check the error messages above" -ForegroundColor Yellow
    exit 1
}
