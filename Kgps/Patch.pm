# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# Patch is a representation of the annotated patch.
package Kgps::Patch;

use strict;
use v5.16;
use warnings;

use Kgps::ListingInfo;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::Patch');
  my $self =
  {
    'author' => undef,
    'from_date' => undef,
    'patch_date' => undef,
    'subject' => undef,
    'message_lines' => [],
    'date_inc' => undef,
    'diffs' => [],
    'sections_ordered' => [],
    'sections_unordered' => {},
    'raw_diffs_and_modes' => {}
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_author
{
  my ($self) = @_;

  return $self->{'author'};
}

sub set_author
{
  my ($self, $author) = @_;

  $self->{'author'} = $author;
}

sub get_from_date
{
  my ($self) = @_;

  return $self->{'from_date'};
}

sub set_from_date
{
  my ($self, $from_date) = @_;

  $self->{'from_date'} = $from_date;
}

sub get_patch_date
{
  my ($self) = @_;

  return $self->{'patch_date'};
}

sub set_patch_date
{
  my ($self, $patch_date) = @_;

  $self->{'patch_date'} = $patch_date;
}

sub get_subject
{
  my ($self) = @_;

  return $self->{'subject'};
}

sub set_subject
{
  my ($self, $subject) = @_;

  $self->{'subject'} = $subject;
}

sub get_message_lines
{
  my ($self) = @_;

  return $self->{'message_lines'};
}

sub add_message_line
{
  my ($self, $line) = @_;
  my $lines = $self->get_message_lines ();

  push (@{$lines}, $line);
}

sub get_date_inc
{
  my ($self) = @_;

  return $self->{'date_inc'};
}

sub set_date_inc
{
  my ($self, $date_inc) = @_;

  $self->{'date_inc'} = $date_inc;
}

sub get_diffs
{
  my ($self) = @_;

  return $self->{'diffs'};
}

sub add_diff
{
  my ($self, $diff) = @_;
  my $diffs = $self->get_diffs ();

  push (@{$diffs}, $diff);
}

sub get_last_diff
{
  my ($self) = @_;
  my $diffs = $self->get_diffs ();

  if (@{$diffs} > 0)
  {
    return @{$diffs}[-1];
  }

  return undef;
}

sub get_sections_ordered
{
  my ($self) = @_;

  return $self->{'sections_ordered'};
}

sub get_sections_unordered
{
  my ($self) = @_;

  return $self->{'sections_unordered'};
}

sub get_sections_count
{
  my ($self) = @_;
  my $count = @{$self->get_sections_ordered ()};

  return $count;
}

sub add_section
{
  my ($self, $section) = @_;
  my $ordered = $self->get_sections_ordered ();
  my $unordered = $self->get_sections_unordered ();
  my $name = $section->get_name ();

  if (exists ($unordered->{$name}))
  {
    return 0;
  }

  push (@{$ordered}, $section);
  $unordered->{$name} = $section;
  return 1;
}

sub get_raw_diffs_and_modes
{
  my ($self) = @_;

  return $self->{'raw_diffs_and_modes'};
}

sub add_raw_diffs_and_mode
{
  my ($self, $diffs_and_mode) = @_;
  my $raw_diffs_and_modes = $self->get_raw_diffs_and_modes ();
  my $git_diffs = $diffs_and_mode->{'git-raw'};
  my $stats = $diffs_and_mode->{'stats'};

  foreach my $section_name (keys (%{$git_diffs}))
  {
    unless (exists ($raw_diffs_and_modes->{$section_name}))
    {
      $raw_diffs_and_modes->{$section_name} = {'git-diffs' => [], 'stats' => Kgps::ListingInfo->new ()};
    }

    push (@{$raw_diffs_and_modes->{$section_name}->{'git-diffs'}}, $git_diffs->{$section_name});
  }

  foreach my $section_name (keys (%{$stats}))
  {
    unless (exists ($raw_diffs_and_modes->{$section_name}))
    {
      $raw_diffs_and_modes->{$section_name} = {'git-diffs' => [], 'stats' => Kgps::ListingInfo->new ()};
    }

    my $new_listing = $raw_diffs_and_modes->{$section_name}->{'stats'}->merge ($stats->{$section_name});

    unless (defined ($new_listing))
    {
      # TODO: just die.
      next;
    }
    $raw_diffs_and_modes->{$section_name}->{'stats'} = $new_listing;
  }
}

sub get_ordered_sectioned_raw_diffs_and_modes
{
  my ($self) = @_;
  my $sections_array = $self->get_sections_ordered ();
  my $raw_diffs_and_modes = $self->get_raw_diffs_and_modes ();
  my @sectioned_diffs_and_modes = ();

  foreach my $section (@{$sections_array})
  {
    my $section_name = $section->get_name ();

    if (exists ($raw_diffs_and_modes->{$section_name}))
    {
      my $diffs_and_modes =
      {
        'git-diffs' => $raw_diffs_and_modes->{$section_name}->{'git-diffs'},
        'section' => $section,
        'stats' => $raw_diffs_and_modes->{$section_name}->{'stats'}
      };
      push (@sectioned_diffs_and_modes, $diffs_and_modes);
    }
  }

  return \@sectioned_diffs_and_modes;
}

1;
