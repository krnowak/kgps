# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::TextFileStatSignsBase;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::TextFileStatSignsBase');
  my $self = {};

  $self = bless ($self, $class);

  return $self;
}

sub fill_context_info
{
  my ($self, $stat_render_context) = @_;

  $self->_fill_context_info_vfunc ($stat_render_context);
}

sub to_string
{
  my ($self, $stat_render_context) = @_;

  return $self->_to_string_vfunc ($stat_render_context);
}

1;
