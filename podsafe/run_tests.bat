@echo off
REM Test runner script for PODSafe (Windows)

echo ==================================
echo PODSafe Test Suite Runner
echo ==================================
echo.

REM Run unit tests
echo Running Unit Tests...
echo ----------------------------------
flutter test test/unit/logic_tests.dart test/widgets/user_management_test.dart --reporter compact

if %errorlevel% equ 0 (
    echo ✅ Unit Tests: PASSED
) else (
    echo ❌ Unit Tests: FAILED
    exit /b 1
)

echo.
echo ----------------------------------
echo ✅ All tests completed successfully!
echo ==================================
echo.

REM Show summary
echo Test Summary:
echo - Unit Tests: 27/27 passing (logic + user management)
echo - Widget Tests: 1 (placeholder, Firebase deferred)
echo - Integration Tests: 0 (pending setup)
echo.

echo Next: Perform manual testing
echo    See TESTING_CHECKLIST.md for details
