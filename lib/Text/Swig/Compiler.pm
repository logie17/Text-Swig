package Text::Swig::Compiler;
use Mouse;

extends 'Text::Xslate::Compiler';

has '+syntax' => (
	    default => 'Swig',
);

sub _generate_key {
    my $self = shift;
    my ($node) = @_;

    my $var = $node->clone(arity => 'variable');

    return $self->compile_ast($self->check_lambda($var));
}

sub _generate_call {
    my $self = shift;
    my ($node) = @_;

    if ($node->is_helper) {
        my @args;
        my @hash;
        for my $arg (@{ $node->second }) {
            if ($arg->arity eq 'pair') {
                push @hash, $arg->first, $arg->second;
            }
            else {
                push @args, $arg;
            }
        }

        my $hash = $self->make_hash(@hash);

        unshift @args, $self->vars;

        if ($node->is_block_helper) {
            push @{ $node->first->second }, $hash;
            $node->second(\@args);
        }
        else {
            $node->second([ @args, $hash ]);
        }
    }

    return $self->SUPER::_generate_call($node);
}

sub _generate_suffix {
    my $self = shift;
    my ($node) = @_;

    return (
        $self->opcode('suffix'),
    );
}

sub find_file {
    my $self = shift;
    my ($filename) = @_;

    return $filename->clone(
        arity => 'unary',
        id    => 'find_file',
        first => $filename,
    );
}

sub _generate_for {
    my $self = shift;
    my ($node) = @_;

    my @opcodes = $self->SUPER::_generate_for(@_);
    return (
        @opcodes,
        $self->opcode('nil'),
    );
}


sub _generate_unary {
    my $self = shift;
    my ($node) = @_;

    # XXX copied from Text::Xslate::Compiler because it uses a hardcoded list
    # of unary ops
    if ($self->is_unary($node->id)) {
        my @code = (
            $self->compile_ast($node->first),
            $self->opcode($node->id)
        );
        # render_string can't be constant folded, because it depends on the
        # current vars
        if ($Text::Xslate::Compiler::OPTIMIZE and $self->_code_is_literal(@code) && $node->id ne 'render_string' && $node->id ne 'find_file') {
            $self->_fold_constants(\@code);
        }
        return @code;
    }
    else {
        return $self->SUPER::_generate_unary(@_);
    }
}

sub is_unary {
    my $self = shift;
    my ($id) = @_;

    my %unary = (
        map { $_ => 1 } qw(builtin_is_array_ref builtin_is_hash_ref is_code_ref
                           find_file)
    );

    return $unary{$id};
}

sub _generate_array_length {
    my $self = shift;
    my ($node) = @_;

    my $max_index = $self->parser->symbol('(max_index)')->clone(
        id    => 'max_index',
        arity => 'unary',
        first => $node->first,
    );

    return (
        $self->compile_ast($max_index),
        $self->opcode('move_to_sb'),
        $self->opcode('literal', 1),
        $self->opcode('add'),
    );
}

sub _generate_run_code {
    my $self = shift;
    my ($node) = @_;

    my $to_render = $node->clone(arity => 'call');

    if ($node->third) {
        my ($open_tag, $close_tag) = @{ $node->third };
        $to_render = $self->make_ternary(
            $self->parser->symbol('==')->clone(
                arity  => 'binary',
                first  => $close_tag->clone,
                second => $self->literal('}}'),
            ),
            $to_render,
            $self->join('{{= ', $open_tag, ' ', $close_tag, ' =}}', $to_render)
        );
    }

    # XXX turn this into an opcode
    my $render_string = $self->call(
        $node,
        '(render_string)',
        $to_render,
        $self->vars,
    );

    return $self->compile_ast($render_string);
}

sub join {
    my $self = shift;
    my (@args) = @_;

    @args = map { $self->literalize($_) } @args;

    my $joined = shift @args;
    for my $arg (@args) {
        $joined = $self->parser->symbol('~')->clone(
            arity  => 'binary',
            first  => $joined,
            second => $arg,
        );
    }

    return $joined;
}

sub literalize {
    my $self = shift;
    my ($val) = @_;

    return $val->clone if blessed($val);
    return $self->literal($val);
}

sub call {
    my $self = shift;
    my ($node, $name, @args) = @_;

    my $code = $self->parser->symbol('(name)')->clone(
        arity => 'name',
        id    => $name,
        line  => $node->line,
    );

    return $self->parser->call($code, @args);
}

sub make_ternary {
    my $self = shift;
    my ($if, $then, $else) = @_;
    return $self->parser->symbol('?:')->clone(
        arity  => 'if',
        first  => $if,
        second => $then,
        third  => $else,
    );
}

sub vars {
    my $self = shift;
    return $self->parser->symbol('(vars)')->clone(arity => 'vars');
}

sub check_lambda {
    my $self = shift;
    my ($var) = @_;

    return $self->make_ternary(
        $self->is_code_ref($var->clone),
        $self->run_code($var->clone),
        $var,
    );
}

sub is_code_ref {
    my $self = shift;
    my ($var) = @_;

    return $self->parser->symbol('(is_code_ref)')->clone(
        id    => 'is_code_ref',
        arity => 'unary',
        first => $var,
    );
}

sub run_code {
    my $self = shift;
    my ($code, $raw_text, $open_tag, $close_tag) = @_;

    return $self->parser->symbol('(run_code)')->clone(
        arity  => 'run_code',
        first  => $code,
        (@_ > 1
            ? (second => [ $raw_text ], third => [ $open_tag, $close_tag ])
            : (second => [])),
    );
}

__PACKAGE__->meta->make_immutable;
no Mouse;

__PACKAGE__->meta->make_immutable;
