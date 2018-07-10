# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::ListingSummary;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;

  return _new_with_numbers ($type, 0, 0, 0);
}

sub get_files_changed_count
{
  my ($self) = @_;

  return $self->{'files_changed_count'};
}

sub set_files_changed_count
{
  my ($self, $count) = @_;

  $self->{'files_changed_count'} = $count;

  return;
}

sub get_insertions
{
  my ($self) = @_;

  return $self->{'insertions'};
}

sub set_insertions
{
  my ($self, $count) = @_;

  $self->{'insertions'} = $count;

  return;
}

sub get_deletions
{
  my ($self) = @_;

  return $self->{'deletions'};
}

sub set_deletions
{
  my ($self, $count) = @_;

  $self->{'deletions'} = $count;

  return;
}

sub merge
{
  my ($self, $other) = @_;
  my $merged_files_changed_count = $self->get_files_changed_count () + $other->get_files_changed_count ();
  my $merged_insertions = $self->get_insertions () + $other->get_insertions ();
  my $merged_deletions = $self->get_deletions () + $other->get_deletions ();

  return Kgps::ListingSummary->_new_with_numbers ($merged_files_changed_count, $merged_insertions, $merged_deletions);
}

sub to_string
{
  my ($self) = @_;
  my $files_changed_count = $self->get_files_changed_count ();
  my $insertions = $self->get_insertions ();
  my $deletions = $self->get_deletions ();
  my $files_word = 'files';

  if ($files_changed_count == 1)
  {
    chop ($files_word);
  }

  my $files_changed_part = " $files_changed_count $files_word changed";
  my $insertions_word = 'insertions';

  if ($insertions == 1)
  {
    chop ($insertions_word);
  }

  my $insertions_part = '';

  if ($insertions > 0 or $deletions == 0)
  {
    $insertions_part = ", $insertions $insertions_word(+)";
  }

  my $deletions_word = 'deletions';

  if ($deletions == 1)
  {
    chop ($deletions_word);
  }

  my $deletions_part = '';

  if ($deletions > 0 or $insertions == 0)
  {
    $deletions_part = ", $deletions $deletions_word(-)";
  }

  return "$files_changed_part$insertions_part$deletions_part";
}

sub _new_with_numbers
{
  my ($type, $files_changed_count, $insertions, $deletions) = @_;
  my $class = (ref ($type) or $type or 'Kgps::ListingSummary');
  my $self = {
    'files_changed_count' => $files_changed_count,
    'insertions' => $insertions,
    'deletions' => $deletions,
  };

  $self = bless ($self, $class);

  return $self;
}

1;
