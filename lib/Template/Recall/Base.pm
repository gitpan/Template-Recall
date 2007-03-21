package Template::Recall::Base;

use strict;
no warnings;


our $VERSION='0.02'; 


sub render {

	my ( $class, $template, $hash_ref ) = @_;

	if ( not defined ($template) ) { return "Template::Recall::Base::render() 'template' parameter not present"; }

	if ( ref($hash_ref) ) {

		foreach my $k ( keys %{$hash_ref} ) {
			$template =~ s/$k/${$hash_ref}{$k}/g;
		}
	
	}

	return $template;

}

1;
