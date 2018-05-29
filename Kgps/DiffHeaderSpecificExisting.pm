# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderSpecificExisting;

use parent qw(Kgps::DiffHeaderSpecificBase);
use strict;
use v5.16;
use warnings;

use Kgps::DiffHeaderAllowedCustomizationsExisting;
use Kgps::DiffHeaderPartContents;
use Kgps::DiffHeaderPartContentsMode;
use Kgps::DiffHeaderPartRename;
use Kgps::ListingAuxChangesDetailsMode;
use Kgps::ListingAuxChangesDetailsModeRename;
use Kgps::ListingAuxChangesDetailsRename;

sub new
{
  my ($type, $part_mode, $part_rename, $part_contents) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderSpecificExisting');
  my $self = $class->SUPER::new ();

  $self->{'part_mode'} = $part_mode;
  $self->{'part_rename'} = $part_rename;
  $self->{'part_contents'} = $part_contents;
  $self = bless ($self, $class);

  return $self;
}

sub get_part_mode
{
  my ($self) = @_;

  return $self->{'part_mode'};
}

sub set_part_mode
{
  my ($self, $part) = @_;

  $self->{'part_mode'} = $part;
}

sub get_part_rename
{
  my ($self) = @_;

  return $self->{'part_rename'};
}

sub set_part_rename
{
  my ($self, $part) = @_;

  $self->{'part_rename'} = $part;
}

sub get_part_contents
{
  my ($self) = @_;

  return $self->{'part_contents'};
}

sub set_part_contents
{
  my ($self, $part) = @_;

  $self->{'part_contents'} = $part;
}

sub _get_text_from_vfunc
{
  my ($self, $diff_common) = @_;

  return $diff_common->get_a ();
}

sub _get_text_to_vfunc
{
  my ($self, $diff_common) = @_;

  return $diff_common->get_b ();
}

sub _has_index_vfunc
{
  my ($self) = @_;

  return defined ($self->get_part_contents ());
}

sub _with_index_vfunc
{
  my ($self) = @_;
  my $part_mode = $self->get_part_mode ();
  my $part_rename = $self->get_part_rename ();
  my $part_contents = $self->get_part_contents ();

  unless (defined ($part_contents))
  {
    if (defined ($part_mode))
    {
      $part_contents = Kgps::DiffHeaderPartContents->new ('1' x 7, '2' x 7);
    }
    else
    {
      my $mode = $part_contents->get_mode ();

      $part_contents = Kgps::DiffHeaderPartContentsMode->new ('1' x 7, '2' x 7, $mode);
    }
  }

  return Kgps::DiffHeaderSpecificExisting->new ($part_mode, $part_rename, $part_contents);
}

sub _without_index_vfunc
{
  my ($self) = @_;
  my $part_mode = $self->get_part_mode ();
  my $part_rename = $self->get_part_rename ();

  return Kgps::DiffHeaderSpecificExisting->new ($part_mode, $part_rename, undef);
}

sub _to_lines_vfunc
{
  my ($self) = @_;
  my @lines = ();
  my $part_mode = $self->get_part_mode ();
  my $part_rename = $self->get_part_rename ();
  my $part_contents = $self->get_part_contents ();

  if (defined ($part_mode))
  {
    push (@lines, $part_mode->to_lines ());
  }
  if (defined ($part_rename))
  {
    push (@lines, $part_rename->to_lines ());
  }
  if (defined ($part_contents))
  {
    push (@lines, $part_contents->to_lines ());
  }

  return @lines;
}

sub _fill_aux_changes_vfunc
{
  my ($self, $common, $listing_aux_changes) = @_;
  my $part_mode = $self->get_part_mode ();
  my $part_rename = $self->get_part_rename ();

  if (defined ($part_mode) and defined ($part_rename))
  {
    my $old_mode = $part_mode->get_old_mode ();
    my $new_mode = $part_mode->get_new_mode ();
    my $old_path = $part_rename->get_from ();;
    my $new_path = $part_rename->get_to ();
    my $similarity_index = $part_rename->get_similarity_index ();
    my $details = Kgps::ListingAuxChangesDetailsModeRename->new ($old_path, $new_path, $similarity_index, $old_mode, $new_mode);

    $listing_aux_changes->add_details ($details);
  }
  elsif (defined ($part_rename))
  {
    my $old_path = $part_rename->get_from ();;
    my $new_path = $part_rename->get_to ();
    my $similarity_index = $part_rename->get_similarity_index ();
    my $details = Kgps::ListingAuxChangesDetailsRename->new ($old_path, $new_path, $similarity_index);

    $listing_aux_changes->add_details ($details);
  }
  elsif (defined ($part_mode))
  {
    my $old_mode = $part_mode->get_old_mode ();
    my $new_mode = $part_mode->get_new_mode ();
    my $path = $common->get_b_no_prefix ();
    my $details = Kgps::ListingAuxChangesDetailsMode->new ($old_mode, $new_mode, $path);

    $listing_aux_changes->add_details ($details);
  }
}

sub _get_allowed_customizations_vfunc
{
  return Kgps::DiffHeaderAllowedCustomizationsExisting->new ();
}

sub _get_pre_file_state_vfunc
{
  my ($self, $builder, $common) = @_;
  my $mode = $self->_get_old_mode ();
  my $path = $common->get_a_no_prefix ();

  return $builder->build_existing_file_state ($mode, $path);
}

sub _get_post_file_state_vfunc
{
  my ($self, $builder, $common) = @_;
  my $mode = $self->_get_mode ();
  my $path = $common->get_b_no_prefix ();

  return $builder->build_existing_file_state ($mode, $path);
}

sub _get_initial_section_ranges_vfunc
{
  my ($self, $sections_array, $border_section) = @_;
  my $first_section = $sections_array->[0];
  my $last_section = $sections_array->[-1];

  return [$first_section, $last_section];
}

sub _pick_default_section_vfunc
{
  my ($self, $sections_array) = @_;

  return $sections_array->[0]->get_neighbour_if_special ();
}

sub _with_bogus_values_vfunc
{
  my ($self) = @_;
  my $part_contents = $self->get_part_contents ();
  my $part_mode = $self->get_part_mode ();
  my $part_rename = $self->get_part_rename ();
  my $bogus_part_contents = undef;
  my $bogus_part_rename = undef;

  if (defined ($part_contents))
  {
    if (defined ($part_mode))
    {
      $bogus_part_contents = Kgps::DiffHeaderPartContents->new ('1' x 7, '2' x 7);
    }
    else
    {
      $bogus_part_contents = Kgps::DiffHeaderPartContentsMode->new ('1' x 7, '2' x 7, $part_contents->get_mode ());
    }
  }
  if (defined ($part_rename))
  {
    $bogus_part_rename = Kgps::DiffHeaderPartRename->new (42, $part_rename->get_from (), $part_rename->get_to ());
  }

  return Kgps::DiffHeaderSpecificExisting->new ($part_mode, $bogus_part_rename, $bogus_part_contents);
}

sub _get_old_mode
{
  my ($self) = @_;
  my $part_mode = $self->get_part_mode ();
  my $part_contents = $self->get_part_contents ();

  if (defined ($part_mode))
  {
    return $part_mode->get_old_mode();
  }

  return $part_contents->get_mode ();
}

sub _get_mode
{
  my ($self) = @_;
  my $part_mode = $self->get_part_mode ();
  my $part_contents = $self->get_part_contents ();

  if (defined ($part_mode))
  {
    return $part_mode->get_new_mode();
  }

  return $part_contents->get_mode ();
}

1;
