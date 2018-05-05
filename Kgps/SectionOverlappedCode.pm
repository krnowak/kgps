# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::SectionOverlappedCode;

use parent qw(Kgps::SectionCode);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $section, $overlap_info) = @_;
  my $class = (ref ($type) or $type or 'Kgps::SectionOverlappedCode');
  my $self = $class->SUPER::new ($section);

  $self->{'overlap_info'} = $overlap_info;
  $self = bless ($self, $class);

  $overlap_info->push_section_overlapped_code ($self);
  return $self;
}

sub get_overlap_info
{
  my ($self) = @_;

  return $self->{'overlap_info'};
}

1;
