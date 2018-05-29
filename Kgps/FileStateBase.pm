# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::FileStateBase;

use strict;
use v5.16;
use warnings;

use Scalar::Util;

sub new
{
  my ($type, $builder) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStateBase');
  my $self =
  {
    'builder' => $builder,
  };

  $self = bless ($self, $class);

  return $self;
}

sub apply_create_customization
{
  my ($self, $customization, $fresh_start) = @_;

  return $self->_apply_create_customization_vfunc ($customization, $fresh_start);
}

sub apply_delete_customization
{
  my ($self, $customization, $fresh_start) = @_;

  return $self->_apply_delete_customization_vfunc ($customization, $fresh_start);
}

sub apply_mode_customization
{
  my ($self, $customization, $fresh_start) = @_;

  return $self->_apply_mode_customization_vfunc ($customization, $fresh_start);
}

sub apply_rename_customization
{
  my ($self, $customization, $fresh_start) = @_;

  return $self->_apply_rename_customization_vfunc ($customization, $fresh_start);
}

sub apply_index_customization
{
  my ($self, $customization, $fresh_start) = @_;

  return $self->_apply_index_customization_vfunc ($customization, $fresh_start);
}

sub get_builder
{
  my ($self) = @_;

  return $self->{'builder'};
}

sub is_same
{
  my ($self, $other) = @_;
  my $self_type = Scalar::Util::blessed ($self);
  my $other_type = Scalar::Util::blessed ($other);

  if (defined ($self_type) and defined ($other_type) and $self_type eq $other_type)
  {
    return $self->_is_same_vfunc ($other);
  }

  return 0;
}

sub generate_diff_header
{
  my ($self, $previous_file_state) = @_;
  my $previous_file_state_wrapper = $previous_file_state->get_wrapper ();

  return $self->_generate_diff_header_vfunc ($previous_file_state_wrapper);
}

sub get_wrapper
{
  my ($self) = @_;

  return $self->_get_wrapper_vfunc ();
}

1;
