# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::TextFileStatSignsDrawn;

use parent qw(Kgps::TextFileStatSignsBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $lines_changed_count, $plus_count, $minus_count) = @_;
  my $class = (ref ($type) or $type or 'Kgps::TextFileStatSignsDrawn');
  my $self = $class->SUPER::new ();

  $self->{'lines_changed_count'} = $lines_changed_count;
  $self->{'plus_count'} = $plus_count;
  $self->{'minus_count'} = $minus_count;
  $self = bless ($self, $class);

  return $self;
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $lines_changed_count = $self->_get_lines_changed_count ();

  $stat_render_context->feed_lines_changed_count ($lines_changed_count);
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;

  return '';
}

sub _get_lines_changed_count
{
  my ($self) = @_;

  return $self->{'lines_changed_count'};
}

1;
