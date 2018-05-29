# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# BinaryFileStat contains information stored in line like:
#
# bar/file | Bin 64 -> 0 bytes
package Kgps::BinaryFileStat;

use parent qw(Kgps::FileStatBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $path, $from_size, $to_size) = @_;
  my $class = (ref ($type) or $type or 'Kgps::BinaryFileStat');
  my $self = $class->SUPER::new ($path);

  $self->{'from_size'} = $from_size;
  $self->{'to_size'} = $to_size;
  $self = bless ($self, $class);

  return $self;
}

sub get_from_size
{
  my ($self) = @_;

  return $self->{'from_size'};
}

sub get_to_size
{
  my ($self) = @_;

  return $self->{'to_size'};
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $from_size = $self->get_from_size ();
  my $to_size = $self->get_to_size ();
  my $bytes_word = 'bytes';

  if ($to_size == 0)
  {
    chop ($bytes_word);
  }

  return "Bin $from_size -> $to_size $bytes_word";
}

sub _fill_summary_vfunc
{
  my ($self, $summary) = @_;

  $summary->set_files_changed_count (1);
}

1;
