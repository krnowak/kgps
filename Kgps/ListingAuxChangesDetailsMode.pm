# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::ListingAuxChangesDetailsMode;

use parent qw(Kgps::ListingAuxChangesDetailsBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $old_mode, $new_mode, $path) = @_;
  my $class = (ref ($type) or $type or 'Kgps::ListingAuxChangesDetailsMode');
  my $self = $class->SUPER::new ($path);

  $self->{'old_mode'} = $old_mode;
  $self->{'new_mode'} = $new_mode;
  $self = bless ($self, $class);

  return $self;
}

sub _to_lines_vfunc
{
  my ($self) = @_;
  my $path = $self->get_path ();
  my $old_mode = $self->_get_old_mode ();
  my $new_mode = $self->_get_new_mode ();
  my @lines = ();

  push (@lines,
        " mode change $old_mode => $new_mode $path");

  return @lines;
}

sub _get_old_mode
{
  my ($self) = @_;

  return $self->{'old_mode'};
}

sub _get_new_mode
{
  my ($self) = @_;

  return $self->{'new_mode'};
}

1;
