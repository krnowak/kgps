# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderPartContentsMode;

use parent qw(Kgps::DiffHeaderPartContents);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $from_hash, $to_hash, $mode) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderPartContentsMode');
  my $self = $class->SUPER::new ($from_hash, $to_hash);

  $self->{'mode'} = $mode;
  $self = bless ($self, $class);

  return $self;
}

sub get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

sub set_mode
{
  my ($self, $mode) = @_;

  $self->{'mode'} = $mode;

  return;
}

sub to_lines
{
  my ($self) = @_;
  my @lines = $self->SUPER::to_lines ();
  my $mode = $self->get_mode ();

  $lines[-1] .= " $mode";
  return @lines;
}

1;
