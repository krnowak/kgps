# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::FileStateWrapperBase;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStateWrapperBase');
  my $self =
  {
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_data_or_undef
{
  my ($self) = @_;

  return $self->_get_data_or_undef_vfunc ();
}

1;
