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
    },
    rounded => {
        top_left     => '╭',
        top_right    => '╮',
        bottom_left  => '╰',
        bottom_right => '╯',
        horizontal   => '─',
        vertical     => '│'
    },
    thick => {
        top_left     => '┏',
        top_right    => '┓',
        bottom_left  => '┗',
        bottom_right => '┛',
        horizontal   => '━',
        vertical     => '┃'
    },
    ascii => {
        top_left     => '+',
        top_right    => '+',
        bottom_left  => '+',
        bottom_right => '+',
        horizontal   => '-',
        vertical     => '|'
    }
);

# Default options
my $style = 'simple';
my $padding = 2;
my $input_file = '';
my $title = '';
my $help = 0;

# Parse command line options
GetOptions(
    'style=s'   => \$style,
    'padding=i' => \$padding,
    'input=s'   => \$input_file,
    'title=s'   => \$title,
    'help|h'    => \$help
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

# Adjust box width if title is longer
if ($title) {
    my $title_width = 3 + length($title) + 1; # 3 spaces + title + 1 space
    if ($title_width > $box_width) {
        $box_width = $title_width;
    }
}

# Print top border with optional title
if ($title) {
    my $title_offset = 2; # horizontal chars before title
    my $title_spacing = 1; # spaces around title
    
    my $prefix = $chars->{horizontal} x $title_offset;
    my $spaced_title = ' ' x $title_spacing . $title . ' ' x $title_spacing;
    my $suffix_width = $box_width - $title_offset - length($spaced_title);
    my $suffix = $chars->{horizontal} x $suffix_width;
    
    print $chars->{top_left} . $prefix . $spaced_title . $suffix . $chars->{top_right} . "\n";
} else {
    my $horizontal_line = $chars->{horizontal} x $box_width;
    print $chars->{top_left} . $horizontal_line . $chars->{top_right} . "\n";
}

# Print content lines
if ($title) {
    # Add empty line after title for visual separation
    my $content_width = $box_width - (2 * $padding);
    my $empty_line = ' ' x $content_width;
    my $padding_str = ' ' x $padding;
    print $chars->{vertical} . $padding_str . $empty_line . $padding_str . $chars->{vertical} . "\n";
}


for my $line (@lines) {
    my $content_width = $box_width - (2 * $padding);
    my $padded_line = $line . (' ' x ($content_width - length($line)));
    my $padding_str = ' ' x $padding;
    
    print $chars->{vertical} . $padding_str . $padded_line . $padding_str . $chars->{vertical} . "\n";
}

# Print bottom border
my $horizontal_line = $chars->{horizontal} x $box_width;
print $chars->{bottom_left} . $horizontal_line . $chars->{bottom_right} . "\n";

sub print_help {
    print <<'EOF';
bi - Box It: Put text inside ASCII box drawing characters

USAGE:
    bi [OPTIONS]
    bi --input FILE [OPTIONS]
    echo "text" | bi [OPTIONS]

OPTIONS:
    --style STYLE     Box style: simple, double, rounded, thick, ascii (default: simple)
    --padding NUM     Padding around text (default: 2)
    --input FILE      Read from file instead of STDIN
    --title TEXT      Add title to top border
    --help, -h        Show this help message

EXAMPLES:
    echo "Hello World" | bi
    bi --input myfile.txt --style double --title "My Code"
    bi --padding 1 --style rounded < input.txt

STYLES:
    simple:  ┌─┐ │ │ └─┘
    double:  ╔═╗ ║ ║ ╚═╝
    rounded: ╭─╮ │ │ ╰─╯
    thick:   ┏━┓ ┃ ┃ ┗━┛
    ascii:   +-+ | | +-+
EOF
}