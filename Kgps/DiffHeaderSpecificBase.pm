# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderSpecificBase;

use strict;
use v5.16;
use warnings;

use Kgps::SectionRanges;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderSpecificBase');
  my $self =
  {
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_text_from
{
  my ($self, $diff_common) = @_;

  return $self->_get_text_from_vfunc ($diff_common);
}

sub get_text_to
{
  my ($self, $diff_common) = @_;

  return $self->_get_text_to_vfunc ($diff_common);
}

sub has_index
{
  my ($self) = @_;

  return $self->_has_index_vfunc ();
}

sub with_index
{
  my ($self) = @_;

  return $self->_with_index_vfunc ();
}

sub without_index
{
  my ($self) = @_;

  return $self->_without_index_vfunc ();
}

sub to_lines
{
  my ($self) = @_;

  return $self->_to_lines_vfunc ();
}

sub fill_aux_changes
{
  my ($self, $common, $listing_aux_changes) = @_;

  $self->_fill_aux_changes_vfunc ($common, $listing_aux_changes);
}

sub get_allowed_customizations
{
  my ($self) = @_;

  return $self->_get_allowed_customizations_vfunc ();
}

sub get_pre_file_state
{
  my ($self, $builder, $common) = @_;

  return $self->_get_pre_file_state_vfunc ($builder, $common);
}

sub get_post_file_state
{
  my ($self, $builder, $common) = @_;

  return $self->_get_post_file_state_vfunc ($builder, $common);
}

sub get_initial_section_ranges
{
  my ($self, $sections_array, $border_section) = @_;
  my $range = $self->_get_initial_section_ranges_vfunc ($sections_array, $border_section);

  return Kgps::SectionRanges->new ($range->[0], $range->[1]);
}

sub pick_default_section
{
  my ($self, $sections_array) = @_;

  return $self->_pick_default_section_vfunc ($sections_array);
}

sub with_bogus_values
{
  my ($self) = @_;

  return $self->_with_bogus_values_vfunc ();
}

1;
