# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::ListingAuxChangesDetailsModeRename;

use parent qw(Kgps::ListingAuxChangesDetailsBase);
use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $old_path, $new_path, $similarity_index, $old_mode, $new_mode) = @_;
  my $class = (ref ($type) or $type or 'Kgps::ListingAuxChangesDetailsModeRename');
  my $self = $class->SUPER::new ($new_path);

  $self->{'old_path'} = $old_path;
  $self->{'similarity_index'} = $similarity_index;
  $self->{'old_mode'} = $old_mode;
  $self->{'new_mode'} = $new_mode;
  $self = bless ($self, $class);

  return $self;
}

sub _to_lines_vfunc
{
  my ($self) = @_;
  my $old_path = $self->_get_old_path ();
  my $new_path = $self->_get_new_path ();
  my $similarity_index = $self->_get_similarity_index ();
  my $old_mode = $self->_get_old_mode ();
  my $new_mode = $self->_get_new_mode ();
  my @lines = ();

  push (@lines,
        " rename $old_path => $new_path ($similarity_index%)",
        " mode change $old_mode => $new_mode");

  return @lines;
}

sub _get_old_path
{
  my ($self) = @_;

  return $self->{'old_path'};
}

sub _get_new_path
{
  my ($self) = @_;

  return $self->get_path ()
}

sub _get_similarity_index
{
  my ($self) = @_;

  return $self->{'similarity_index'};
}

sub _get_old_mode
{
  my ($self) = @_;

  return $self->{'old_mode'};
}

sub _get_new_mode
{
  my ($self) = @_;

  return $self->{'new_mode'};
}

1;
