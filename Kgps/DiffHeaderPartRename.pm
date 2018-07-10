# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderPartRename;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $similarity_index, $from, $to) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderPartRename');
  my $self =
  {
    'similarity_index' => $similarity_index,
    'from' => $from,
    'to' => $to,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_similarity_index
{
  my ($self) = @_;

  return $self->{'similarity_index'};
}

sub set_similarity_index
{
  my ($self, $index) = @_;

  $self->{'similarity_index'} = $index;

  return;
}

sub get_from
{
  my ($self) = @_;

  return $self->{'from'};
}

sub set_from
{
  my ($self, $from) = @_;

  $self->{'from'} = $from;

  return;
}

sub get_to
{
  my ($self) = @_;

  return $self->{'to'};
}

sub set_to
{
  my ($self, $to) = @_;

  $self->{'to'} = $to;

  return;
}

sub to_lines
{
  my ($self) = @_;
  my @lines = ();
  my $similarity_index = $self->get_similarity_index ();
  my $from = $self->get_from ();
  my $to = $self->get_to ();

  push (@lines,
        "similarity index $similarity_index%",
        "rename from $from",
        "rename to $to");

  return @lines;
}

1;
