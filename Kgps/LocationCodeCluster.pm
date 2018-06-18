# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# LocationCodeCluster is a single code chunk that is being split
# between multiple sections.
package Kgps::LocationCodeCluster;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $marker) = @_;
  my $class = (ref ($type) or $type or 'Kgps::LocationCodeCluster');
  my $self =
  {
    'marker' => $marker,
    'section_codes' => [],
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_section_codes
{
  my ($self) = @_;

  return $self->{'section_codes'};
}

sub push_section_code
{
  my ($self, $new_code) = @_;
  my $codes = $self->get_section_codes ();

  push (@{$codes}, $new_code);
}

sub get_marker
{
  my ($self) = @_;

  return $self->{'marker'};
}

1;
