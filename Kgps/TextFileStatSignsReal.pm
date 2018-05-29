# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::TextFileStatSignsReal;

use parent qw(Kgps::TextFileStatSignsBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $insertions, $deletions) = @_;
  my $class = (ref ($type) or $type or 'Kgps::TextFileStatSignsReal');
  my $self = $class->SUPER::new ();

  $self->{'insertions'} = $insertions;
  $self->{'deletions'} = $deletions;
  $self = bless ($self, $class);

  return $self;
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $total = $self->_get_insertions () + $self->_get_deletions ();

  $stat_render_context->feed_lines_changed_count ($total);
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $insertions = $self->_get_insertions ();
  my $deletions = $self->_get_deletions ();
  my $total = $insertions + $deletions;

  return $stat_render_context->render_text_rest ($total, $insertions, $deletions);
}

sub _get_insertions_vfunc
{
  my ($self) = @_;

  return $self->_get_insertions ();
}

sub _get_deletions_vfunc
{
  my ($self) = @_;

  return $self->_get_deletions ();
}

sub _get_insertions
{
  my ($self) = @_;

  return $self->{'insertions'};
}

sub _get_deletions
{
  my ($self) = @_;

  return $self->{'deletions'};
}

1;
