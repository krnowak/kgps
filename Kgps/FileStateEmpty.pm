# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::FileStateEmpty;

use parent qw(Kgps::FileStateBase);
use strict;
use v5.16;
use warnings;

use Kgps::DiffHeader;
use Kgps::DiffHeaderCommon;
use Kgps::DiffHeaderPartContents;
use Kgps::DiffHeaderSpecificDeleted;
use Kgps::FileStateWrapperEmpty;

sub new
{
  my ($type, $builder) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FileStateEmpty');
  my $self = $class->SUPER::new ($builder);

  $self = bless ($self, $class);

  return $self;
}

sub _apply_create_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;

  unless ($fresh_start)
  {
    return;
  }

  my $builder = $self->get_builder ();
  my $mode = $customization->get_mode ();
  my $path = $customization->get_path ();

  return $builder->build_modified_file_state ($mode, $path);
}

sub _apply_delete_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;

  return;
}

sub _apply_mode_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;

  return;
}

sub _apply_rename_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;

  return;
}

sub _apply_index_customization_vfunc
{
  my ($self, $customization, $fresh_start) = @_;

  return;
}

sub _is_same_vfunc
{
  my ($self, $other) = @_;

  return 1;
}

sub _generate_diff_header_vfunc
{
  my ($self, $old_file_state_wrapper) = @_;
  my $old_data = $old_file_state_wrapper->get_data_or_undef ();

  unless (defined ($old_data))
  {
    # TODO: die("empty to empty?");
    return;
  }

  my $old_path = $old_data->get_path ();
  my $old_mode = $old_data->get_mode ();
  my $common = Kgps::DiffHeaderCommon->new ($old_path, $old_path);
  my $part_contents = Kgps::DiffHeaderPartContents ('1' x 7, '2' x 7);
  my $specific = Kgps::DiffHeaderSpecificDeleted->new ($old_mode, $part_contents);

  return Kgps::DiffHeader->new_relaxed ($common, $specific);
}

sub _get_wrapper_vfunc
{
  my ($self) = @_;

  return Kgps::FileStateWrapperEmpty->new ();
}

1;
