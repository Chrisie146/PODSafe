#!/usr/bin/env bash
# Production Firebase Setup Script
# Usage: bash scripts/setup_production.sh
# This automates the Firebase production project setup

set -e  # Exit on any error

echo "🚀 PODSafe Production Firebase Setup Script"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found. Install it first:${NC}"
    echo "   npm install -g firebase-tools"
    exit 1
fi

echo -e "${YELLOW}Step 1: Create Production Firebase Project${NC}"
echo "This will create a new Firebase project called 'podsafe-production'"
echo "You'll need to:"
echo "  1. Have a Google Cloud account"
echo "  2. Have billing enabled"
echo "  3. Have Project Editor permissions"
echo ""

read -p "Press Enter to continue or Ctrl+C to cancel..."

# Step 1: Create project
echo -e "${YELLOW}Creating Firebase project 'podsafe-production'...${NC}"
firebase projects:create podsafe-production --display-name "PODSafe Production" || {
    echo -e "${RED}⚠️ Project may already exist. Continuing...${NC}"
}

# Step 2: Set as active
echo -e "${YELLOW}Setting as active Firebase project...${NC}"
firebase use podsafe-production

# Step 3: Get project ID
PROJECT_ID=$(firebase use | grep -oP 'Currently using alias default \(\K[^)]+' || echo "podsafe-production")
echo -e "${GREEN}✅ Project ID: $PROJECT_ID${NC}"

# Step 4: Enable required APIs
echo -e "${YELLOW}Enabling required Google Cloud APIs...${NC}"
gcloud services enable \
    firestore.googleapis.com \
    storage-component.googleapis.com \
    cloudfunctions.googleapis.com \
    cloudkms.googleapis.com \
    firebase.googleapis.com \
    --project="$PROJECT_ID" || echo "Some APIs may already be enabled"

# Step 5: Deploy Firebase rules
echo -e "${YELLOW}Step 2: Deploy Firebase Security Rules${NC}"
read -p "Deploy Firestore and Storage rules? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deploying Firestore rules...${NC}"
    firebase deploy --only firestore:rules --project "$PROJECT_ID"
    
    echo -e "${YELLOW}Deploying Storage rules...${NC}"
    firebase deploy --only storage --project "$PROJECT_ID"
    
    echo -e "${GREEN}✅ Security rules deployed${NC}"
fi

# Step 6: Deploy Cloud Functions
echo -e "${YELLOW}Step 3: Deploy Cloud Functions${NC}"
read -p "Deploy Cloud Functions? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deploying createUser Cloud Function...${NC}"
    firebase deploy --only functions --project "$PROJECT_ID"
    
    echo -e "${GREEN}✅ Cloud Functions deployed${NC}"
fi

# Step 7: Get Firebase config
echo -e "${YELLOW}Step 4: Get Firebase Web Config${NC}"
echo "Retrieving Firebase config..."

FIREBASE_CONFIG=$(firebase use | grep -A 20 "podsafe-production")

echo -e "${YELLOW}Firebase Configuration:${NC}"
echo "$FIREBASE_CONFIG"

# Step 8: Create test accounts
echo -e "${YELLOW}Step 5: Create Test Accounts (Optional)${NC}"
read -p "Would you like to create test user accounts? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Note: Use Firebase Console to create test accounts:${NC}"
    echo "  1. Go to Firebase Console"
    echo "  2. Navigate to Authentication"
    echo "  3. Click 'Add User'"
    echo "  4. Create:"
    echo "     - admin@test.com / TestPass123 (role: admin)"
    echo "     - driver@test.com / TestPass123 (role: driver)"
    echo "     - manager@test.com / TestPass123 (role: manager)"
fi

# Step 9: Summary
echo ""
echo -e "${GREEN}✅ Production Firebase Setup Complete!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Update environment configuration:"
echo "   - Edit lib/config/environment.dart with Firebase web config"
echo "   - Update your app IDs in Firebase console"
echo ""
echo "2. Test login with test accounts"
echo ""
echo "3. Set up monitoring:"
echo "   - Firestore > Rules tab"
echo "   - Cloud Functions > Monitor tab"
echo "   - Cloud Storage > Rules tab"
echo ""
echo "4. Create backup strategy"
echo ""
echo -e "${YELLOW}Emergency Contact:${NC}"
echo "If something goes wrong, you can always switch back to development:"
echo "  firebase use default"
echo ""
echo "🎉 You're ready to launch the beta!"
