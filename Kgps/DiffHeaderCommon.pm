# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderCommon;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $diff_a, $diff_b) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderCommon');
  my $self =
  {
    'diff_a' => $diff_a,
    'diff_b' => $diff_b,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_a
{
  my ($self) = @_;

  return 'a/' . $self->get_a_no_prefix ();
}

sub get_a_no_prefix
{
  my ($self) = @_;

  return $self->{'diff_a'};
}

sub set_a
{
  my ($self, $a) = @_;

  $self->{'diff_a'} = $a;

  return;
}

sub get_b
{
  my ($self) = @_;

  return 'b/' . $self->get_b_no_prefix ();
}

sub get_b_no_prefix
{
  my ($self) = @_;

  return $self->{'diff_b'};
}

sub set_b
{
  my ($self, $b) = @_;

  $self->{'diff_b'} = $b;

  return;
}

sub to_lines
{
  my ($self) = @_;
  my $diff_a = $self->get_a ();
  my $diff_b = $self->get_b ();
  my @lines = ();

  push (@lines,
        "diff --git $diff_a $diff_b");

  return @lines;
}

1;
