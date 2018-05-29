# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::FileStateExisting;

use parent qw(Kgps::FileStateBase);
use strict;
use v5.16;
use warnings;

use Kgps::DiffHeader;
use Kgps::DiffHeaderCommon;
use Kgps::DiffHeaderPartMode;
use Kgps::DiffHeaderPartRename;
use Kgps::DiffHeaderSpecificExisting;
use Kgps::FileStateWrapperExisting;

sub new
{
  my ($type, $builder, $mode, $path) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStateExisting');
  my $self = $class->SUPER::new ($builder);

  $self->{'mode'} = $mode;
  $self->{'path'} = $path;

  $self = bless ($self, $class);

  return $self;
}

sub _apply_create_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;

  return undef;
}

sub _apply_delete_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;
  my $builder = $self->get_builder ();

  unless ($fresh_start)
  {
    die;
  }
  # TODO: checks
  return $builder->build_empty_file_state ();
}

sub _apply_mode_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;
  my $builder = $self->get_builder ();
  my $mode = $self->_get_mode ();
  my $path = $self->_get_path ();

  # TODO: checks
  return $builder->build_existing_file_state ($mode, $path);
}

sub _apply_rename_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;
  my $builder = $self->get_builder ();
  my $mode = $self->_get_mode ();
  my $path = $self->_get_path ();

  # TODO: checks
  return $builder->build_existing_file_state ($mode, $path);
}

sub _apply_index_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;
  my $builder = $self->get_builder ();
  my $mode = $self->_get_mode ();
  my $path = $self->_get_path ();

  # TODO: checks
  return $builder->build_modified_file_state ($mode, $path);
}

sub _is_same_vfunc
{
  my ($self, $other) = @_;

  if ($self->_get_mode () eq $other->_get_mode () and $self->_get_path () eq $other->_get_path ())
  {
    return 1;
  }

  return 0;
}

sub _generate_diff_header_vfunc
{
  my ($self, $old_file_state_wrapper) = @_;
  my $path = $self->_get_path ();
  my $mode = $self->_get_mode ();
  my $old_data = $old_file_state_wrapper->get_data_or_undef ();

  if (defined ($old_data))
  {
    my $old_path = $old_data->get_path ();
    my $old_mode = $old_data->get_mode ();
    my $common = Kgps::DiffHeaderCommon->new ($old_path, $path);
    my $part_mode = undef;
    my $part_rename = undef;

    if ($old_mode ne $mode)
    {
      $part_mode = Kgps::DiffHeaderPartMode->new ($old_mode, $mode);
    }
    if ($old_path ne $path)
    {
      $part_rename = Kgps::DiffHeaderPartRename->new (42, $old_path, $path);
    }

    my $specific = Kgps::DiffHeaderSpecificExisting->new ($part_mode, $part_rename, undef);

    return Kgps::DiffHeader->new_strict ($common, $specific);
  }
  else
  {
    return undef;
  }
}

sub _get_wrapper_vfunc
{
  my ($self) = @_;
  my $path = $self->_get_path ();
  my $mode = $self->_get_mode ();

  return Kgps::FileStateWrapperExisting->new ($path, $mode);
}

sub _get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

sub _get_path
{
  my ($self) = @_;

  return $self->{'path'};
}

1;
