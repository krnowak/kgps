# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# Section describes the generated patch and its ancestor-descendant
# relation to other generated patches.
package Kgps::Section;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type, $name, $index) = @_;
  my $class = (ref ($type) or $type or 'Kgps::Section');
  my $self =
  {
    'name' => $name,
    'index' => $index,
    'subject' => undef,
    'author' => undef,
    'date' => undef,
    'subject' => undef,
    'message_lines' => undef,
    'special' => 0,
  };

  $self = bless ($self, $class);

  return $self;
}

sub new_special
{
  my ($type, $name, $index, $neighbour) = @_;
  my $class = (ref ($type) or $type or 'Kgps::Section');
  my $self =
  {
    'name' => $name,
    'index' => $index,
    'neighbour' => $neighbour,
    'special' => 1,
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_neighbour_if_special
{
  my ($self) = @_;

  if ($self->_is_special ())
  {
    return $self->_get_neighbour ();
  }

  return $self;
}

sub get_name
{
  my ($self) = @_;

  return $self->{'name'};
}

sub get_index
{
  my ($self) = @_;

  return $self->{'index'};
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

sub get_date
{
  my ($self) = @_;

  return $self->{'date'};
}

sub set_date
{
  my ($self, $date) = @_;

  $self->{'date'} = $date;
}

sub get_message_lines
{
  my ($self) = @_;

  $self->{'message_lines'}
}

sub set_message_lines
{
  my ($self, $lines) = @_;

  $self->{'message_lines'} = $lines;
}

sub add_message_line
{
  my ($self, $line) = @_;
  my $lines = $self->get_message_lines ();

  unless (defined ($lines))
  {
    $lines = $self->{'message_lines'} = [];
  }

  push (@{$lines}, $line);
}

sub is_older_than
{
  my ($self, $other) = @_;
  my $index = $self->get_index ();
  my $other_index = $other->get_index ();

  # the lower the index the older the section is.
  return ($index < $other_index);
}

sub is_younger_than
{
  my ($self, $other) = @_;

  return $other->is_older_than ($self);
}

sub is_same_as
{
  my ($self, $other) = @_;
  my $index = $self->get_index ();
  my $other_index = $other->get_index ();

  return ($index == $other_index);
}

sub _is_special
{
  my ($self) = @_;

  return $self->{'special'};
}

sub _get_neighbour
{
  my ($self) = @_;

  return $self->{'neighbour'};
}

1;
