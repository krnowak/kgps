# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::OverlapInfo;

use strict;
use v5.16;
use warnings;

use Scalar::Util;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::OverlapInfo');
  my $self = {
    'codes' => []
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_section_overlapped_codes
{
  my ($self) = @_;

  return $self->{'codes'};
}

sub push_section_overlapped_code
{
  my ($self, $section_overlapped_code) = @_;
  my $codes = $self->get_section_overlapped_codes ();

  push (@{$codes}, $section_overlapped_code);
  Scalar::Util::weaken ($codes->[-1]);
}

1;
