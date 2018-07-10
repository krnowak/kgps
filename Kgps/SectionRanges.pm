# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::SectionRanges;

use strict;
use v5.16;
use warnings;

use constant
{
  NotInRange => 0,
  AdditionsOnly => 1,
  DeletionsOnly => 2,
  Any => 3,
};

sub new
{
  my ($type, $first_section, $last_section) = @_;

  return _new_with_ranges ($type, [[$first_section, $last_section]]);
}

sub new_empty
{
  my ($type) = @_;

  return _new_with_ranges ($type, []);
}

sub add_range
{
  my ($self, $first_section, $last_section) = @_;
  my $ranges = $self->_get_ranges ();

  _ensure_order_or_die ($first_section, $last_section);
  push (@{$ranges}, [$first_section, $last_section]);

  return;
}

sub terminate_last_range_at
{
  my ($self, $last_section) = @_;
  my $ranges = $self->_get_ranges ();

  _ensure_any_range_or_die ($ranges);

  my $last_range = $ranges->[-1];
  my $first_section = $last_range->[0];

  _ensure_order_or_die ($first_section, $last_section);
  $last_range->[1] = $last_section;

  return;
}

sub is_in_range
{
  my ($self, $section) = @_;
  my $ranges = $self->_get_ranges ();

  _ensure_any_range_or_die ($ranges);

  for my $range (@{$ranges})
  {
    my $first_section = $range->[0];
    my $last_section = $range->[1];

    if ($first_section->is_same_as ($section))
    {
      return AdditionsOnly;
    }
    if ($last_section->is_same_as ($section))
    {
      return DeletionsOnly;
    }
    if ($first_section->is_older_than ($section) and $last_section->is_younger_than ($section))
    {
      return Any;
    }
  }

  return NotInRange;
}

sub get_last_allowed_section
{
  my ($self) = @_;
  my $ranges = $self->_get_ranges ();

  _ensure_any_range_or_die ($ranges);

  my $last_range = $ranges->[-1];
  my $last_section = $last_range->[1];

  return $last_section->get_neighbour_if_special ();
}

sub _ensure_any_range_or_die
{
  my ($ranges) = @_;

  unless (@{$ranges})
  {
    die;
  }

  return;
}

sub _ensure_order_or_die
{
  my ($first_section, $last_section) = @_;

  if ($first_section->is_same_as ($last_section))
  {
    die;
  }
  if ($first_section->is_younger ($last_section))
  {
    die;
  }

  return;
}

sub _get_ranges
{
  my ($self) = @_;

  return $self->{'ranges'};
}

sub _new_with_ranges
{
  my ($type, $ranges) = @_;
  my $class = (ref ($type) or $type or 'Kgps::SectionRanges');
  my $self =
  {
    'ranges' => $ranges,
  };

  $self = bless ($self, $class);

  return $self;
}

1;
