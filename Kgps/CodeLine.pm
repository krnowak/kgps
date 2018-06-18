# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# CodeLine is a representation of a single line of code in diff. It's
# the line in diff that starts with a single sigil (either +, - or
# space) and the rest of the line is the actual code.
package Kgps::CodeLine;

use strict;
use v5.16;
use warnings;

use constant
{
  Plus => 0, # added line
  Minus => 1, # removed line
  Space => 2, # unchanged line
  Binary => 3,  # binary line
};

my $type_to_char =
{
  Plus () => '+',
  Minus () => '-',
  Space () => ' ',
};
my $char_to_type =
{
  '+' => Plus,
  '-' => Minus,
  ' ' => Space,
};

sub get_char
{
  my ($type) = @_;

  if (exists ($type_to_char->{$type}))
  {
    return $type_to_char->{$type};
  }

  return undef;
}

sub get_type
{
  my ($char) = @_;

  if (exists ($char_to_type->{$char}))
  {
    return $char_to_type->{$char};
  }

  return undef;
}

sub new
{
  my ($type, $sigil, $line) = @_;
  my $class = (ref ($type) or $type or 'Kgps::CodeLine');
  my $self =
  {
    'sigil' => $sigil,
    'line' => $line,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_sigil
{
  my ($self) = @_;

  return $self->{'sigil'};
}

sub get_line
{
  my ($self) = @_;

  return $self->{'line'};
}

1;
