# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# SectionCode is a code chunk taken verbatim from the annotated patch.
package Kgps::SectionCode;

use parent qw(Kgps::CodeBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $section) = @_;
  my $class = (ref ($type) or $type or 'Kgps::SectionCode');
  my $self = $class->SUPER::new ();

  $self->{'section'} = $section;
  $self = bless ($self, $class);

  return $self;
}

sub get_section
{
  my ($self) = @_;

  return $self->{'section'};
}

1;
