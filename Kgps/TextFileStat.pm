# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# TextFileStat contains information stored in line like:
#
# foo/file | 26 +
package Kgps::TextFileStat;

use parent qw(Kgps::FileStatBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $path, $signs) = @_;
  my $class = (ref ($type) or $type or 'Kgps::TextFileStat');
  my $self = $class->SUPER::new ($path);

  $self->{'signs'} = $signs;
  $self = bless ($self, $class);

  return $self;
}

sub get_lines_changed_count
{
  my ($self) = @_;

  return $self->{'lines_changed_count'};
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $signs = $self->_get_signs ();

  $signs->fill_context_info ($stat_render_context);
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $signs = $self->_get_signs ();

  return $signs->to_string ($stat_render_context);
}

sub _get_signs
{
  my ($self) = @_;

  return $self->{'signs'};
}

1;
