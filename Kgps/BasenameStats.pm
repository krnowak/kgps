#!/usr/bin/perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# BasenameStats contains information about modifications of all file
# with certain basename. So for changes like:
#
# foo/file | 26 +
# bar/file | Bin 64 -> 0 bytes
# bar/aaaa | 2  +-
#
# one BasenameStats instance will contain information about foo/file
# and bar/file, and another instance - about bar/aaaa.
package Kgps::BasenameStats;

use strict;
use v5.16;
use warnings;

use File::Spec;

use Kgps::BinaryFileStat;
use Kgps::TextFileStat;
use Kgps::TextFileStatSignsDrawn;

sub new
{
  my ($type) = @_;

  return _new_with_stats ($type, {});
}

sub get_bin_stats_for_basename
{
  my ($self, $basename) = @_;
  my $stats = $self->_get_stats ();
  my $bin_stats = [];

  if (exists ($stats->{$basename}))
  {
    for my $stat (@{$stats->{$basename}})
    {
      # bleh
      if ($stat->isa ('Kgps::BinaryFileStat'))
      {
        push (@{$bin_stats}, $stat);
      }
    }
  }

  return $bin_stats;
}

sub add_stat
{
  my ($self, $stat) = @_;
  my $stats = $self->_get_stats ();
  my $path = $stat->get_path ();
  my $basename = (File::Spec->splitpath ($path))[2];

  unless (exists ($stats->{$basename}))
  {
    $stats->{$basename} = [];
  }

  push (@{$stats->{$basename}}, $stat);

  return;
}

sub add_file_stats
{
  my ($self, $path, $stats_line) = @_;
  my $stat = undef;

  if ($stats_line =~ /^\s*(\d+) (\+*)(-*)$/a)
  {
    my $plus_count = 0;
    my $minus_count = 0;

    if (defined ($2))
    {
      $plus_count = length ($2);
    }
    if (defined ($3))
    {
      $minus_count = length ($3);
    }

    my $signs = Kgps::TextFileStatSignsDrawn->new ($1, $plus_count, $minus_count);

    $stat = Kgps::TextFileStat->new ($path, $signs);
  }
  elsif ($stats_line =~ /^Bin (\d+) -> \d+ bytes?$/)
  {
    $stat = Kgps::BinaryFileStat->new ($path, $1, $2);
  }

  unless (defined ($stat))
  {
    return 0;
  }

  $self->add_stat ($stat);
  return 1;
}

sub merge
{
  my ($self, $other) = @_;
  my $self_stats = $self->_get_stats ();
  my $other_stats = $other->_get_stats ();
  my $merged_stats = {};

  for my $basename (keys (%{$self_stats}), keys (%{$other_stats}))
  {
    my $self_array = [];
    my $other_array = [];

    if (exists ($self_stats->{$basename}))
    {
      $self_array = $self_stats->{$basename};
    }
    if (exists ($other_stats->{$basename}))
    {
      $self_array = $other_stats->{$basename};
    }

    $merged_stats->{$basename} = [@{$self_array}, @{$other_array}];
  }

  return Kgps::BasenameStats->_new_with_stats ($merged_stats);
}

sub fill_context_info
{
  my ($self, $stat_render_context) = @_;

  for my $file_stats (values (%{$self->_get_stats ()}))
  {
    for my $file_stat (@{$file_stats})
    {
      $file_stat->fill_context_info ($stat_render_context);
    }
  }

  return;
}

sub to_lines
{
  my ($self, $stat_render_context) = @_;
  my %all_stats = ();

  for my $file_stats (values (%{$self->_get_stats ()}))
  {
    for my $file_stat (@{$file_stats})
    {
      $all_stats{$file_stat->get_path ()} = $file_stat;
    }
  }

  my @lines = ();
  for my $path (sort (keys (%all_stats)))
  {
    my $file_stat = $all_stats{$path};

    push (@lines, $stat_render_context->render_stat ($file_stat));
  }

  return @lines;
}

sub _get_stats
{
  my ($self) = @_;

  return $self->{'stats'};
}

sub _new_with_stats
{
  my ($type, $stats) = @_;
  my $class = (ref ($type) or $type or 'Kgps::BasenameStats');
  my $self = {
    # basename to array of FileStatBase
    'stats' => $stats,
  };

  $self = bless ($self, $class);

  return $self;
}

1;
