# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderSpecificCreated;

use parent qw(Kgps::DiffHeaderSpecificBase);
use strict;
use v5.16;
use warnings;

use Kgps::DiffHeaderAllowedCustomizationsCreated;
use Kgps::DiffHeaderPartContents;
use Kgps::ListingAuxChangesDetailsCreate;

sub new
{
  my ($type, $mode, $part_contents) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderSpecificCreated');
  my $self = $class->SUPER::new ();

  $self->{'mode'} = $mode;
  $self->{'part_contents'} = $part_contents;
  $self = bless ($self, $class);

  return $self;
}

sub get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

sub set_mode
{
  my ($self, $mode) = @_;

  $self->{'mode'} = $mode;
}

sub get_part_contents
{
  my ($self) = @_;

  return $self->{'part_contents'};
}

sub set_part_contents
{
  my ($self, $part_contents) = @_;

  $self->{'part_contents'} = $part_contents;
}

sub _get_text_from_vfunc
{
  my ($self, $diff_common) = @_;

  return '/dev/null';
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

  # created specific already contains index, otherwise would be badly
  # formed
  return $self;
}

sub _without_index_vfunc
{
  my ($self) = @_;

  # created specific must contain index, otherwise it will be badly
  # formed
  return $self;
}

sub _to_lines_vfunc
{
  my ($self) = @_;
  my $mode = $self->get_mode ();
  my $part_contents = $self->get_part_contents ();
  my @lines = ();

  push (@lines,
        "new file mode $mode",
        $part_contents->to_lines ());

  return @lines;
}

sub _fill_aux_changes_vfunc
{
  my ($self, $common, $listing_aux_changes) = @_;
  my $mode = $self->get_mode ();
  my $details = Kgps::ListingAuxChangesDetailsCreate->new ($mode, $common->get_b_no_prefix ());

  $listing_aux_changes->add_details ($details);
}

sub _get_allowed_customizations_vfunc
{
  return Kgps::DiffHeaderAllowedCustomizationsCreated->new ();
}

sub _get_pre_file_state_vfunc
{
  my ($self, $builder, $common) = @_;

  return $builder->build_empty_file_state ();
}

sub _get_post_file_state_vfunc
{
  my ($self, $builder, $common) = @_;
  my $mode = $self->get_mode ();
  my $path = $common->get_b_no_prefix ();

  return $builder->build_existing_file_state ($mode, $path);
}

sub _get_initial_section_ranges_vfunc
{
  my ($self, $sections_array, $border_section) = @_;
  my $first_real_section = $border_section;
  my $last_section = $sections_array->[-1];

  return [$first_real_section, $last_section];
}

sub _pick_default_section_vfunc
{
  my ($self, $sections_array) = @_;

  return $sections_array->[0]->get_neighbour_if_special ();
}

sub _with_bogus_values_vfunc
{
  my ($self) = @_;
  my $bogus_part_contents = Kgps::DiffHeaderPartContents->new ('0' x 7, '2' x 7);
  my $mode = $self->get_mode ();

  return Kgps::DiffHeaderSpecificCreated->new ($mode, $bogus_part_contents);
}

1;