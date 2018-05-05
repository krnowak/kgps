# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::NewAndGoneFiles;

use strict;
use v5.16;
use warnings;

use Kgps::NewAndGoneDetails;

sub new
{
  my ($type) = @_;

  return _new_with_files ($type, {});
}

sub add_details
{
  my ($self, $path, $details) = @_;
  my $files = $self->_get_files ();

  if (exists ($files->{$path}))
  {
    return 0;
  }

  $files->{$path} = $details;

  return 1;
}

sub get_details_for_path
{
  my ($self, $path) = @_;
  my $files = $self->_get_files ();

  unless (exists ($files->{$path}))
  {
    return undef;
  }

  return $files->{$path};
}

sub merge
{
  my ($self, $other) = @_;
  my $self_files = $self->_get_files ();
  my $other_files = $other->_get_files ();
  my $merged_files = { %{$self_files}, %{$other_files} };

  if (scalar (keys (%{$merged_files})) != scalar (keys (%{$self_files})) + scalar (keys (%{$other_files})))
  {
    return undef;
  }

  return Kgps::NewAndGoneFiles->_new_with_files ($merged_files);
}

sub to_lines
{
  my ($self) = @_;
  my $files = $self->_get_files ();
  my @lines = ();

  for my $path (sort (keys (%{$files})))
  {
    my $details = $files->{$path};
    my $action = $details->get_action ();
    my $mode = $details->get_mode ();
    my $action_str = '';

    if ($action == Kgps::NewAndGoneDetails::Create)
    {
      $action_str = 'create';
    }
    elsif ($action == Kgps::NewAndGoneDetails::Delete)
    {
      $action_str = 'delete';
    }
    else
    {
      die;
    }

    push (@lines, " $action_str mode $mode $path");
  }

  return @lines;
}

sub _get_files
{
  my ($self) = @_;

  return $self->{'files'};
}

sub _new_with_files
{
  my ($type, $files) = @_;
  my $class = (ref ($type) or $type or 'Kgps::NewAndGoneFiles');
  my $self = {
    # path to NewAndGoneDetails
    'files' => $files
  };

  $self = bless ($self, $class);

  return $self;
}

1;
