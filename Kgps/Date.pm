#!/usr/bin/perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# Date represents a date from git patch. It is really an RFC822
# format.
#
# This package is ew. Time handling is ew.
package Kgps::Date;

use strict;
use v5.16;
use warnings;

use DateTime;

use Kgps::Misc;

my %month_to_idx = _words_to_idx_map ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
my %day_to_idx = _words_to_idx_map ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');

sub create
{
  my ($type, $raw) = @_;
  my $dt = _do_lame_strptime ($raw);

  return undef unless (defined ($dt));
  return _new_with_datetime ($type, $dt);
}

sub incremented
{
  my ($self, $date_inc) = @_;
  my $dt = $self->_get_dt ();
  my $new_dt = $dt->clone ();

  $new_dt->add (
    'days' => $date_inc->get_days (),
    'hours' => $date_inc->get_hours (),
    'minutes' => $date_inc->get_minutes (),
    'seconds' => $date_inc->get_seconds ()
  );

  return Kgps::Date->_new_with_datetime ($new_dt);
}

sub decremented
{
  my ($self, $date_inc) = @_;
  my $dt = $self->_get_dt ();
  my $new_dt = $dt->clone ();

  $new_dt->subtract (
    'days' => $date_inc->get_days (),
    'hours' => $date_inc->get_hours (),
    'minutes' => $date_inc->get_minutes (),
    'seconds' => $date_inc->get_seconds ()
  );

  return Kgps::Date->_new_with_datetime ($new_dt);
}

sub to_string
{
  my ($self) = @_;
  my $dt = $self->_get_dt ();

  # DateTime insists on formatting day as two digits number, even if
  # it is less than 10. Git doesn't format patches that way.
  my $day = $dt->day_of_month ();
  return $dt->strftime("%a, $day %b %Y %H:%M:%S %z");
}

sub _get_dt
{
  my ($self) = @_;

  return $self->{'dt'};
}

sub _new_with_datetime
{
  my ($type, $dt) = @_;
  my $class = (ref ($type) or $type or 'Kgps::Date');
  my $self = {
    'dt' => $dt
  };

  $self = bless ($self, $class);

  return $self;
}

sub _do_lame_strptime
{
  my ($raw) = @_;

  if ($raw =~ /^(\w{3}), (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ([-+]\d{4})$/)
  {
    my $day_str = $1;
    my $day = Kgps::Misc::to_num ($2);
    my $month_str = $3;
    my $year = Kgps::Misc::to_num ($4);
    my $hour = Kgps::Misc::to_num ($5);
    my $minute = Kgps::Misc::to_num ($6);
    my $second = Kgps::Misc::to_num ($7);
    my $offset_str = $8;

    return undef unless (exists ($day_to_idx{$day_str}));
    return undef unless (exists ($month_to_idx{$month_str}));
    return undef unless (1 <= $day and $day <= 31);
    return undef unless (0 <= $hour and $hour <= 23);
    return undef unless (0 <= $minute and $minute <= 59);
    return undef unless (0 <= $second and $second <= 61);

    return DateTime->new (
      'year' => $year,
      'month' => $month_to_idx{$month_str},
      'day' => $day,
      'hour' => $hour,
      'minute' => $minute,
      'second' => $second,
      'time_zone' => $offset_str,
      'locale' => 'C',
    );
  }

  return undef;
}

sub _words_to_idx_map
{
  my $i = 0;

  return map { $_ => ++$i } @_;
}

1;
