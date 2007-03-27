package Template::Recall::Base;

use strict;
no warnings;


our $VERSION='0.03'; 


sub render {

	my ( $class, $template, $hash_ref, $delims ) = @_;

	if ( not defined ($template) ) { return "Template::Recall::Base::render() 'template' parameter not present"; }

	if ( ref($hash_ref) ) {

		foreach my $k ( keys %{$hash_ref} ) {

			# $delims must be 2 element array reference
			if ( ref($delims) and $#{$delims} == 1 ) {	
				$template =~ s/${$delims}[0] . '\s*' . $k . '\s*' . ${$delims}[1]/${$hash_ref}{$k}/g;
			}
			else {
				$template =~ s/$k/${$hash_ref}{$k}/g;
			}
			
		} # foreach
	
	} # if

	return $template;

} # render()

1;
