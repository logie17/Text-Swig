package Text::Xslate::Syntax::Swig;
use Mouse;

extends 'Text::Xslate::Parser';
use Text::Swig::Symbol;

sub symbol_class { 'Text::Swig::Symbol' }
sub _build_tag_start { '{{' };
sub _build_tag_end { '}}' };

sub undefined_name {
	my $self = shift;
	my ($name) = @_;
	return $self->symbol('(key)')->clone(id => $name);
}

# unsure if we'll need this yet
sub init_symbols {
    my $self = shift;

    for my $type (qw(key)) {
        my $symbol = $self->symbol("($type)");
        $symbol->arity($type);
        $symbol->set_nud($self->can("nud_$type"));
        $symbol->lbp(10);
    }
}

sub nud_key {
    my $self = shift;
    my ($symbol) = @_;

    return $symbol->clone(arity => 'key');
}

__PACKAGE__->meta->make_immutable;
