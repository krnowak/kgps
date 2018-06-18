# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# DiffBase is a base package for either textual or binary diffs.
package Kgps::DiffBase;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffBase');
  my $self =
  {
    'header' => undef,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_header
{
  my ($self) = @_;

  return $self->{'header'};
}

sub set_header
{
  my ($self, $header) = @_;

  $self->{'header'} = $header;
}

sub postprocess
{
  my ($self, $sections_array, $sections_hash) = @_;

  return $self->_postprocess_vfunc ($sections_array, $sections_hash);
}

1;
