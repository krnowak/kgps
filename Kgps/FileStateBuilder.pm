# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::FileStateBuilder;

use strict;
use v5.16;
use warnings;

use Kgps::FileStateEmpty;
use Kgps::FileStateExisting;
use Kgps::FileStateModified;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStateBuilder');
  my $self =
  {
  };

  $self = bless ($self, $class);

  return $self;
}

sub build_empty_file_state
{
  my ($self) = @_;

  return Kgps::FileStateEmpty->new ($self);
}

sub build_existing_file_state
{
  my ($self, $mode, $path) = @_;

  return Kgps::FileStateExisting->new ($self, $mode, $path);
}

sub build_modified_file_state
{
  my ($self, $mode, $path) = @_;

  return Kgps::FileStateModified->new ($self, $mode, $path);
}

1;
