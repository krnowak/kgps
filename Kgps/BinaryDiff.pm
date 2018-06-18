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
use Kgps::ListingInfo;

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
}

sub _postprocess_vfunc
{
  my ($self, $sections_array, $sections_hash) = @_;
  my $code = $self->get_code ();
  my $name = $code->get_section ()->get_name ();
  my $raw = join ("\n",
                  $self->_get_diff_git_header (),
                  "GIT binary patch",
                  @{$self->_get_raw_lines ($code->get_lines ())},
                  "");
  my $raw_diff = {$name => $raw};
  my $big_listing_info = $self->get_listing_info ();
  my $big_new_and_gone_files = $big_listing_info->new_and_gone_files ();
  my $big_per_basename_stats = $big_listing_info->get_per_basename_stats ();
  my $listing_info = Kgps::ListingInfo->new ();
  my $per_basename_stats = $listing_info->get_per_basename_stats ();
  my $summary = $listing_info->get_summary ();
  my $new_and_gone_files = $listing_info->new_and_gone_files ();
  my $header = $self->get_header ();
  my $path = $header->get_a ();
  my $details_from_big = $big_new_and_gone_files->get_details_for_path ($path);
  my $basename = (File::Spec->splitpath ($path))[2];
  my $maybe_relevant = undef;

  for my $bin_stat (@{$big_per_basename_stats->get_bin_stats_for_basename ($basename)})
  {
    my $relevancy = $bin_stat->is_relevant_for_path ($path);

    if ($relevancy == Kgps::FileStatBase::RelevantYes)
    {
      $per_basename_stats->add_stat ($bin_stat);
      $maybe_relevant = undef;
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
      }
      else
      {
        $maybe_relevant = Kgps::BinaryFileStat->new ($path, $bin_stat->get_from_size, $bin_stat->get_to_size ());
      }
    }
  }
  if (defined ($maybe_relevant))
  {
    $per_basename_stats->add_stat ($maybe_relevant);
  }

  $summary->set_files_changed_count (1);
  if (defined ($details_from_big))
  {
    $new_and_gone_files->add_details ($path, $details_from_big);
  }

  my $stats = {$name => $listing_info};
  my $raw_diffs_and_modes = {
    'git-raw' => $raw_diff,
    'stats' => $stats,
  };

  return $raw_diffs_and_modes;
}

sub _get_diff_git_header
{
  my ($self) = @_;
  my $header = $self->get_header ();
  my $a = 'a/' . $header->get_a ();
  my $b = 'b/' . $header->get_b ();
  my $action = $header->get_action ();
  my $mode = $header->get_mode ();
  my $index_from = $header->get_index_from ();
  my $index_to = $header->get_index_to ();

  if (defined ($action))
  {
    return join ("\n",
                 "diff --git $a $b",
                 "$action mode $mode",
                 "index $index_from..$index_to");
  }
  return join ("\n",
               "diff --git $a $b",
               "index $index_from..$index_to $mode");
}

sub _get_raw_lines
{
  my ($self, $lines) = @_;
  my @raw_lines = map { $_->get_line () } @{$lines};

  return \@raw_lines;
}

1;
