# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# FileStatBase contains information about single file modification. It
# is a base package for representation of a line like:
#
# foo/file | 26 +
#
# or
#
# bar/file | Bin 64 -> 0 bytes
package Kgps::FileStatBase;

use strict;
use v5.16;
use warnings;

use File::Spec;

use constant
{
  RelevantNo => 0,
  RelevantYes => 1,
  RelevantMaybe => 2,
};

sub new
{
  my ($type, $path) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStatBase');
  my $self = {
    'path' => $path,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_path
{
  my ($self) = @_;

  return $self->{'path'};
}

sub is_relevant_for_path
{
  my ($self, $full_path) = @_;
  my $path = $self->get_path ();

  if ($path eq $full_path)
  {
    return RelevantYes;
  }

  my (undef, $full_dir, $full_basename) = File::Spec->splitpath ($full_path);
  my (undef, $dir, $basename) = File::Spec->splitpath ($path);

  if ($basename ne $full_basename)
  {
    return RelevantNo;
  }

  my @full_dirs = reverse (File::Spec->splitdir ($full_dir));
  my @dirs = reverse (File::Spec->splitdir ($dir));
  my $last_idx = scalar (@full_dirs);
  if ($last_idx > scalar (@dirs))
  {
    $last_idx = scalar (@dirs);
  }
  # We want index of last item in the array so decrement by one. We
  # want to skip comparing last item in the array, because it may be
  # '...', so decrement by one again.
  $last_idx -= 2;

  for my $idx (0 .. $last_idx)
  {
    if ($full_dirs[$idx] ne $dirs[$idx])
    {
      return RelevantNo;
    }
  }
  if ($dirs[$last_idx + 1] eq '...')
  {
    return RelevantMaybe;
  }
  if (scalar (@dirs) != scalar (@full_dirs))
  {
    return RelevantNo;
  }
  if ($dirs[$last_idx + 1] ne $full_dirs[$last_idx + 1])
  {
    return RelevantNo;
  }

  return RelevantYes;
}

sub fill_context_info
{
  my ($self, $stat_render_context) = @_;

  $stat_render_context->feed_path_length (length ($self->get_path ()));
  $self->_fill_context_info_vfunc ($stat_render_context);

  return;
}

sub to_string
{
  my ($self, $stat_render_context) = @_;

  return $self->_to_string_vfunc ($stat_render_context);
}

sub fill_summary
{
  my ($self, $summary) = @_;

  $self->_fill_summary_vfunc ($summary);

  return;
}

1;
