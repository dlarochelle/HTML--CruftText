#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10 + 1 + 1;
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

    $expected_output =  "        This is body.\n";
    $expected_output .= "        <!-- This is a -->\n";
    $expected_output .= "<!--              multiline comment. -->\n";
    $expected_output .= "        This is the rest of the body.\n";

    is(HTML::CruftText::_remove_tags_in_comments($input), $expected_output, '_remove_tags_in_comments - Basic test');

    # Comment with '>' inside
    $input =  "        This is body.\n";
    $input .= "        <!-- This is a\n";
    $input .= "             multiline comment that includes <<, > and whatnot. -->\n";
    $input .= "        This is the rest of the body.\n";

    $expected_output =  "        This is body.\n";
    $expected_output .= "        <!-- This is a -->\n";
    $expected_output .= "<!--              multiline comment that includes ||, | and whatnot. -->\n";
    $expected_output .= "        This is the rest of the body.\n";

    is(HTML::CruftText::_remove_tags_in_comments($input), $expected_output, '_remove_tags_in_comments - Comment with "<" and ">" inside');

    # RDF comment
    $input =  "             <!--\n";
    $input .= "             <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n";
    $input .= "             xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n";
    $input .= "             xmlns:trackback=\"http://madskills.com/public/xml/rss/module/trackback/\">\n";
    $input .= "         <rdf:Description rdf:about=\"http://globalvoicesonline.org/2009/06/11/amplified-conversation-fighting-the-digital-crimes-bill-in-brazil/\"\n";
    $input .= "    dc:identifier=\"http://globalvoicesonline.org/2009/06/11/amplified-conversation-fighting-the-digital-crimes-bill-in-brazil/\"\n";
    $input .= "    dc:title=\"Brazil: Amplified conversations to fight the Digital Crimes Bill\"\n";
    $input .= "    trackback:ping=\"http://globalvoicesonline.org/2009/06/11/amplified-conversation-fighting-the-digital-crimes-bill-in-brazil/trackback/\" />\n";
    $input .= "</rdf:RDF>               -->\n";

    $expected_output =  "             <!-- -->\n";
    $expected_output .= "<!--              |rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" -->\n";
    $expected_output .= "<!--              xmlns:dc=\"http://purl.org/dc/elements/1.1/\" -->\n";
    $expected_output .= "<!--              xmlns:trackback=\"http://madskills.com/public/xml/rss/module/trackback/\"| -->\n";
    $expected_output .= "<!--          |rdf:Description rdf:about=\"http://globalvoicesonline.org/2009/06/11/amplified-conversation-fighting-the-digital-crimes-bill-in-brazil/\" -->\n";
    $expected_output .= "<!--     dc:identifier=\"http://globalvoicesonline.org/2009/06/11/amplified-conversation-fighting-the-digital-crimes-bill-in-brazil/\" -->\n";
    $expected_output .= "<!--     dc:title=\"Brazil: Amplified conversations to fight the Digital Crimes Bill\" -->\n";
    $expected_output .= "<!--     trackback:ping=\"http://globalvoicesonline.org/2009/06/11/amplified-conversation-fighting-the-digital-crimes-bill-in-brazil/trackback/\" /| -->\n";
    $expected_output .= "<!-- |/rdf:RDF|               -->\n";

    is(HTML::CruftText::_remove_tags_in_comments($input), $expected_output, '_remove_tags_in_comments - RDF comment');

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
    $expected_output .= "        Some more text.\n";

    is(HTML::CruftText::_fix_multiline_tags($input), $expected_output, '_fix_multiline_tags - Basic test');

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
    $expected_output .= "        Even more text.\n";

    is(HTML::CruftText::_fix_multiline_tags($input), $expected_output, '_fix_multiline_tags - Text between tags');

    # Tags on the same line
    $input =  "        Some text.\n";
    $input .= "        <foo>\n";
    $input .= "        <bar>\n";
    $input .= "        Some more text.\n";

    $expected_output =  "        Some text.\n";
    $expected_output .= "        <foo>\n";
    $expected_output .= "        <bar>\n";
    $expected_output .= "        Some more text.\n";  # sans the last newline

    is(HTML::CruftText::_fix_multiline_tags($input), $expected_output, '_fix_multiline_tags - Tags on the same line');
}

sub test_remove_nonbody_text()
{
    my $input;
    my $expected_output;

    # Basic test
    $input =  "<html>\n";
    $input .= "<head>\n";
    $input .= "  <title>This is a test</title>\n";
    $input .= "</head>\n";
    $input .= "<body>\n";
    $input .= "<p>This is a paragraph.</p>\n";
    $input .= "<p>This is another paragraph.</p>\n";
    $input .= "</body>\n";
    $input .= "</html>\n";
    
    $expected_output =  "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .=  "<body>\n";
    $expected_output .= "<p>This is a paragraph.</p>\n";
    $expected_output .= "<p>This is another paragraph.</p>\n";
    $expected_output .= "</body>\n";
    $expected_output .= "\n";

    is(HTML::CruftText::_remove_nonbody_text($input), $expected_output, '_remove_nonbody_text - Basic test');

    # Multiple <body> elements
    $input =  "<html>\n";
    $input .= "<head>\n";
    $input .= "  <title>This is a test</title>\n";
    $input .= "</head>\n";
    $input .= "<body>\n";
    $input .= "<p>This is a paragraph.</p>\n";
    $input .= "<p>This is another paragraph.</p>\n";
    $input .= "</body>\n";
    $input .= "</html>\n";
    $input .= "<html>\n";
    $input .= "<head>\n";
    $input .= "  <title>This is a test</title>\n";
    $input .= "</head>\n";
    $input .= "<body>\n";
    $input .= "<p>This is yet another paragraph.</p>\n";
    $input .= "<p>This is the last paragraph.</p>\n";
    $input .= "</body>\n";
    $input .= "</html>\n";
    
    $expected_output =  "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "<body>\n";
    $expected_output .= "<p>This is a paragraph.</p>\n";
    $expected_output .= "<p>This is another paragraph.</p>\n";
    $expected_output .= "</body>\n";
    $expected_output .= "</html>\n";
    $expected_output .= "<html>\n";
    $expected_output .= "<head>\n";
    $expected_output .= "  <title>This is a test</title>\n";
    $expected_output .= "</head>\n";
    $expected_output .= "<body>\n";
    $expected_output .= "<p>This is yet another paragraph.</p>\n";
    $expected_output .= "<p>This is the last paragraph.</p>\n";
    $expected_output .= "</body>\n";
    $expected_output .= "\n";

    is(HTML::CruftText::_remove_nonbody_text($input), $expected_output, '_remove_nonbody_text - Multiple <body> elements');
}

sub test_remove_auxiliary_element_text()
{
    my $input;
    my $expected_output;

    # Basic test
    $input =  "<html>\n";
    $input .= "<head>\n";
    $input .= "  <title>This is a test</title>\n";
    $input .= "  <script type=\"text/javascript\"><!--\n";
    $input .= "      alert('Well, hello there!');\n";
    $input .= "  --></script>\n";
    $input .= "</head>\n";
    $input .= "<body>\n";
    $input .= "<p>This is a paragraph.</p>\n";
    $input .= "<p>This is another paragraph.</p>\n";
    $input .= "<SCRIPT>\n";
    $input .= "  alert(\"Here goes another JavaScript block.\");\n";
    $input .= "</SCRIPT>\n";
    $input .= "</body>\n";
    $input .= "</html>\n";
    
    $expected_output =  "<html>\n";
    $expected_output .= "<head>\n";
    $expected_output .= "  <title>This is a test</title>\n";
    $expected_output .= "  <script type=\"text/javascript\">\n";
    $expected_output .= "\n";
    $expected_output .= "</script>\n";
    $expected_output .= "</head>\n";
    $expected_output .= "<body>\n";
    $expected_output .= "<p>This is a paragraph.</p>\n";
    $expected_output .= "<p>This is another paragraph.</p>\n";
    $expected_output .= "<SCRIPT>\n";
    $expected_output .= "\n";
    $expected_output .= "</SCRIPT>\n";
    $expected_output .= "</body>\n";
    $expected_output .= "</html>\n";

    is(HTML::CruftText::_remove_auxiliary_element_text($input), $expected_output, '_remove_auxiliary_element_text - Basic test');
}

sub test_remove_nonclickprint_text()
{
    my $input;
    my $expected_output;

    # Basic test
    $input =  "<html>\n";
    $input .= "<head>\n";
    $input .= "  <title>This is a test</title>\n";
    $input .= "</head>\n";
    $input .= "<body>\n";
    $input .= "<p>This is removed.</p>\n";
    $input .= "<!--startclickprintinclude-->\n";    # first include
    $input .= "<p>This is included.</p>\n";
    $input .= "<!--startclickprintexclude-->\n";
    $input .= "<p>This is excluded.</p>\n";
    $input .= "<p>This, too, is excluded.</p>\n";
    $input .= "<!--endclickprintexclude-->\n";
    $input .= "<p>This is also included.</p>\n";
    $input .= "<!--endclickprintinclude-->\n";
    $input .= "<p>This is removed as well.</p>\n";
    $input .= "<!--startclickprintinclude-->\n";    # second include
    $input .= "<p>This is included.</p>\n";
    $input .= "<!--startclickprintexclude-->\n";
    $input .= "<p>This is excluded.</p>\n";
    $input .= "<p>This, too, is excluded.</p>\n";
    $input .= "<!--endclickprintexclude-->\n";
    $input .= "<p>This is also included.</p>\n";
    $input .= "<!--endclickprintinclude-->\n";
    $input .= "</body>\n";
    $input .= "</html>\n";
    
    $expected_output =  "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "<!--startclickprintinclude-->\n";
    $expected_output .= "<p>This is included.</p>\n";
    $expected_output .= "<!--startclickprintexclude-->\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "<!--endclickprintexclude-->\n";
    $expected_output .= "<p>This is also included.</p>\n";
    $expected_output .= "<!--endclickprintinclude-->\n";
    $expected_output .= "\n";
    $expected_output .= "<!--startclickprintinclude-->\n";
    $expected_output .= "<p>This is included.</p>\n";
    $expected_output .= "<!--startclickprintexclude-->\n";
    $expected_output .= "\n";
    $expected_output .= "\n";
    $expected_output .= "<!--endclickprintexclude-->\n";
    $expected_output .= "<p>This is also included.</p>\n";
    $expected_output .= "<!--endclickprintinclude-->\n";
    $expected_output .= "\n";
    $expected_output .= "\n";

    is(HTML::CruftText::_remove_nonclickprint_text($input), $expected_output, '_remove_nonclickprint_text - Basic test');
}

sub main()
{
    test_remove_tags_in_comments();
    test_fix_multiline_tags();
    test_remove_nonbody_text();
    test_remove_auxiliary_element_text();
    test_remove_nonclickprint_text();
}

main();
