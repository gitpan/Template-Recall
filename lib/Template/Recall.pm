package Template::Recall;

use 5.008001;
use strict;
use warnings;

use base qw(Template::Recall::Base);

# This version: only single file template or template string
our $VERSION='0.18';


sub new {

	my $class = shift;
	my $self = {};

	my ( %h ) = @_;

	# Set default values
	$self->{'is_file_template'} = 0;
	$self->{'template_secpat'} = qr/\[\s*=+\s*\w+\s*=+\s*\]/;		# Section pattern
	$self->{'secpat_delims'} = [ '\[\s*=+\s*', '\s*=+\s*\]' ];	# Section delimiters
	$self->{'val_delims'} = [ '\[\'', '\'\]' ];
	$self->{'trim'} = undef;		# undef=off
    #TODO remove?
	$self->{'stored_secs'} = {};	# Store rendered sections internally


	bless( $self, $class );

	# User defines section pattern
	$self->{'template_secpat'} = qr/$h{'secpat'}/ if defined( $h{'secpat'} );

	# Section: User sets 'no delimiters'
	$self->{'secpat_delims'} = undef
		if defined($h{'secpat_delims'}) and !ref($h{'secpat_delims'});

	# Section: User specifies delimiters
	$self->{'secpat_delims'} = [ @{ $h{'secpat_delims'} } ]
		if defined($h{'secpat_delims'}) and ref($h{'secpat_delims'});


	# User sets 'no delimiters'
	$self->{'val_delims'} = undef if defined($h{'val_delims'}) and !ref($h{'val_delims'});

	# User specifies delimiters
	$self->{'val_delims'} = [ @{ $h{'val_delims'} } ]
		if defined($h{'val_delims'}) and ref($h{'val_delims'});

	# User supplied the template from a string

	if ( defined($h{'template_str'}) ) {
		$self->init_template($h{'template_str'});
		return $self;
	}
    else {
        die if ( not defined($h{'template_path'}) or !-e $h{'template_path'} );
    }

    $self->{'template_path'} = $h{'template_path'};
    $self->init_template_from_file();

	return $self;

} # new()






sub render {

	my ( $self, $section, $hash_ref ) = @_;

	return "Error: no section to render: $section\n" if !defined($section);

    return if (!exists $self->{'template_secs'}->{$section});

    my $sectemp = $self->{'template_secs'}->{$section};

    #TODO is it faster if the default delim allows for *no* spaces between ID
    return $self->SUPER::render( $sectemp, $hash_ref, $self->{'val_delims'} );

} # render()






# Load the single file template into array of sections

sub init_template_from_file {

	my $self = shift;

	my $t;
    open my $fh, $self->{'template_path'} or die "Couldn't open $self->{'template_path'} $!";
	while(<$fh>) { $t .= $_; }
	close $fh;
    $self->init_template($t);

} # init_file_template()





# Handle template passed by user as string

sub init_template {

    my ($self, $template) = @_;

    my $sec = [ split( /($self->{'template_secpat'})/, $template ) ];

    my %h;
    my $curr = '';

    # top-down + only one 'body' follows section, why this parse hack works
    for (@$sec) {
        next if /^$/;
        if (/$self->{'template_secpat'}/) {
            $curr = $_;
            $curr =~ s/$self->{'secpat_delims'}[0]|$self->{'secpat_delims'}[1]//g;
            $h{$curr} = '';
        }
        else {
            $h{$curr} = $_;
        }
    }

    $self->{'template_secs'} = \%h;

}






# Set trim flags
sub trim {
	my ($self, $flag) = @_;



	# trim() with no params defaults to trimming both ends
	if (!defined($flag)) {
		$self->{'trim'} = 'both';
		return;
	}



	# Turn trimming off
	if ($flag =~ /^(off|o)$/i) {
		$self->{'trim'} = undef;
		return;
	}


	# Make sure we get something valid
	if ($flag !~ /^(off|left|right|both|l|r|b|o)$/i) {
		$self->{'trim'} = undef;
		return;
	}


	$self->{'trim'} = $flag;
	return;


} # trim()



1;


__END__

=head1 NAME

Template::Recall - "Reverse callback" templating system


=head1 SYNOPSIS

	use Template::Recall;

	# Load template sections from file
	my $tr = Template::Recall->new( template_path => '/path/to/template_file.html' );

	my @prods = (
		'soda,sugary goodness,$.99',
		'energy drink,jittery goodness,$1.99',
		'green tea,wholesome goodness,$1.59'
		);

	$tr->render('header');

	for (@prods)
	{
		my %h;
		my @a = split(/,/, $_);

		$h{'product'} = $a[0];
		$h{'description'} = $a[1];
		$h{'price'} = $a[2];

		print $tr->render('prodrow', \%h);
	}

	print $tr->render('footer');

=head1 DESCRIPTION

Template::Recall works using what I call a "reverse callback" approach. A
"callback" templating system (i.e. Mason, Apache::ASP) generally includes
template markup and code in the same file. The template "calls" out to the code
where needed. Template::Recall works in reverse. Rather than inserting code
inside the template, the template remains separate, but broken into sections.
The sections are called from within the code at the appropriate times.

A template section is merely a file on disk. For instance, 'prodrow' above
(actually F<prodrow.html> in the template directory), might look like

	<tr>
		<td>[' product ']</td>
		<td>[' description ']</td>
		<td>['price']</td>
	</tr>

The C<render()> method is used to "call" back to the template sections. Simply
create a hash of name/value pairs that represent the template tags you wish to
replace, and pass a reference of it along with the template section, i.e.

	$tr->render('prodrow', \%h);

=head1 METHODS

=head3 C<new( [ template_path =E<gt> $path, secpat =E<gt> $section_pattern, delims =E<gt> ['opening', 'closing'] ] )>

Instantiates the object. If you do not specify C<template_path>, it will assume
templates are in the directory that the script lives in. If C<template_path>
points to a file rather than a directory, it loads all the template sections
from this file. The file must be sectioned using the "section pattern", which
can be adjusted via the C<secpat> parameter.

C<secpat>, by default, is C<[\s*=+\s*\w+\s*=+\s*]/>. So if you put all your
template sections in one file, the way Template::Recall knows where to get the
sections is via this pattern, e.g.

	[ ==================== header ==================== ]
	<html
		<head><title>Untitled</title></head>
	<body>

	<table>

	[ ==================== prodrow ==================== ]
	<tr>
		<td>[' product ']</td>
		<td>[' description ']</td>
		<td>[' price ']</td>
	</tr>

	[==================== footer ==================== ]

	</table>

	</body>
	</html>

You may set C<secpat> to any pattern you wish. Note that if you use delimiters
(i.e. opening and closing symbols) for the section pattern, you will also need
to set the C<secpat_delims> parameter to those delimiters. So if you had set
C<secpat> to that above, you would need also need to set C<secpat_delims =E<gt>
[ '[\s*=+\s*', '\s*=+\s*]' ]>. If you decide to not use delimiters, and use
something like C<secpat =E<gt> qr/MYTEMPLATE_SECTION_\w+/>, then you must set
C<secpat_delims =E<gt> 'no'>.

The default delimeters for variables in Template::Recall are C<['> (opening)
and C<']> (closing). This tells Template::Recall that C<[' price ']> is
different from "price" in the same template, e.g.

	What is the price? It's [' price ']

You can change C<delims> by passing a two element array to C<new()>
representing the opening and closing delimiters, such as C<delims =E<gt> [
'E<lt>%', '%E<gt>' ]>. If you don't want to use delimiters at all, simply set
C<delims =E<gt> 'none'>.

The C<template_str> parameter allows you to pass in a string that contains the
template data, instead of reading it from disk:

C<new( template_str =E<gt> $str )>

For example, this enables you to store templates in the C<__DATA__> section of
the calling script

=head3 C<render( $section [, $reference_to_hash ] );>

You must specify C<$section>, which tells C<render()> what template
"section" to load. C<$reference_to_hash> is optional. Sometimes you just want
to return a template section without any variables. Usually,
C<$reference_to_hash> will be used, and C<render()> iterates through the hash,
replacing the F<key> found in the template with the F<value> associated to
F<key>. A reference was chosen for efficiency. The hash may be large, so either
pass it using a backslash like in the synopsis, or do something like
C<$hash_ref = { 'name' =E<gt> 'value' }> and pass C<$hash_ref>.

=head3 C<trim( 'off|left|right|both' );>

You may want to control whitespace in your section output. You could use
C<s///> on the returned text, of course, but C<trim()>is included for
convenience and clarity. Simply pass the directive you want when you call it,
e.g.

	$tr->trim('right');
	print $tr->render('sec1', \%values);
	$tr->trim('both')
	print $tr->render('sec2', \%values2);
	$tr->trim('off');
	# ...etc...

If you just do

	$tr->trim();

it will default to trimming both ends of the template. Note that you can also
use abbreviations, i.e. C<$tr-E<gt>trim( 'o|l|r|b' )> to save a few keystrokes.

=head1 AUTHOR

James Robson E<lt>arbingersys F<AT> gmail F<DOT> comE<gt>

=head1 SEE ALSO

http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html
