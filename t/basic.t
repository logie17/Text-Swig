#! /usr/bin/env perl

use strict;
use warnings;
use Test::Most tests => 3;

my $class = 'Text::Swig';
use_ok $class;

my $template =<<TEMP1;
  Test1: {{data1}}
TEMP1

my $compiler;
lives_ok { $compiler = Text::Swig->new };

like $compiler->render_string($template, {data1 => 'foo'}), qr/Test1: foo/;
