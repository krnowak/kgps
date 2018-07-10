# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# BinaryDiff is a representation of a diff of a binary file.
package Kgps::BinaryDiff;

use parent qw(Kgps::DiffBase);
use strict;
use v5.16;
use warnings;

use File::Spec;

use Kgps::BinaryFileStat;
use Kgps::FileStatBase;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::BinaryDiff');
  my $self = $class->SUPER::new ();

  $self->{'code'} = undef;
  $self->{'listing_info'} = undef;
  $self = bless ($self, $class);

  return $self;
}

sub get_code
{
  my ($self) = @_;

  return $self->{'code'};
}

sub set_code
{
  my ($self, $code) = @_;

  $self->{'code'} = $code;

  return;
}

sub get_listing_info
{
  my ($self) = @_;

  return $self->{'listing_info'};
}

sub set_listing_info
{
  my ($self, $listing_info) = @_;

  $self->{'listing_info'} = $listing_info;

  return;
}

sub _postprocess_vfunc
{
  my ($self, $sections_array, $sections_hash, $headers_for_sections) = @_;
  my $code = $self->get_code ();
  my $name = $code->get_section ()->get_name ();
  my $header = $self->get_header ();
  my $raw = join ("\n",
                  $self->_get_diff_git_header ($header),
                  "GIT binary patch",
                  @{$self->_get_raw_lines ($code->get_lines ())},
                  "");
  my $raw_diff = {$name => $raw};
  my $big_listing_info = $self->get_listing_info ();
  my $big_per_basename_stats = $big_listing_info->get_per_basename_stats ();
  my $path = $header->get_basename_stat_path ();
  my $basename = (File::Spec->splitpath ($path))[2];
  my $maybe_relevant = undef;

  for my $bin_stat (@{$big_per_basename_stats->get_bin_stats_for_basename ($basename)})
  {
    my $relevancy = $bin_stat->is_relevant_for_path ($path);

    if ($relevancy == Kgps::FileStatBase::RelevantYes)
    {
      $maybe_relevant = Kgps::BinaryFileStat->new ($bin_stat->get_path (), $bin_stat->get_from_size (), $bin_stat->get_to_size ());
      last;
    }
    if ($relevancy == Kgps::FileStatBase::RelevantMaybe)
    {
      if (defined ($maybe_relevant))
      {
        # Meh, warn about ambiguity in overlong paths, maybe consider
        # adding a helper to GIT binary patch section.
        #
        # Try more heuristics with checking if the file is created or
        # deleted. Created files usually have from size 0, and deleted
        # files have to size 0.
        # TODO: Do something else.
        $maybe_relevant = Kgps::BinaryFileStat->new ($path, -1, -1);
      }
      else
      {
        $maybe_relevant = Kgps::BinaryFileStat->new ($path, $bin_stat->get_from_size, $bin_stat->get_to_size ());
      }
    }
  }

  my $listing_info = $header->get_stats ($maybe_relevant);
  my $stats = {$name => $listing_info};
  my $raw_diffs_and_modes = {
    'git-raw' => $raw_diff,
    'stats' => $stats,
  };

  return $raw_diffs_and_modes;
}

sub _get_diff_git_header
{
  my ($self, $header) = @_;

  return join ("\n",
               $header->to_lines ());
}

sub _get_raw_lines
{
  my ($self, $lines) = @_;
  my @raw_lines = map { $_->get_line () } @{$lines};

  return \@raw_lines;
}

1;
