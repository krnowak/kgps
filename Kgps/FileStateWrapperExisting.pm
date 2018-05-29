# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::FileStateWrapperExisting;

use parent qw(Kgps::FileStateWrapperBase);
use strict;
use v5.16;
use warnings;

use Kgps::FileStateWrapperData;

sub new
{
  my ($type, $path, $mode) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStateWrapperExisting');
  my $self = $class->SUPER::new ();

  $self->{'path'} = $path;
  $self->{'mode'} = $mode;
  $self = bless ($self, $class);

  return $self;
}

sub _get_data_or_undef_vfunc
{
  my ($self) = @_;
  my $path = $self->_get_path ();
  my $mode = $self->_get_mode ();

  return Kgps::FileStateWrapperData->new ($path, $mode, 0);
}

sub _get_path
{
  my ($self) = @_;

  return $self->{'path'};
}

sub _get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

1;
