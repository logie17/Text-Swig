use strict;
use warnings;
package Text::Swig;

our $VERSION = '0.001';

use base 'Text::Xslate';

sub options {
	my $class = shift;

	my $options = $class->SUPER::options(@_);

  $options->{compiler} = 'Text::Swig::Compiler';
	$options->{helpers} = {};
	return $options;
}

1;
