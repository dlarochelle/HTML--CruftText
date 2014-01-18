package HTML::CruftText;

use 5.012;
use strict;
use warnings;

use Time::HiRes;
use List::MoreUtils qw(first_index indexes last_index);
use Data::Dumper;

# STATICS

# markers -- patterns used to find lines than can help find the text
my $_MARKER_PATTERNS = {
    startclickprintinclude => qr/<\!--\s*startclickprintinclude/pi,
    endclickprintinclude   => qr/<\!--\s*endclickprintinclude/pi,
    startclickprintexclude => qr/<\!--\s*startclickprintexclude/pi,
    endclickprintexclude   => qr/<\!--\s*endclickprintexclude/pi,
    sphereitbegin          => qr/<\!--\s*DISABLEsphereit\s*start/i,
    sphereitend            => qr/<\!--\s*DISABLEsphereit\s*end/i,
    body                   => qr/<body/i,
    comment                => qr/(id|class)="[^"]*comment[^"]*"/i,

    # Any clickprint comment
    clickprint => qr/<\!--\s*(start|end)clickprint(in|ex)clude/pi,
};

#TODO handle sphereit like we're now handling CLickprint.

# blank everything within these elements
my $_AUXILIARY_TAGS = [ qw/script style frame applet textarea/ ];


# Preserve newlines in the match
sub _preserve_newlines($)
{
    my $data = shift;

    # Retain the number of newlines
    my $newlines = ($data =~ tr/\n//);

    return "\n" x $newlines;    
}


# Decide upon the HTML comment's contents
sub _comment_contents_for_comment($)
{
    my $comment = shift;

    # Don't touch clickprint comments
    return($comment) if ($comment =~ $_MARKER_PATTERNS->{clickprint});

    return _preserve_newlines($comment);
}

# Remove HTML comments retaining the number of lines;
# remove >'s from inside comments so the simple line density scorer
# doesn't get confused about where tags end
sub _remove_comments($)
{
    my $html = shift;

    $html =~ s/<!--(.*?)-->/_comment_contents_for_comment($&)/sige;

    return $html;
}


sub _prepend_every_line_with_tag($$)
{
    my ($tag_name, $data) = @_;

    $data =~ s/\n/ >\n$tag_name /gs;

    return $data;
}

# make sure that all tags start and close on one line
# by adding false <>s as necessary, eg:
#
# <foo
# bar>
#
# becomes
#
# <foo>
# <tag bar>
#
sub _fix_multiline_tags($)
{
    my $html = shift;

    $html =~ s/

        # Start of the tag (e.g. "<foo")
        (<[^\s>]*)

        # Anything but the ">" and a linebreak (tag doesn't end on the same line)
        [^>]*\n

        # Any content up until the end of the tag (">")
        [^>]*>

        /_prepend_every_line_with_tag($1, $&)/sigex;

    return $html;
}

# Remove all text not within the <body> tag
# Note: some badly formated web pages will have multiple <body> tags or will
# not have an open tag.
# We go the conservative thing of only deleting stuff before the first <body>
# tag and stuff after the last </body> tag.
sub _remove_nonbody_text($)
{
    my $html = shift;

    # Remove everything before the first <body>
    $html =~ s/^(.*?)(<body)/_preserve_newlines($1).$2/sige;

    # Remove everything after the last </body>
    $html =~ s/(.*)(<\/body>)(.*?)$/$1.$2._preserve_newlines($3)/sige;

    return $html;
}

sub _remove_nonclickprint_text($)
{
    my $html = shift;

    # Process the clickprint only if it's present in the HTML
    unless (has_clickprint($html)) {
        return $html;
    }

    # Remove excludes
    $html =~ s/

        (<!--\s*startclickprintexclude\s*-->)
        (.*?)
        (<!--\s*endclickprintexclude\s*-->)

        /$1._preserve_newlines($2).$3/sigex;

    # Remove everything except what's between the first
    # "startclickprintinclude" and the last "endclickprintinclude"
    $html =~ s/

        ^(.*?)
        (
            <!--\s*startclickprintinclude\s*-->
            .*  # greedy!
            <!--\s*endclickprintinclude\s*-->
        )
        (.*?)$

        /_preserve_newlines($1).$2._preserve_newlines($3)/sigex;

    # Remove "inbetween" leftover content between "endclickprintinclude" and
    # "startclickprintinclude"
    $html =~ s/

        (<!--\s*endclickprintinclude\s*-->)
        (.*?)
        (<!--\s*startclickprintinclude\s*-->)

        /$1._preserve_newlines($2).$3/sigex;

    return $html;
}

# remove text within script, style, iframe, applet, and textarea tags
sub _remove_auxiliary_element_text($)
{
    my $html = shift;

    foreach my $tag_to_remove (@{$_AUXILIARY_TAGS}) {

        $html =~ s/(<\Q$tag_to_remove\E\b[^>]*>)(.*?)(<\/\Q$tag_to_remove\E>)/$1._preserve_newlines($2).$3/sigex;

    }

    return $html;
}


my $_start_time;
my $_last_time;

sub _print_time
{
    return;

    my ( $s ) = @_;

    my $t = Time::HiRes::gettimeofday();
    $_start_time ||= $t;
    $_last_time  ||= $t;

    my $elapsed     = $t - $_start_time;
    my $incremental = $t - $_last_time;

    printf( STDERR "time $s: %f elapsed %f incremental\n", $elapsed, $incremental );

    $_last_time = $t;
}

=head1 NAME

HTML::CruftText - Remove unuseful text from HTML

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

Removes junk from HTML page text.

This module uses a regular expression based approach to remove cruft from HTML.
I.e. content/text that is very unlikely to be useful or interesting.


    use HTML::CruftText;

    open (my $MYINPUTFILE, '<input.html' );
    
    my @lines = <$MYINPUTFILE>;

    my $de_crufted_lines = HTML::CruftText::clearCruftText( \@lines);

    ...

=head1 DESCRIPTION

This module was developed for the Media Cloud project (http://mediacloud.org) as
the first step in differentiating article text from ads, navigation, and other
boilerplate text. Its approach is very conservative and almost never removes
legitimate article text. However, it still leaves in a lot of cruft so many
users will want to do additional processing.

Typically, the clearCruftText method is called with an array reference
containing the lines of an HTML file. Each line is then altered so that the
cruft text is removed. After completion some lines will be entirely blank, while
others will have certain text removed. In a few rare cases, additional HTML tags
are added. The result is NOT GUARANTEED to be valid, balanced HTML though some
HTML is retained because it is extremely useful for further processing. Thus
some users will want to run an HTML stripper over the results.

The following tactics are used to remove cruft text:

* Nonbody text --anything outside of the <body></body> tags -- is removed

* Text within the following tags is removed: <script>, <style>, <frame>,
  <applet>, and <textarea>

* clickprint markers -- many web sites have clickprint annotation comments that
  explicitly mark whether text should be included.

* Removal of HTML tags in comments.

* Close tags that span multiple lines within an single open tag. For example,
  we would change:

     FOO<a 
   href="bar.com>BAZ

 to:

     FOO<a >
   <a href="bar.com>BAZ
   
this makes the output easier to process with regular expressions.


=head1 SUBROUTINES/METHODS

=head2 clearCruftText( $lines )

This is the main method for this module. Removes cruft text from $lines and
returns the result. Generally $lines will be a reference to an array of lines
from an HTML file. However, this method can also be called with a string, in
which case, the string will be split into multiple lines and an array reference
of decrufted html lines is returned.

=cut

sub clearCruftText
{
    my $lines = shift;

    my $expected_number_of_lines;
    my $html;

    if (ref ($lines)) {
        # Arrayref
        $expected_number_of_lines = scalar (@{$lines});
        $html = join ("\n", @{ $lines });
    } else {
        # String - change all line endings to Unix
        $html = $lines;

        # 'x' linebreaks make 'x+1' lines (duh.)
        $expected_number_of_lines = ($html =~ s/[\n\r]+/\n/g + 1);
    }

    my $orig_html = $html;

    $html = _remove_comments( $html );
    _print_time( "remove comments" );

    $html = _fix_multiline_tags( $html );
    _print_time( "fix multiline" );

    # _remove_auxiliary_element_text() is run before _remove_nonbody_text()
    # because <script> elements might contain <body>
    $html = _remove_auxiliary_element_text( $html );
    _print_time( "remove auxiliary element text" );

    $html = _remove_nonbody_text( $html );
    _print_time( "remove nonbody" );

    $html = _remove_nonclickprint_text( $html );
    _print_time( "remove clickprint" );

    # Remove the last newline (if there's one) because otherwise split() with
    # -1 limit below will produce an unneeded empty line
    $expected_number_of_lines -= $html =~ s/\n$//;

    # Return arrayref in all cases
    $lines = [ split( "\n", $html, -1 ) ];

    # Make sure that the number of lines is the same as in the input
    my $processed_number_of_lines = scalar(@{ $lines });
    if ($expected_number_of_lines != $processed_number_of_lines) {

        my $error = "The number of lines changed after processing the input HTML.\n";
        $error .= "Expected # of lines: $expected_number_of_lines;\n";
        $error .= "Actual # of lines: $processed_number_of_lines.\n";
        $error .= "\n";
        $error .= "Input HTML: --cut--\n" . $orig_html . "\n--cut--\n";
        $error .= "\n";
        $error .= "Output HTML: --cut--\n" . $html . "\n--cut--\n";
        $error .= "\n";

        warn $error;
    }

    return $lines;
}

=head2 has_clickprint ( $lines )

Returns true if the HTML in $lines has clickprint annotation comment tags.
Returns false otherwise.

=cut

sub has_clickprint($)
{
    my $lines = shift;

    if (ref ($lines)) {
        # Arrayref
        $lines = join ("\n", @{ $lines });
    }

    if ($lines =~ $_MARKER_PATTERNS->{ startclickprintinclude }) {
        return 1;
    } else {
        return 0;
    }
}


=head1 AUTHOR

David Larochelle, C<< <dlarochelle at cyber.law.harvard.edu> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-html-crufttext at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTML-CruftText>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTML::CruftText


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTML-CruftText>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTML-CruftText>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTML-CruftText>

=item * Search CPAN

L<http://search.cpan.org/dist/HTML-CruftText/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Berkman Center for Internet & Society at Harvard University.

This program is released under the following license: aAffero General Public License


=cut

1; # End of HTML::CruftText
