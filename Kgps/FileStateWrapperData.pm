# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::FileStateWrapperData;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $path, $mode, $modified) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStateWrapperData');
  my $self =
  {
    'path' => $path,
    'mode' => $mode,
    'modified' => $modified,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_path
{
  my ($self) = @_;

  return $self->{'path'}
}

sub get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

sub is_modified
{
  my ($self) = @_;

  return $self->{'modified'};
}

1;
