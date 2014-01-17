#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5 + 1 + 1;
use Test::NoWarnings;

use Readonly;

#
# Note: heredoc is avoided and basic string assigment is used instead because
# it's easier to count the number of spaces / newlines that way.
#

BEGIN
{
    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use_ok( 'HTML::CruftText' );
}

sub test_remove_tags_in_comments()
{
    my $input;
    my $expected_output;

    # Basic test
    $input =  "        This is body.\n";
    $input .= "        <!-- This is a\n";
    $input .= "             multiline comment. -->\n";
    $input .= "        This is the rest of the body.\n";

    $expected_output = "        This is body.\n";
    $expected_output .= "        \n";
    $expected_output .= "\n";
    $expected_output .= "        This is the rest of the body.\n";

    is(HTML::CruftText::_remove_tags_in_comments($input), $expected_output, '_remove_tags_in_comments - Basic test');

    # Comment with '>' inside
    $input =  "        This is body.\n";
    $input .= "        <!-- This is a\n";
    $input .= "             multiline comment that includes <<, > and whatnot. -->\n";
    $input .= "        This is the rest of the body.\n";

    $expected_output = "        This is body.\n";
    $expected_output .= "        \n";
    $expected_output .= "\n";
    $expected_output .= "        This is the rest of the body.\n";

    is(HTML::CruftText::_remove_tags_in_comments($input), $expected_output, '_remove_tags_in_comments - Comment with "<" and ">" inside');    
}

sub test_fix_multiline_tags()
{
    my $input;
    my $expected_output;

    # Basic test
    $input =  "        Some text.\n";
    $input .= "        <foo\n";
    $input .= "        bar>\n";
    $input .= "        Some more text.\n";

    $expected_output =  "        Some text.\n";
    $expected_output .= "        <foo >\n";
    $expected_output .= "<foo         bar>\n";
    $expected_output .= "        Some more text.";

    is(HTML::CruftText::_fix_multiline_tags($input), $expected_output, '_remove_tags_in_comments - Basic test');

    # Text between tags
    $input =  "        Some text.\n";
    $input .= "        <foo\n";
    $input .= "        Some more text.\n";
    $input .= "        bar>\n";
    $input .= "        Even more text.\n";

    $expected_output =  "        Some text.\n";
    $expected_output .= "        <foo >\n";
    $expected_output .= "<foo         Some more text. >\n";
    $expected_output .= "<foo         bar>\n";
    $expected_output .= "        Even more text.";

    is(HTML::CruftText::_fix_multiline_tags($input), $expected_output, '_remove_tags_in_comments - Text between tags');

    # Tags on the same line
    $input =  "        Some text.\n";
    $input .= "        <foo>\n";
    $input .= "        <bar>\n";
    $input .= "        Some more text.\n";

    $expected_output =  "        Some text.\n";
    $expected_output .= "        <foo>\n";
    $expected_output .= "        <bar>\n";
    $expected_output .= "        Some more text.";  # sans the last newline

    is(HTML::CruftText::_fix_multiline_tags($input), $expected_output, '_remove_tags_in_comments - Taks on the same line');
}


sub main()
{
    test_remove_tags_in_comments();
    test_fix_multiline_tags();
}

main();
