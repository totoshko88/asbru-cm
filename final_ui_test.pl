#!/usr/bin/perl

###############################################################################
# Final UI Improvements Test for Ásbrú Connection Manager 7.0.2
# Tests all 10 requested UI improvements
###############################################################################

use strict;
use warnings;
use FindBin qw($RealBin);

print "=== Final UI Improvements Test for Ásbrú CM 7.0.2 ===\n\n";

# Test results tracking
my %results;

# 1. Native connection icons in Info tab
print "1. Testing native connection icons in connection tree...\n";
my $main_pm = "$RealBin/lib/PACMain.pm";
my $native_config = `grep -A 2 "use_native_connection_icons.*1" "$main_pm"`;
my $tree_logic = `grep -A 5 -B 5 "use_native.*connection_method" "$main_pm"`;
if ($native_config && $tree_logic =~ /getConnectionTypeIcon/) {
    print "   ✅ FIXED: Native connection icons enabled and tree logic updated\n";
    $results{1} = 1;
} else {
    print "   ❌ FAILED: Native connection icons not properly configured\n";
    $results{1} = 0;
}

# 2. Connection icons in terminal tabs
print "2. Testing connection icons in terminal tabs...\n";
my $terminal_pm = "$RealBin/lib/PACTerminal.pm";
my $tab_icon_count = `grep -c "connection_method.*_getConnectionTypeIcon" "$terminal_pm"`;
chomp $tab_icon_count;
if ($tab_icon_count >= 3) {
    print "   ✅ FIXED: Tab icons implemented in $tab_icon_count locations\n";
    $results{2} = 1;
} else {
    print "   ❌ FAILED: Tab icons found in only $tab_icon_count locations\n";
    $results{2} = 0;
}

# 3. Local shell icon for Local connections
print "3. Testing Local shell icon for Local connections...\n";
my $local_support = `grep -A 2 -B 2 "PACShell.*Local.*asbru_method_local" "$main_pm"`;
my @themes = qw(default system asbru-dark asbru-color);
my $local_files = 1;
for my $theme (@themes) {
    unless (-f "$RealBin/res/themes/$theme/asbru_method_local.svg") {
        $local_files = 0;
        last;
    }
}
if ($local_support && $local_files) {
    print "   ✅ FIXED: Local connection icons and mapping implemented\n";
    $results{3} = 1;
} else {
    print "   ❌ FAILED: Local connection support incomplete\n";
    $results{3} = 0;
}

# 4. WebDAV icon display
print "4. Testing WebDAV icon display...\n";
my $webdav_mapping = `grep -A 2 -B 2 "WebDAV.*cadaver" "$main_pm"`;
my $webdav_files = 1;
for my $theme (@themes) {
    unless (-f "$RealBin/res/themes/$theme/asbru_method_cadaver.svg") {
        $webdav_files = 0;
        last;
    }
}
if ($webdav_mapping && $webdav_files) {
    print "   ✅ SHOULD WORK: WebDAV icon mapping and files present\n";
    $results{4} = 1;
} else {
    print "   ❌ FAILED: WebDAV icon support incomplete\n";
    $results{4} = 0;
}

# 5. Standardized + button sizes (COMPLEX - checking for preparation)
print "5. Testing + button standardization preparation...\n";
print "   ⏳ COMPLEX: Requires detailed GUI work in preferences\n";
print "   📝 TODO: Standardize button sizes in Global Variables, Local/Remote Commands\n";
$results{5} = 0; # Not implemented - complex task

# 6. Look & Feel tab icon update
print "6. Testing Look & Feel tab icon update...\n";
my $glade_icon = `grep -A 5 -B 5 "preferences-desktop-theme" "$RealBin/res/asbru.glade"`;
if ($glade_icon =~ /image17.*preferences-desktop-theme/) {
    print "   ✅ FIXED: Look & Feel tab icon updated to theme icon\n";
    $results{6} = 1;
} else {
    print "   ❌ FAILED: Look & Feel tab icon not updated\n";
    $results{6} = 0;
}

# 7. Open Online Help button normalization (COMPLEX)
print "7. Testing Open Online Help button normalization...\n";
print "   ⏳ COMPLEX: Requires detailed GUI consistency work\n";
print "   📝 TODO: Normalize help button styling across all preference sections\n";
$results{7} = 0; # Not implemented - complex task

# 8. KeePass integration section icon
print "8. Testing KeePass integration section icon...\n";
my $config_pm = "$RealBin/lib/PACConfig.pm";
my $keepass_icon_code = `grep -A 10 -B 5 "asbru_keepass.svg" "$config_pm"`;
my $keepass_files = 1;
for my $theme (@themes) {
    unless (-f "$RealBin/res/themes/$theme/asbru_keepass.svg") {
        $keepass_files = 0;
        last;
    }
}
if ($keepass_icon_code =~ /set_from_pixbuf/ && $keepass_files) {
    print "   ✅ FIXED: KeePass integration icon updated to use theme icons\n";
    $results{8} = 1;
} else {
    print "   ❌ FAILED: KeePass integration icon not properly updated\n";
    $results{8} = 0;
}

# 9. keepassxc-cli dependency checking
print "9. Testing keepassxc-cli dependency checking...\n";
my $keepass_dep = `grep -A 5 -B 5 "keepassxc-cli.*KeePassXC" "$main_pm"`;
if ($keepass_dep =~ /version_cmd.*keepassxc-cli.*--version/) {
    print "   ✅ FIXED: keepassxc-cli dependency checking implemented\n";
    $results{9} = 1;
} else {
    print "   ❌ FAILED: keepassxc-cli dependency checking missing\n";
    $results{9} = 0;
}

# 10. Font style normalization (COMPLEX)
print "10. Testing font style normalization...\n";
print "   ⏳ COMPLEX: Requires detailed styling audit across preferences\n";
print "   📝 TODO: Normalize font styles, especially KeePass integration section\n";
$results{10} = 0; # Not implemented - complex task

# BONUS: Tree CSS styling
print "\nBONUS: Testing connection tree CSS styling...\n";
my $css_themes = 0;
for my $theme (@themes) {
    my $css_file = "$RealBin/res/themes/$theme/asbru.css";
    if (-f $css_file) {
        my $css_content = `grep -A 5 "asbru-connection-tree" "$css_file"`;
        if ($css_content =~ /background-color.*color/) {
            $css_themes++;
        }
    }
}
if ($css_themes >= 4) {
    print "   ✅ BONUS FIXED: Connection tree CSS styling added to all themes\n";
    $results{bonus} = 1;
} else {
    print "   ❌ BONUS FAILED: CSS styling missing in some themes\n";
    $results{bonus} = 0;
}

# Calculate results
my $fixed_count = grep { $results{$_} } (1..10, 'bonus');
my $total_possible = 11; # 10 main + 1 bonus

print "\n" . "="x60 . "\n";
print "FINAL UI IMPROVEMENTS SUMMARY\n";
print "="x60 . "\n";

print "✅ FULLY IMPLEMENTED:\n";
$results{1} && print "   • Native connection icons in tree\n";
$results{2} && print "   • Connection icons in terminal tabs\n";
$results{3} && print "   • Local shell icon for Local connections\n";
$results{4} && print "   • WebDAV icon display support\n";
$results{6} && print "   • Look & Feel tab icon update\n";
$results{8} && print "   • KeePass integration section icon\n";
$results{9} && print "   • keepassxc-cli dependency checking\n";
$results{bonus} && print "   • BONUS: Connection tree CSS styling\n";

print "\n⏳ REQUIRES COMPLEX GUI WORK:\n";
!$results{5} && print "   • + button standardization in Preferences\n";
!$results{7} && print "   • Open Online Help button normalization\n";
!$results{10} && print "   • Font style normalization across Preferences\n";

print "\n📊 STATISTICS:\n";
print "   • Issues fixed: $fixed_count/$total_possible\n";
my $percentage = int(($fixed_count / $total_possible) * 100);
print "   • Completion rate: $percentage%\n";

if ($fixed_count >= 7) {
    print "\n🎉 EXCELLENT! Most UI improvements successfully implemented!\n";
} elsif ($fixed_count >= 5) {
    print "\n👍 GOOD! Major UI improvements completed successfully!\n";
} else {
    print "\n⚠ PARTIAL: Some core improvements need attention\n";
}

print "\n📋 TESTING RECOMMENDATIONS:\n";
print "1. Launch application and test connection tree icon display\n";
print "2. Create connections of different types (SSH, RDP, Local, WebDAV)\n";
print "3. Verify icons appear in terminal tabs when connections open\n";
print "4. Check 'My Connections' visibility against background\n";
print "5. Open Preferences and verify KeePass section icon\n";
print "6. Test dependency validation: ./asbru-cm --verbose\n";

print "\n" . "="x60 . "\n";
print "Final UI Improvements Test Complete\n";
print "="x60 . "\n";

exit 0;
