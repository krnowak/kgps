# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# CodeBase is a single chunk of changed code.
package Kgps::CodeBase;

use strict;
use v5.16;
use warnings;

use Kgps::CodeLine;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::CodeBase');
  my $self =
  {
    'lines' => [],
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_lines
{
  my ($self) = @_;

  return $self->{'lines'};
}

sub push_line
{
  my ($self, $sigil, $code_line) = @_;
  my $lines = $self->get_lines ();
  my $line = Kgps::CodeLine->new ($sigil, $code_line);

  push (@{$lines}, $line);
}

1;
