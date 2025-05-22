#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Getopt::Long;

# Enable UTF-8 output
binmode(STDOUT, ':utf8');

# Box drawing characters
my %styles = (
    simple => {
        top_left     => '┌',
        top_right    => '┐',
        bottom_left  => '└',
        bottom_right => '┘',
        horizontal   => '─',
        vertical     => '│'
    },
    double => {
        top_left     => '╔',
        top_right    => '╗',
        bottom_left  => '╚',
        bottom_right => '╝',
        horizontal   => '═',
        vertical     => '║'
    }
);

# Default options
my $style = 'simple';
my $padding = 2;
my $input_file = '';
my $help = 0;

# Parse command line options
GetOptions(
    'style=s'  => \$style,
    'padding=i' => \$padding,
    'input=s'  => \$input_file,
    'help|h'   => \$help
) or die "Error parsing options!\n";

# Show help
if ($help) {
    print_help();
    exit 0;
}

# Validate style
if (!exists $styles{$style}) {
    die "Error: Unknown style '$style'. Available styles: " . join(', ', keys %styles) . "\n";
}

# Validate padding
if ($padding < 0) {
    die "Error: Padding must be non-negative\n";
}

# Read input
my @lines;
if ($input_file) {
    # Read from file
    open my $fh, '<:utf8', $input_file or die "Cannot open file '$input_file': $!\n";
    @lines = <$fh>;
    close $fh;
    chomp @lines;
} else {
    # Read from STDIN
    binmode(STDIN, ':utf8');
    @lines = <STDIN>;
    chomp @lines;
}

# Handle empty input
if (@lines == 0) {
    @lines = ('');
}

# Calculate maximum line width (accounting for indentation)
my $max_width = 0;
for my $line (@lines) {
    my $width = length($line);
    $max_width = $width if $width > $max_width;
}

# Get box characters for selected style
my $chars = $styles{$style};

# Calculate total box width
my $box_width = $max_width + (2 * $padding);
my $horizontal_line = $chars->{horizontal} x $box_width;

# Print top border
print $chars->{top_left} . $horizontal_line . $chars->{top_right} . "\n";

# Print content lines
for my $line (@lines) {
    my $content_width = $max_width;
    my $padded_line = $line . (' ' x ($content_width - length($line)));
    my $padding_str = ' ' x $padding;
    
    print $chars->{vertical} . $padding_str . $padded_line . $padding_str . $chars->{vertical} . "\n";
}

# Print bottom border
print $chars->{bottom_left} . $horizontal_line . $chars->{bottom_right} . "\n";

sub print_help {
    print <<'EOF';
bi - Box It: Put text inside ASCII box drawing characters

USAGE:
    bi [OPTIONS]
    bi --input FILE [OPTIONS]
    echo "text" | bi [OPTIONS]

OPTIONS:
    --style STYLE     Box style: simple, double (default: simple)
    --padding NUM     Padding around text (default: 2)
    --input FILE      Read from file instead of STDIN
    --help, -h        Show this help message

EXAMPLES:
    echo "Hello World" | bi
    bi --input myfile.txt --style double
    bi --padding 1 --style simple < input.txt

STYLES:
    simple: ┌─┐ │ │ └─┘
    double: ╔═╗ ║ ║ ╚═╝
EOF
}
