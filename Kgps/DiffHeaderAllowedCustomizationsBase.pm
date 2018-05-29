# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderAllowedCustomizationsBase;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderAllowedCustomizationsBase');
  my $self =
  {
  };

  $self = bless ($self, $class);

  return $self;
}

sub is_create_allowed
{
  my ($self) = @_;

  return $self->_is_create_allowed_vfunc ();
}

sub is_delete_allowed
{
  my ($self) = @_;

  return $self->_is_delete_allowed_vfunc ();
}

sub is_rename_allowed
{
  my ($self) = @_;

  return $self->_is_rename_allowed_vfunc ();
}

sub is_mode_allowed
{
  my ($self) = @_;

  return $self->_is_mode_allowed_vfunc ();
}

sub is_index_allowed
{
  my ($self) = @_;

  return $self->_is_index_allowed_vfunc ();
}

1;
