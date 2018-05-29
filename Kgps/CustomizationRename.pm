# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::CustomizationRename;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $old_path, $new_path) = @_;
  my $class = (ref ($type) or $type or 'Kgps::CustomizationRename');
  my $self =
  {
    'old_path' => $old_path,
    'new_path' => $new_path,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_old_path
{
  my ($self) = @_;

  return $self->{'old_path'};
}

sub get_new_path
{
  my ($self) = @_;

  return $self->{'new_path'};
}

1;
