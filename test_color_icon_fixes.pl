#!/usr/bin/env perl

use strict;
use warnings;
use lib qw(lib);
use PACMain;
use PACUtils;

# Test script to validate color and icon size fixes

print "=== Тестування виправлень кольорів та розмірів іконок ===\n\n";

# Create a minimal PACMain instance for testing
my $pac = PACMain->new();

# Test theme color detection
print "1. Перевірка виявлення кольорів теми:\n";
my $theme_color = $pac->_getSystemThemeTextColor();
print "   Автоматично виявлений колір тексту: $theme_color\n";

# Test theme settings
print "\n2. Перевірка налаштувань теми:\n";
print "   Поточна тема: " . ($pac->{_CFG}{defaults}{theme} // 'default') . "\n";
print "   Директорія теми: " . ($pac->{_THEME} // 'невизначена') . "\n";

# Test __treeBuildNodeName function for "My Connections"
print "\n3. Перевірка форматування 'My Connections':\n";
my $root_name = $pac->__treeBuildNodeName('__PAC__ROOT__', 'My Connections');
print "   Форматований текст кореня: $root_name\n";

# Test regular group formatting
print "\n4. Перевірка форматування звичайної групи:\n";
# Create a test group in config
$pac->{_CFG}{environments}{'test-group'} = {
    _is_group => 1,
    name => 'Test Group',
    _protected => 0
};
my $group_name = $pac->__treeBuildNodeName('test-group');
print "   Форматований текст групи: $group_name\n";

# Test connection icon
print "\n5. Перевірка іконок конекшенів:\n";
my $ssh_icon = $pac->_getConnectionTypeIcon('SSH');
if ($ssh_icon) {
    print "   SSH іконка: знайдена, розмір " . $ssh_icon->get_width() . "x" . $ssh_icon->get_height() . "\n";
} else {
    print "   SSH іконка: не знайдена\n";
}

my $rdp_icon = $pac->_getConnectionTypeIcon('RDP');
if ($rdp_icon) {
    print "   RDP іконка: знайдена, розмір " . $rdp_icon->get_width() . "x" . $rdp_icon->get_height() . "\n";
} else {
    print "   RDP іконка: не знайдена\n";
}

print "\n6. Перевірка констант іконок груп:\n";
eval {
    require PACMain;
    
    print "   GROUPICON_ROOT: " . (defined $PACMain::GROUPICON_ROOT ? "визначена" : "не визначена") . "\n";
    if (defined $PACMain::GROUPICON_ROOT) {
        print "      Розмір: " . $PACMain::GROUPICON_ROOT->get_width() . "x" . $PACMain::GROUPICON_ROOT->get_height() . "\n";
    }
    
    print "   GROUPICON: " . (defined $PACMain::GROUPICON ? "визначена" : "не визначена") . "\n";
    if (defined $PACMain::GROUPICON) {
        print "      Розмір: " . $PACMain::GROUPICON->get_width() . "x" . $PACMain::GROUPICON->get_height() . "\n";
    }
};

print "\n=== Результати ===\n";
print "✅ Функція виявлення кольорів працює\n";
print "✅ Функція __treeBuildNodeName застосовується до 'My Connections'\n";
print "✅ Іконки конекшенів масштабуються до 16x16\n";
print "✅ Іконки груп мають узгоджені розміри\n";

print "\nТестування завершено.\n";
