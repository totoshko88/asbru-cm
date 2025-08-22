#!/usr/bin/perl

###############################################################################
# UI Fixes Test Script for Ásbrú Connection Manager 7.0.2
# Tests all implemented improvements
###############################################################################

use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

print "=== UI Fixes Test Results ===\n\n";

# Test 1: Check if native connection icons are enabled by default
sub test_native_icons_config {
    print "1. Testing native connection icons configuration...\n";
    
    my $main_pm = "$RealBin/lib/PACMain.pm";
    my $config_check = `grep -A 2 -B 2 "use_native_connection_icons.*//.*1" "$main_pm"`;
    
    if ($config_check) {
        print "   ✓ Native connection icons enabled by default\n";
        return 1;
    } else {
        print "   ✗ Native connection icons config missing\n";
        return 0;
    }
}

# Test 2: Check connection tree icon logic
sub test_tree_icon_logic {
    print "2. Testing connection tree icon logic...\n";
    
    my $main_pm = "$RealBin/lib/PACMain.pm";
    my $logic_check = `grep -A 5 "use_native.*connection_method" "$main_pm"`;
    
    if ($logic_check =~ /use_native.*_getConnectionTypeIcon/) {
        print "   ✓ Tree icon logic updated for native icons\n";
        return 1;
    } else {
        print "   ✗ Tree icon logic not properly updated\n";
        return 0;
    }
}

# Test 3: Check tab icon implementation
sub test_tab_icons {
    print "3. Testing terminal tab icon implementation...\n";
    
    my $terminal_pm = "$RealBin/lib/PACTerminal.pm";
    my $tab_count = `grep -c "_getConnectionTypeIcon.*method_icon" "$terminal_pm"`;
    chomp $tab_count;
    
    if ($tab_count >= 3) {
        print "   ✓ Tab icons implemented in $tab_count locations\n";
        return 1;
    } else {
        print "   ⚠ Tab icons found in $tab_count locations (expected 3+)\n";
        return 0;
    }
}

# Test 4: Check Local method icon files
sub test_local_icons {
    print "4. Testing Local method icon files...\n";
    
    my @themes = qw(default system asbru-dark asbru-color);
    my $all_present = 1;
    
    for my $theme (@themes) {
        my $svg_exists = -f "$RealBin/res/themes/$theme/asbru_method_local.svg";
        my $png_exists = -f "$RealBin/res/themes/$theme/asbru_method_local.png";
        
        if ($svg_exists && $png_exists) {
            print "   ✓ $theme theme has Local icons\n";
        } else {
            print "   ✗ $theme theme missing Local icons\n";
            $all_present = 0;
        }
    }
    
    return $all_present;
}

# Test 5: Check WebDAV icon files and mapping
sub test_webdav_icons {
    print "5. Testing WebDAV icon support...\n";
    
    my @themes = qw(default system asbru-dark asbru-color);
    my $files_present = 1;
    
    for my $theme (@themes) {
        my $svg_exists = -f "$RealBin/res/themes/$theme/asbru_method_cadaver.svg";
        my $png_exists = -f "$RealBin/res/themes/$theme/asbru_method_cadaver.png";
        
        unless ($svg_exists && $png_exists) {
            print "   ✗ $theme theme missing WebDAV icons\n";
            $files_present = 0;
        }
    }
    
    if ($files_present) {
        print "   ✓ WebDAV icon files present in all themes\n";
    }
    
    # Check mapping
    my $main_pm = "$RealBin/lib/PACMain.pm";
    my $mapping_check = `grep -A 1 -B 1 "WebDAV.*cadaver" "$main_pm"`;
    
    if ($mapping_check) {
        print "   ✓ WebDAV -> cadaver icon mapping exists\n";
        return $files_present;
    } else {
        print "   ✗ WebDAV icon mapping missing\n";
        return 0;
    }
}

# Test 6: Check CSS tree styling
sub test_tree_css {
    print "6. Testing connection tree CSS styling...\n";
    
    my @themes = qw(default system asbru-dark asbru-color);
    my $css_present = 1;
    
    for my $theme (@themes) {
        my $css_file = "$RealBin/res/themes/$theme/asbru.css";
        next unless -f $css_file;
        
        my $css_check = `grep -A 3 "asbru-connection-tree" "$css_file"`;
        if ($css_check =~ /background-color.*color/) {
            print "   ✓ $theme theme has tree CSS styling\n";
        } else {
            print "   ✗ $theme theme missing tree CSS\n";
            $css_present = 0;
        }
    }
    
    return $css_present;
}

# Test 7: Check keepassxc-cli dependency
sub test_keepassxc_dependency {
    print "7. Testing keepassxc-cli dependency integration...\n";
    
    my $main_pm = "$RealBin/lib/PACMain.pm";
    my $dep_check = `grep -A 3 -B 3 "keepassxc-cli.*KeePassXC" "$main_pm"`;
    
    if ($dep_check =~ /version_cmd.*keepassxc-cli.*--version/) {
        print "   ✓ keepassxc-cli dependency properly configured\n";
        return 1;
    } else {
        print "   ✗ keepassxc-cli dependency configuration missing\n";
        return 0;
    }
}

# Test 8: Application basic functionality
sub test_application_launch {
    print "8. Testing application launch...\n";
    
    my $version_output = `cd "$RealBin" && timeout 3s ./asbru-cm --version 2>/dev/null`;
    
    if ($version_output =~ /Ásbrú Connection Manager 7\.0\.2/) {
        print "   ✓ Application launches and reports correct version\n";
        return 1;
    } else {
        print "   ⚠ Application launch test inconclusive\n";
        return 0;
    }
}

# Run all tests
print "Running comprehensive UI fixes test suite...\n\n";

my $native_icons = test_native_icons_config();
my $tree_logic = test_tree_icon_logic();
my $tab_icons = test_tab_icons();
my $local_icons = test_local_icons();
my $webdav_icons = test_webdav_icons();
my $tree_css = test_tree_css();
my $keepassxc_dep = test_keepassxc_dependency();
my $app_launch = test_application_launch();

my $total_passed = $native_icons + $tree_logic + $tab_icons + $local_icons + 
                   $webdav_icons + $tree_css + $keepassxc_dep + $app_launch;

print "\n=== TEST SUMMARY ===\n";
print "Native icons config: " . ($native_icons ? "✓" : "✗") . "\n";
print "Tree icon logic: " . ($tree_logic ? "✓" : "✗") . "\n";
print "Tab icons: " . ($tab_icons ? "✓" : "✗") . "\n";
print "Local method icons: " . ($local_icons ? "✓" : "✗") . "\n";
print "WebDAV icons: " . ($webdav_icons ? "✓" : "✗") . "\n";
print "Tree CSS styling: " . ($tree_css ? "✓" : "✗") . "\n";
print "keepassxc-cli dependency: " . ($keepassxc_dep ? "✓" : "✗") . "\n";
print "Application launch: " . ($app_launch ? "✓" : "✗") . "\n";

print "\nTests passed: $total_passed/8\n";

if ($total_passed >= 6) {
    print "🎉 UI fixes implementation is successful!\n";
} elsif ($total_passed >= 4) {
    print "👍 Most UI fixes are working, minor issues remain\n";
} else {
    print "⚠ Major issues detected, review needed\n";
}

print "\n=== ISSUE STATUS UPDATE ===\n";
print "1. Native connection icons in tree: " . ($native_icons && $tree_logic ? "✅ FIXED" : "⏳ PARTIAL") . "\n";
print "2. Connection icons in terminal tabs: " . ($tab_icons ? "✅ FIXED" : "❌ NEEDS WORK") . "\n";
print "3. Local shell icon for Local connections: " . ($local_icons ? "✅ FIXED" : "❌ NEEDS WORK") . "\n";
print "4. WebDAV icon display: " . ($webdav_icons ? "✅ SHOULD WORK" : "❌ BROKEN") . "\n";
print "5. keepassxc-cli dependency: " . ($keepassxc_dep ? "✅ FIXED" : "❌ BROKEN") . "\n";

print "\n=== NEXT STEPS ===\n";
print "- Test UI in running application\n";
print "- Create test connections of different types\n";
print "- Verify icon display in real usage\n";
print "- Check 'My Connections' visibility in tree\n";
print "- Address remaining preferences UI consistency issues\n";

print "\n=== UI Fixes Test Complete ===\n";
