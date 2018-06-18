#!/usr/bin/perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DateInc;

use strict;
use v5.16;
use warnings;

use constant
{
  From => 0,
  Upto => 1,
  Ignore => 2,
};

sub new_ignore
{
  my ($type) = @_;

  return new ($type, 0, 0, 0, 0, Ignore);
}

sub new
{
  my ($type, $days, $hours, $minutes, $seconds, $mode) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DateInc');
  my $self = {
    'days' => $days,
    'hours' => $hours,
    'minutes' => $minutes,
    'seconds' => $seconds,
    'mode' => $mode,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_days
{
  my ($self) = @_;

  return $self->{'days'};
}

sub get_hours
{
  my ($self) = @_;

  return $self->{'hours'};
}

sub get_minutes
{
  my ($self) = @_;

  return $self->{'minutes'};
}

sub get_seconds
{
  my ($self) = @_;

  return $self->{'seconds'};
}

sub get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

1;
