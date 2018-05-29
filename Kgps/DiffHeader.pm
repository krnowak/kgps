# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# DiffHeader is a representation of lines that come before the
# description of actual changes in the file. These are lines that look
# like:
#
# diff --git a/.bzrignore.moved b/.bzrignore.moved
# new file mode 100644
# index 0000000..f852cf1
package Kgps::DiffHeader;

use strict;
use v5.16;
use warnings;

use Kgps::ListingInfo;

sub new_strict
{
  my ($type, $diff_common, $diff_specific) = @_;

  return _new_full ($type, $diff_common, $diff_specific, 1);
}

sub new_relaxed
{
  my ($type, $diff_common, $diff_specific) = @_;

  return _new_full ($type, $diff_common, $diff_specific, 0);
}

sub get_text_from
{
  my ($self) = @_;
  my $diff_common = $self->get_diff_common ();
  my $diff_specific = $self->_get_diff_specific ();

  return $diff_specific->get_text_from ($diff_common);
}

sub get_text_to
{
  my ($self) = @_;
  my $diff_common = $self->get_diff_common ();
  my $diff_specific = $self->_get_diff_specific ();

  return $diff_specific->get_text_to ($diff_common);
}

sub to_lines
{
  my ($self) = @_;
  my $diff_common = $self->get_diff_common ();
  my $diff_specific = $self->_get_diff_specific ();
  my @lines = ();

  push (@lines,
        $diff_common->to_lines (),
        $diff_specific->to_lines ());

  return @lines;
}

sub get_basename_stat_path
{
  my ($self) = @_;
  my $common = $self->get_diff_common ();
  my $a = $common->get_a_no_prefix ();
  my $b = $common->get_b_no_prefix ();

  if ($a eq $b)
  {
    return $a;
  }
  else
  {
    return "$a => $b";
  }
}

sub get_stats
{
  my ($self, $file_stat) = @_;
  my $listing_info = Kgps::ListingInfo->new ();
  my $per_basename_stats = $listing_info->get_per_basename_stats ();
  my $summary = $listing_info->get_summary ();
  my $listing_aux_changes = $listing_info->get_aux_changes ();
  my $common = $self->get_diff_common ();
  my $specific = $self->_get_diff_specific ();

  $per_basename_stats->add_stat ($file_stat);
  $file_stat->fill_summary ($summary);
  $specific->fill_aux_changes ($common, $listing_aux_changes);

  return $listing_info;
}

sub get_allowed_customizations
{
  my ($self) = @_;
  my $specific = $self->_get_diff_specific ();

  return $specific->get_allowed_customizations ();
}

sub get_pre_file_state
{
  my ($self, $builder) = @_;
  my $common = $self->get_diff_common ();
  my $specific = $self->_get_diff_specific ();

  return $specific->get_pre_file_state ($builder, $common);
}

sub get_post_file_state
{
  my ($self, $builder) = @_;
  my $common = $self->get_diff_common ();
  my $specific = $self->_get_diff_specific ();

  return $specific->get_post_file_state ($builder, $common);
}

sub get_initial_section_ranges
{
  my ($self, $sections_array, $border_section_or_undef) = @_;
  my $specific = $self->_get_diff_specific ();

  return $specific->get_initial_section_ranges ($sections_array, $border_section_or_undef);
}

sub pick_default_section
{
  my ($self, $sections_array) = @_;
  my $specific = $self->_get_diff_specific ();

  return $specific->pick_default_section ($sections_array);
}

sub without_index
{
  my ($self) = @_;
  my $specific = $self->_get_diff_specific ();

  unless ($specific->has_index ())
  {
    return $self;
  }
  if ($self->_get_strict ())
  {
    die 'changes are required';
  }

  my $specific_without_index = $specific->without_index ();
  my $common = $self->get_diff_common ();

  return Kgps::DiffHeader->new_strict ($common, $specific_without_index);
}

sub with_index
{
  my ($self) = @_;
  my $specific = $self->_get_diff_specific ();

  if ($specific->has_index ())
  {
    return $self;
  }

  if ($self->_get_strict ())
  {
    die 'changes are forbidden';
  }

  my $specific_with_index = $specific->with_index ();
  my $common = $self->get_diff_common ();

  return Kgps::DiffHeader->new_strict ($common, $specific_with_index);
}

sub with_bogus_values
{
  my ($self) = @_;
  my $common = $self->get_diff_common ();
  my $specific = $self->_get_diff_specific ();
  my $bogus_specific = $specific->with_bogus_values ();

  if ($self->_get_strict ())
  {
    return Kgps::DiffHeader->new_strict ($common, $bogus_specific);
  }
  else
  {
    return Kgps::DiffHeader->new_relaxed ($common, $bogus_specific);
  }
}

sub get_diff_common
{
  my ($self) = @_;

  return $self->{'diff_common'};
}

sub _get_diff_specific
{
  my ($self) = @_;

  return $self->{'diff_specific'};
}

sub _new_full
{
  my ($type, $diff_common, $diff_specific, $strict) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeader');
  my $self =
  {
    'diff_common' => $diff_common,
    'diff_specific' => $diff_specific,
    'strict' => $strict,
  };

  $self = bless ($self, $class);

  return $self;
}

sub _get_strict
{
  my ($self) = @_;

  return $self->{'strict'};
}

1;
