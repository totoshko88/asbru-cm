use strict;
use utf8;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

my $have_pacutils = eval { require PACUtils; 1 };
if (!$have_pacutils) {
	plan skip_all => 'PACUtils could not be loaded (Gtk3 not available in test env)';
}
PACUtils->import();

plan tests => 6;

ok($have_pacutils, 'PACUtils loaded');

# Simulate main config presence
$PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'ui emojis'} = 1;

is(PACUtils::emoji('X'), 'X', 'emoji() passes through when enabled');
like(PACUtils::_maybe_strip_emojis('🚀 Start ✨'), qr/Start/, '_maybe_strip_emojis leaves text intact when enabled');

$PACMain::FUNCS{_MAIN}{_CFG}{'defaults'}{'ui emojis'} = 0;

is(PACUtils::emoji('X'), '', 'emoji() returns empty when disabled');
my $stripped = PACUtils::_maybe_strip_emojis('🚀 Start ✨ ✅');
like($stripped, qr/^\s*Start\s*$/, '_maybe_strip_emojis strips emojis when disabled');

pass('emoji preference tests completed');
