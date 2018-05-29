# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::ListingAuxChangesDetailsCreate;

use parent qw(Kgps::ListingAuxChangesDetailsBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $mode, $path) = @_;
  my $class = (ref ($type) or $type or 'Kgps::ListingAuxChangesDetailsCreate');
  my $self = $class->SUPER::new ($path);

  $self->{'mode'} = $mode;
  $self = bless ($self, $class);

  return $self;
}

sub _to_lines_vfunc
{
  my ($self) = @_;
  my $path = $self->get_path ();
  my $mode = $self->_get_mode ();
  my @lines = ();

  push (@lines,
        " create mode $mode $path");

  return @lines;
}

sub _get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

1;
