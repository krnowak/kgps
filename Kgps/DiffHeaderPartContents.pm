# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderPartContents;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $from_hash, $to_hash) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderPartContents');
  my $self =
  {
    'from_hash' => $from_hash,
    'to_hash' => $to_hash,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_from_hash
{
  my ($self) = @_;

  return $self->{'from_hash'};
}

sub set_from_hash
{
  my ($self, $hash) = @_;

  $self->{'from_hash'} = $hash;
}

sub get_to_hash
{
  my ($self) = @_;

  return $self->{'to_hash'};
}

sub set_to_hash
{
  my ($self, $hash) = @_;

  $self->{'to_hash'} = $hash;
}

sub to_lines
{
  my ($self) = @_;
  my @lines = ();
  my $index_from = $self->get_from_hash ();
  my $index_to = $self->get_to_hash ();

  push (@lines,
        "index $index_from..$index_to");

  return @lines;
}

1;
