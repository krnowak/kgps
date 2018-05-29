# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderAllowedCustomizationsCreated;

use parent qw(Kgps::DiffHeaderAllowedCustomizationsBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderAllowedCustomizationsCreated');
  my $self = $class->SUPER::new ();

  $self = bless ($self, $class);

  return $self;
}

sub _is_create_allowed_vfunc
{
  return 1;
}

sub _is_delete_allowed_vfunc
{
  return 1;
}

sub _is_rename_allowed_vfunc
{
  return 1;
}

sub _is_mode_allowed_vfunc
{
  return 1;
}

sub _is_index_allowed_vfunc
{
  return 1;
}

1;
