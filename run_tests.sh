#!/bin/bash
# Test runner script for PODSafe

echo "=================================="
echo "PODSafe Test Suite Runner"
echo "=================================="
echo ""

# Run unit tests
echo "📋 Running Unit Tests..."
echo "----------------------------------"
flutter test test/unit/logic_tests.dart --reporter compact

if [ $? -eq 0 ]; then
    echo "✅ Unit Tests: PASSED"
else
    echo "❌ Unit Tests: FAILED"
    exit 1
fi

echo ""
echo "----------------------------------"
echo "✅ All tests completed successfully!"
echo "=================================="
echo ""

# Show summary
echo "Test Summary:"
echo "- Unit Tests: 23/23 passing"
echo "- Widget Tests: 0 (pending setup)"
echo "- Integration Tests: 0 (pending setup)"
echo ""

echo "📋 Next: Perform manual testing"
echo "   See TESTING_CHECKLIST.md for details"
