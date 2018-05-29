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

# TODO: make a separate member for drawn signs and a separate one for
# real signs.
#
# TODO: fixup drawn signs into a real one when parsed the whole patch
#
# TODO: file stat base could be used to fill the listing summary then
sub new_with_real_signs
{
  my ($type, $path, $real_signs) = @_;

  return _new_full ($type, $path, $real_signs, undef);
}

sub new_with_drawn_signs
{
  my ($type, $path, $drawn_signs) = @_;

  return _new_full ($type, $path, undef, $drawn_signs);
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

sub _fill_summary_vfunc
{
  my ($self, $summary) = @_;
  my $signs = $self->_get_signs ();
  my $insertions = $signs->get_insertions ();
  my $deletions = $signs->get_deletions ();

  $summary->set_files_changed_count (1);
  $summary->set_insertions ($insertions);
  $summary->set_deletions ($deletions);
}

sub _get_signs
{
  my ($self) = @_;
  my $signs = $self->_get_real_signs ();

  unless (defined ($signs))
  {
    $signs = $self->{'drawn_signs'};
  }

  return $signs;
}

sub _get_real_signs
{
  my ($self) = @_;

  return $self->{'real_signs'};
}

sub _new_full
{
  my ($type, $path, $real_signs, $drawn_signs) = @_;
  my $class = (ref ($type) or $type or 'Kgps::TextFileStat');
  my $self = $class->SUPER::new ($path);

  $self->{'real_signs'} = $real_signs;
  $self->{'drawn_signs'} = $drawn_signs;
  $self = bless ($self, $class);

  return $self;
}

1;
