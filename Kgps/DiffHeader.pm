# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# DiffHeader is a representation of lines that come before the
# description of actual changes in the file. These are lines that look
# like:
#
# diff --git a/.bzrignore.moved b/.bzrignore.moved
# new file mode 100644
# index 0000000..f852cf1
package Kgps::DiffHeader;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeader');
  my $self =
  {
    'a' => undef,
    'b' => undef,
    'action' => undef,
    'mode' => undef,
    'index_from' => undef,
    'index_to' => undef
  };

  $self = bless ($self, $class);

  return $self;
}

sub parse_diff_line
{
  my ($self, $line) = @_;

  if ($line =~ m!^diff --git a/(.*) b/(.*)$!)
  {
    $self->set_a ($1);
    $self->set_b ($2);

    return 1;
  }

  return 0;
}

sub parse_mode_line
{
  my ($self, $line) = @_;

  if ($line =~ /^(.*)\s+mode\s+(\d+)$/)
  {
    $self->set_action ($1);
    $self->set_mode ($2);

    return 1;
  }

  return 0;
}

sub parse_index_line
{
  my ($self, $line) = @_;

  if ($line =~ /^index\s+(\w+)\.\.(\w+)(?:\s+(\d+))?$/)
  {
    $self->set_index_from ($1);
    $self->set_index_to ($2);
    if (defined ($3))
    {
      $self->set_mode ($3);
    }

    return 1;
  }

  return 0;
}

sub get_a
{
  my ($self) = @_;

  return $self->{'a'};
}

sub set_a
{
  my ($self, $a) = @_;

  $self->{'a'} = $a;
}

sub get_b
{
  my ($self) = @_;

  return $self->{'b'};
}

sub set_b
{
  my ($self, $b) = @_;

  $self->{'b'} = $b;
}

sub get_action
{
  my ($self) = @_;

  return $self->{'action'};
}

sub set_action
{
  my ($self, $action) = @_;

  $self->{'action'} = $action;
}

sub get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

sub set_mode
{
  my ($self, $mode) = @_;

  $self->{'mode'} = $mode;
}

sub get_index_from
{
  my ($self) = @_;

  return $self->{'index_from'};
}

sub set_index_from
{
  my ($self, $index_from) = @_;

  $self->{'index_from'} = $index_from;
}

sub get_index_to
{
  my ($self) = @_;

  return $self->{'index_to'};
}

sub set_index_to
{
  my ($self, $index_to) = @_;

  $self->{'index_to'} = $index_to;
}

1;
