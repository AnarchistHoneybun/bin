#!/usr/bin/env perl
#
# tf
#
# Author: Raj Singh
# License: MIT
# Version: 1.0.1 (2025/08/23)
#

use strict;
use warnings;

sub parse_time {
    my $time_str = shift;
    
    # Remove any whitespace
    $time_str =~ s/\s+//g;
    
    # Split by colons
    my @parts = split /:/, $time_str;
    
    # Pad with zeros if needed and ensure we have exactly 3 parts
    if (@parts == 1) {
        # Just seconds
        unshift @parts, 0, 0;  # Add hours and minutes
    } elsif (@parts == 2) {
        # Minutes:seconds
        unshift @parts, 0;     # Add hours
    } elsif (@parts > 3) {
        die "Invalid time format: $time_str (too many colons)\n";
    }
    
    # Pad each part to handle single digits
    for my $i (0..$#parts) {
        $parts[$i] = sprintf "%02d", $parts[$i];
    }
    
    my ($hours, $minutes, $seconds) = @parts;
    
    # Validate ranges
    die "Invalid minutes: $minutes (must be 0-59)\n" if $minutes > 59;
    die "Invalid seconds: $seconds (must be 0-59)\n" if $seconds > 59;
    die "Invalid hours: $hours (must be >= 0)\n" if $hours < 0;
    die "Invalid minutes: $minutes (must be >= 0)\n" if $minutes < 0;
    die "Invalid seconds: $seconds (must be >= 0)\n" if $seconds < 0;
    
    # Convert to total seconds
    return $hours * 3600 + $minutes * 60 + $seconds;
}

sub usage {
    print "Usage: tf TIME1/TIME2\n";
    print "  Calculate the fraction TIME1/TIME2\n";
    print "  Time format: [H[H]:]M[M]:S[S] or [H[H]:]S[S] or S[S]\n";
    print "  Examples:\n";
    print "    tf 1:00:00/2:00:00  -> 0.5\n";
    print "    tf 30:00/1:00:00    -> 0.5\n";
    print "    tf 1:30/3:00        -> 0.5\n";
    print "    tf 45/90            -> 0.5\n";
    print "    tf 1:0:0/2:0:0      -> 0.5\n";
    exit 1;
}

# Check for help flags
if (@ARGV == 0 || $ARGV[0] =~ /^(-h|--help)$/) {
    usage();
}

# Get the argument
my $input = $ARGV[0];

# Split on forward slash
my @time_parts = split /\//, $input;

if (@time_parts != 2) {
    die "Error: Please provide two times separated by '/'\n";
}

my ($time1_str, $time2_str) = @time_parts;

eval {
    my $time1_seconds = parse_time($time1_str);
    my $time2_seconds = parse_time($time2_str);
    
    if ($time2_seconds == 0) {
        die "Error: Division by zero (second time is 0:00:00)\n";
    }
    
    my $fraction = $time1_seconds / $time2_seconds;
    
    # Print with reasonable precision
    printf "%.6g\n", $fraction;
};

if ($@) {
    print STDERR $@;
    exit 1;
}