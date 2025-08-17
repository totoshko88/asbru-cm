#!/usr/bin/env perl
use strict;use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Basename;

# Simple variant generator: duplicates default SVGs into a new theme dir and applies a color transform.
# Usage: perl scripts/generate_theme_variant.pl variant-name #colorhex
# Example: perl scripts/generate_theme_variant.pl asbru-magenta ff00ff

my $variant = shift @ARGV || die "Variant name required\n";
my $hex = shift @ARGV || 'ff6600';
$hex =~ s/^#//; die "Hex color invalid\n" unless $hex =~ /^[0-9a-fA-F]{6}$/;
my ($r,$g,$b) = map { hex($_) } ($hex =~ /(..)(..)(..)/);

my $root = 'res/themes';
my $src = "$root/default";
my $dst = "$root/$variant";
-d $src or die "Source theme not found: $src\n";
if (-d $dst) { die "Destination theme already exists: $dst\n"; }
make_path($dst);

opendir(my $dh,$src) or die $!;
while (my $f = readdir($dh)) {
    next if $f =~ /^(\.|..)$/;
    my $from = "$src/$f";
    my $to = "$dst/$f";
    if ($f =~ /\.svg$/i) {
        open my $IN,'<',$from or die $!;
        local $/; my $svg = <$IN>; close $IN;
        # naive colorization: replace fill="currentColor" or standard greys with target hex
        my $color = sprintf('#%02x%02x%02x',$r,$g,$b);
        $svg =~ s/fill="currentColor"/fill="$color"/g;
        $svg =~ s/stroke="currentColor"/stroke="$color"/g;
        # replace common grayscale fills
        $svg =~ s/fill="#(?:[0-9a-f]{2}){3}"/fill="$color"/ig;
        open my $OUT,'>',$to or die $!;
        print $OUT $svg; close $OUT;
    } else {
        copy($from,$to) or die $!;
    }
}
closedir $dh;

# Copy CSS if present and append variant marker
if (-f "$dst/asbru.css") {
    open my $APP,'>>',"$dst/asbru.css"; print $APP "\n/* Variant generated $variant color #$hex */\n"; close $APP;
}

print "Generated variant theme: $variant (#$hex)\n";
