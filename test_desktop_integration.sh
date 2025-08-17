#!/bin/bash

# Test script for desktop integration validation
echo "Testing Ásbrú Connection Manager desktop integration..."

# Test desktop file validation
if command -v desktop-file-validate >/dev/null 2>&1; then
    echo "Validating desktop file..."
    desktop-file-validate res/asbru-cm.desktop
    if [ $? -eq 0 ]; then
        echo "✓ Desktop file is valid"
    else
        echo "✗ Desktop file validation failed"
        exit 1
    fi
else
    echo "⚠ desktop-file-validate not available, skipping validation"
fi

# Test AppData file validation
if command -v appstream-util >/dev/null 2>&1; then
    echo "Validating AppData file..."
    appstream-util validate-relax res/org.asbru.cm.appdata.xml
    if [ $? -eq 0 ]; then
        echo "✓ AppData file is valid"
    else
        echo "✗ AppData file validation failed"
        exit 1
    fi
else
    echo "⚠ appstream-util not available, skipping AppData validation"
fi

# Test icon availability
if [ -f "res/asbru-logo-64.png" ]; then
    echo "✓ Application icon found"
else
    echo "⚠ Application icon not found at expected location"
fi

# Test Wayland compatibility
echo "Checking Wayland compatibility..."
main_exec=$(grep "^Exec=" res/asbru-cm.desktop | head -1)
if echo "$main_exec" | grep -q "GDK_BACKEND=x11"; then
    echo "✗ Main Exec line forces X11 backend"
else
    echo "✓ Main Exec allows automatic display server detection"
fi

# Check for X11 compatibility action
if grep -q "Desktop Action X11Mode" res/asbru-cm.desktop; then
    echo "✓ X11 compatibility mode available as optional action"
else
    echo "⚠ No X11 fallback option available"
fi

# Test for modern desktop categories
if grep -q "Network;" res/asbru-cm.desktop; then
    echo "✓ Modern desktop categories included"
else
    echo "⚠ Consider adding Network category for better categorization"
fi

echo "Desktop integration test completed."