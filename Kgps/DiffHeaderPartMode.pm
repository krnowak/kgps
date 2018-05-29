# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderPartMode;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $old_mode, $new_mode) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderPartMode');
  my $self =
  {
    'old_mode' => $old_mode,
    'new_mode' => $new_mode,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_old_mode
{
  my ($self) = @_;

  return $self->{'old_mode'};
}

sub set_old_mode
{
  my ($self, $mode) = @_;

  $self->{'old_mode'} = $mode;
}

sub get_new_mode
{
  my ($self) = @_;

  return $self->{'new_mode'};
}

sub set_new_mode
{
  my ($self, $mode) = @_;

  $self->{'new_mode'} = $mode;
}

sub to_lines
{
  my ($self) = @_;
  my @lines = ();
  my $old_mode = $self->get_old_mode ();
  my $new_mode = $self->get_new_mode ();

  push (@lines,
        "old mode $old_mode",
        "new mode $new_mode");

  return @lines;
}

1;
