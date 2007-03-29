package Template::Recall;

use 5.008008;
use strict;
use warnings;

use base qw(Template::Recall::Base);

our $VERSION='0.05';


sub new {

	
	my $class = shift;
	my $self = {};

	my ( %h ) = @_;


	# Set default values
	$self->{'is_file_template'} = 0;
	$self->{'template_flavor'} = qr/html$|htm$/i;
	$self->{'template_secpat'} = qr/<%\s*=+\s*\w+\s*=+\s*%>/;		# Section pattern
	$self->{'delims'} = [ '<%', '%>' ];

	

	bless( $self, $class );


	# Compile flavor, if there is one
	$self->{'template_flavor'} = $h{'flavor'} if defined( $h{'flavor'} );



	# User defines section pattern
	$self->{'template_secpat'} = qr/$h{'secpat'}/ if defined( $h{'secpat'} ); 



	# User sets 'no delimiters'
	$self->{'delims'} = undef if defined($h{'delims'}) and !ref($h{'delims'});
		
	# User specifies delimiters
	$self->{'delims'} = [ @{ $h{'delims'} } ] if defined($h{'delims'}) and ref($h{'delims'});



	# Check the path
	$self->{'template_path'} = '.' if ( not defined($h{'template_path'}) or !-e $h{'template_path'} );		# Default is local dir



	# Single file template:

	if ( defined($h{'template_path'} ) and -f $h{'template_path'} ) {

		$self->{'template_path'} = $h{'template_path'};
		$self->{'is_file_template'} = 1;	# true

		$self->init_file_template();

		return $self;

	}
	elsif ( defined($h{'template_path'}) and -d $h{'template_path'} ) {		# It's a directory

		$self->{'template_path'} = $h{'template_path'};

	}



	$self->{'template_path'} =~ s/\\$|\/$//g;	# Remove last slash
	$self->{'template_path'} =~ s/\\/\//g;		# All forward slashes


	# Get all the template files in the given directory

	opendir(DIR, $self->{'template_path'}) || die "Can't open $self->{'template_path'} $!";
	$self->{'template_files'} = 
		[	map { "$self->{'template_path'}/$_" } 
			grep { /$self->{'template_flavor'}/ && -f "$self->{'template_path'}/$_" } 
			readdir(DIR) ];
	closedir(DIR);

	return $self;



} # new()






sub render {

	my ( $self, $tpattern, %h ) = @_;

	# Parameter checks
	my $np = @_;
	if ($np < 2) { return "Incorrect number of parameters: $np"; }

	 

	# Single file template handling

	if ( $self->{'is_file_template'} and %h )
	{
		return render_file($self, $tpattern, \%h)
	}
	elsif ( $self->{'is_file_template'} ) {			# No tags to replace
		return render_file($self, $tpattern); 
	}


	# Multiple file template handling


	# It's preloaded:

	if ( defined($self->{'preloaded'}{$tpattern}) ) {

		return $self->SUPER::render( $self->{'preloaded'}{$tpattern}, \%h, $self->{'delims'} );

	}




	# Load template file from disk

	# Does file exist at our location?
	my $file;
	for( @{ $self->{'template_files'} } ) {		
		$file = $_ and last if /$tpattern/;
	}

	# If we've found it, render it
	if (defined($file)) {
		my $t;
		open(F, $file) or die "Couldn't open $file $!";
		while(<F>) { $t .= $_; }
		close(F);
		
		return $self->SUPER::render( $t, \%h, $self->{'delims'} );

	}


} # render()




# Handles rendering when template is stored in single, sectioned template file

sub render_file {

	my ( $self, $tpattern, $hash_ref ) = @_;

	my $retval;

	my @template_secs = @{ $self->{'template_secs'} };

	for ( my $i=0; $i<$#template_secs; $i++ ) {

		if ( $template_secs[$i] =~ /$tpattern/ ) {

			return $template_secs[$i+1] if ( not ref($hash_ref) ); # Return template untouched

			$retval = $template_secs[$i+1]; # Make copy -- necessary

			return $self->SUPER::render( $retval, $hash_ref, $self->{'delims'} );	
			
		}

	}


	return;

} # render_file()





# Preload template in memory (template sections in multiple files only)

sub preload {

	my ($self, $tpattern) = @_;
	
	return if not defined($tpattern) or $self->{'is_file_template'} == 1;

	# Get the appropriate file
	my $file;
	for( @{ $self->{'template_files'} } ) {
		$file = $_ and last if /$tpattern/;
	}


	if (defined($file)) {
		my $t;
		
		open(F, $file) or die "Couldn't open $file $!";
		while(<F>) { $t .= $_; }
		close(F);

		$self->{'preloaded'}{$tpattern} = $t;

	}


	return;
	
} # preload()



# Remove template from memory (multiple file templates only)

sub unload {
		my ($self, $tpattern) = @_;
		delete $self->{'preloaded'}{$tpattern};
}





# Load the single file template into array of sections

sub init_file_template {

	my $self = shift;

	my $t;
	open(F, $self->{'template_path'}) or die "Couldn't open $self->{'template_path'} $!";
	while(<F>) { $t .= $_; }
	close(F);

	$self->{'template_secs'} = [ split( /($self->{'template_secpat'})/, $t ) ];


} # init_file_template()




1;


__END__

=head1 NAME

Template::Recall - "Reverse callback" templating system


=head1 SYNOPSIS
	
	use Template::Recall;

	my $tr = Template::Recall->new( template_path => '/path/to/template/sections' );

	my @prods = (
		'soda,sugary goodness,$.99', 
		'energy drink,jittery goodness,$1.99',
		'green tea,wholesome goodness,$1.59'
		);

	$tr->render('header');

	# Load template into memory

	$tr->preload('prodrow');
							
	for (@prods) 
	{
		my %h;
		my @a = split(/,/, $_);

		$h{'product'} = $a[0];
		$h{'description'} = $a[1];
		$h{'price'} = $a[2];

		print $tr->render('prodrow', %h);
	}

	# Remove template from memory

	$tr->unload('prodrows');

	print $tr->render('footer');

=head1 DESCRIPTION	

Template::Recall works using what I call a "reverse callback" approach. A "callback" templating system (i.e. Mason, Apache::ASP) generally includes template markup and code in the same file. The template "calls" out to the code where needed. Template::Recall works in reverse. Rather than inserting code inside the template, the template remains separate, but broken into sections. The sections are called from within the code at the appropriate times.

A template section is merely a file on disk (or a "marked" section in a single file). For instance, 'prodrow' above (actually F<prodrow.html> in the template directory), might look like

	<tr>
		<td><% product %></td>
		<td><% description %></td>
		<td><%price%></td>
	</tr>

The C<render()> method is used to "call" out to the template sections. Simply create a hash of name/value pairs that represent the template tags you wish to replace, and pass it along with the template section, i.e.

	$tr->render('prodrow', %h);

=head1 METHODS

=head3 C<new( [template_path =E<gt> $path ] [, flavor =E<gt> $template_flavor] [, secpat =E<gt> $section_pattern ] [, delims =E<gt> ['opening', 'closing' ] ] )>

Instantiates the object. If you do not specify C<template_path>, it will assume templates are in the diretory that the script lives in. If C<template_path> points to a file rather than a directory, it loads all the template sections from this file. The file must be sectioned using the "section pattern", which can be adjusted via C<secpat>.

C<flavor> is a pattern to specify what type of template to load. This is C</html$|htm$/i> by default, which picks up HTML file extensions. You could set it to C</xml$/i>, for instance, to get *.xml files.

C<secpat>, by default, is C</E<lt>%\s*=+\s*\w+\s*=+\s*%E<gt>/>. So if you put all your template sections in one file, the way Template::Recall knows where to get the sections is via this pattern, e.g.

	<% ==================== header ==================== %>
	<html
		<head><title>Untitled</title></head>
	<body>

	<table>

	<% ==================== prodrow ==================== %>
	<tr>
		<td><% product %></td>
		<td><% description %></td>
		<td><% price %></td>
	</tr>
	
	<% ==================== footer ==================== %>
	
	</table>

	</body>
	</html>

You may set C<secpat> to any pattern you wish.	

The default delimeters for Template::Recall are C<E<lt>%> (opening) and C<%E<gt>> (closing). This tells Template::Recall that C<E<lt>% price %E<gt>> is different from "price" in the same template, e.g.

	What is the price? It's <% price %>

You can change C<delims> by passing a two element array to C<new()> representing the opening and closing delimiters, such as C<delims =E<gt> [ '(%', '%)' ]>. If you don't want to use delimiters at all, simply set C<delims =E<gt> 'none'>.

=head3 C<render( $template_pattern [, %hash_of_replacements ] );>

You must specify C<$template_pattern>, which tells C<render()> what template "section" to load. C<%hash_of_replacements> is optional. Sometimes you just want to return a template section without any variables. Usually, C<%hash_of_replacements> will be used, and C<render()> iterates through the hash, replacing the F<key> found in the template with the F<value> associated to F<key>.

=head3 C<preload( $template_pattern );>

In the loop over C<@prods> in the synopsis, the 'prodrow' template is being accessed multiple times. If the section is stored in a file, i.e. F<prodrow.html>, you have to read from the disk every time C<render()> is called. C<preload()> allows you to load a template section file into memory. Then, every time C<render()> is called, it pulls the template from memory rather than disk. This does not work for single file templates, since they are already loaded into memory.

=head3 C<unload( $template_pattern );>

When you are finished with the template, free up the memory.

=head1 AUTHOR

James Robson E<lt>info F<AT> arbingersys F<DOT> com

=head1 SEE ALSO

http://perl.apache.org/docs/tutorials/tmpl/comparison/comparison.html
