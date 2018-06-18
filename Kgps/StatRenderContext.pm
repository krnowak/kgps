# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::StatRenderContext;

use strict;
use v5.16;
use warnings;

use File::Spec;

use constant
{
  PrefixSpaceLength => 1,

  MaxFileStatPathLength => 50,
  MaxFileStatLineLength => 79,
};

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::StatRenderContext');
  my $self = {
    'longest_path_length' => 0,
    'greatest_lines_changed_count' => 0,
    'locked' => 0,
    'max_signs_count' => 0,
    'max_lines_changed_count_length' => 0,
  };

  $self = bless ($self, $class);

  return $self;
}

sub feed_path_length
{
  my ($self, $length) = @_;

  $self->_die_if_locked ();

  my $old_length = $self->_get_longest_path_length ();

  if ($length > $old_length)
  {
    my $new_length = $length;
    if ($new_length > MaxFileStatPathLength)
    {
      $new_length = MaxFileStatPathLength;
    }
    if ($new_length > $old_length)
    {
      $self->_set_longest_path_length ($new_length);
    }
  }
}

sub feed_lines_changed_count
{
  my ($self, $count) = @_;

  $self->_die_if_locked ();

  my $old_count = $self->_get_greatest_lines_changed_count ();

  if ($count > $old_count)
  {
    $self->_set_greatest_lines_changed_count ($count);
  }
}

sub render_stat
{
  my ($self, $file_stat) = @_;

  $self->_lock ();

  my $path = $self->_shorten_path_if_needed ($file_stat->get_path ());
  my $rest = $file_stat->to_string ($self);

  return sprintf (' %-*2$s | %3$s', $path, $self->_get_longest_path_length (), $rest);
}

sub _log10plus1
{
  my ($num) = @_;

  my $ln = log ($num);
  my $l10 = log (10);
  my $l10n = $ln / $l10;
  my $result = sprintf("%d", $l10n) + 1;

  return $result;
}

sub render_text_rest
{
  my ($self, $changed_lines_count, $plus_count, $minus_count) = @_;
  my $count_length = _log10plus1 ($self->_get_greatest_lines_changed_count ());
  my $pluses = '+' x $plus_count;
  my $minuses = '-' x $minus_count;
  my $str = sprintf ('%*2$d %3$s%4$s', $changed_lines_count, $count_length, $pluses, $minuses);

  return $str;
}

sub _shorten_path_if_needed
{
  my ($self, $path) = @_;
  my $limit = $self->_get_longest_path_length ();
  my $path_length = length ($path);

  while (length ($path) > $limit)
  {
    my (undef, $dir, $basename) = File::Spec->splitpath ($path);
    my @dirs = File::Spec->splitdir ($dir);

    if (scalar (@dirs) > 0)
    {
      if ($dirs[0] eq '...')
      {
        shift (@dirs);
      }
    }
    else
    {
      last;
    }

    if (scalar (@dirs) > 0)
    {
      shift (@dirs);
      unshift (@dirs, '...');
    }
    else
    {
      last;
    }
    $path = File::Spec->catfile (@dirs, $basename);
  }

  return $path;
}

sub _get_longest_path_length
{
  my ($self) = @_;

  return $self->{'longest_path_length'};
}

sub _set_longest_path_length
{
  my ($self, $length) = @_;

  $self->{'longest_path_length'} = $length;
}

sub _get_greatest_lines_changed_count
{
  my ($self) = @_;

  return $self->{'greatest_lines_changed_count'};
}

sub _set_greatest_lines_changed_count
{
  my ($self, $count) = @_;

  $self->{'greatest_lines_changed_count'} = $count;
}

sub _die_if_locked
{
  my ($self) = @_;

  if ($self->{'locked'})
  {
    die;
  }
}

sub _lock
{
  my ($self) = @_;

  $self->{'locked'} = 1;
}

1;
