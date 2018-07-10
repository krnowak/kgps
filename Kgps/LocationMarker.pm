# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# LocationMarker is a representation of a line that describes a
# location of a chunk of changed code. These are lines in a patch that
# look like:
#
# @@ -81,6 +81,7 @@ sub DB_COLUMNS {
#
# The line contains line number and count before the change and after
# the change. It also may contain some context, which comes after
# second `@@`. Context is the first line that is before the chunk with
# no leading whitespace.
package Kgps::LocationMarker;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::LocationMarker');
  my $self =
  {
    'old_line_no' => undef,
    'old_line_count' => undef,
    'new_line_no' => undef,
    'new_line_count' => undef,
    'inline_context' => undef,
  };

  $self = bless ($self, $class);

  return $self;
}

sub new_zero
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::LocationMarker');
  my $self = $class->new ();

  $self->set_old_line_no (0);
  $self->set_old_line_count (0);
  $self->set_new_line_no (0);
  $self->set_new_line_count (0);

  return $self;
}

sub parse_line
{
  my ($self, $line) = @_;

  if ($line =~ /^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@(?:\s+(\S.*))?$/)
  {
    my $old_line_no = $1;
    my $old_line_count = $2;
    my $new_line_no = $3;
    my $new_line_count = $4;
    my $inline_context = $5;

    unless (defined ($old_line_count))
    {
      $old_line_count = 1;
    }
    unless (defined ($new_line_count))
    {
      $new_line_count = 1;
    }

    $self->set_old_line_no ($old_line_no);
    $self->set_old_line_count ($old_line_count);
    $self->set_new_line_no ($new_line_no);
    $self->set_new_line_count ($new_line_count);
    $self->set_inline_context ($inline_context);

    return 1;
  }

  return 0;
}

sub clone
{
  my ($self) = @_;
  my $class = (ref ($self) or $self or 'Kgps::LocationMarker');
  my $clone = $class->new ();

  $clone->set_old_line_no ($self->get_old_line_no ());
  $clone->set_new_line_no ($self->get_new_line_no ());
  $clone->set_old_line_count ($self->get_old_line_count ());
  $clone->set_new_line_count ($self->get_new_line_count ());
  $clone->set_inline_context ($self->get_inline_context ());

  return $clone;
}

sub set_old_line_no
{
  my ($self, $old_line_no) = @_;

  $self->{'old_line_no'} = $old_line_no;

  return;
}

sub get_old_line_no
{
  my ($self) = @_;

  return $self->{'old_line_no'};
}

sub inc_old_line_no
{
  my ($self) = @_;

  return ++$self->{'old_line_no'};
}

sub dec_old_line_no
{
  my ($self) = @_;

  --$self->{'old_line_no'};

  return;
}

sub set_old_line_count
{
  my ($self, $old_line_count) = @_;

  $self->{'old_line_count'} = $old_line_count;

  return;
}

sub get_old_line_count
{
  my ($self) = @_;

  return $self->{'old_line_count'};
}

sub inc_old_line_count
{
  my ($self) = @_;

  return ++$self->{'old_line_count'};
}

sub set_new_line_no
{
  my ($self, $new_line_no) = @_;

  $self->{'new_line_no'} = $new_line_no;

  return;
}

sub get_new_line_no
{
  my ($self) = @_;

  return $self->{'new_line_no'};
}

sub inc_new_line_no
{
  my ($self) = @_;

  return ++$self->{'new_line_no'};
}

sub dec_new_line_no
{
  my ($self) = @_;

  --$self->{'new_line_no'};

  return;
}

sub set_new_line_count
{
  my ($self, $new_line_count) = @_;

  $self->{'new_line_count'} = $new_line_count;

  return;
}

sub get_new_line_count
{
  my ($self) = @_;

  return $self->{'new_line_count'};
}

sub inc_new_line_count
{
  my ($self) = @_;

  return ++$self->{'new_line_count'};
}

sub set_inline_context
{
  my ($self, $inline_context) = @_;

  $self->{'inline_context'} = $inline_context;

  return;
}

sub get_inline_context
{
  my ($self) = @_;

  return $self->{'inline_context'};
}

sub add_marker
{
  my ($self, $other) = @_;

  $self->set_old_line_no ($self->get_old_line_no () + $other->get_old_line_no ());
  $self->set_new_line_no ($self->get_new_line_no () + $other->get_new_line_no ());
  $self->set_old_line_count ($self->get_old_line_count () + $other->get_old_line_count ());
  $self->set_new_line_count ($self->get_new_line_count () + $other->get_new_line_count ());

  return;
}

sub sanitize
{
  my ($self) = @_;
  my $old_no = $self->get_old_line_no ();
  my $old_count = $self->get_old_line_count ();
  my $new_no = $self->get_new_line_no ();
  my $new_count = $self->get_new_line_count ();

  if ($old_no < 0)
  {
    $old_no = 0;
  }
  if ($new_no < 0)
  {
    $new_no = 0;
  }
  if ($old_count < 0)
  {
    $old_count = 0;
  }
  if ($new_count < 0)
  {
    $new_count = 0;
  }

  if ($old_no == 0 and $old_count > 0)
  {
    $old_no = 1;
  }
  if ($new_no == 0 and $new_count > 0)
  {
    $new_no = 1;
  }
  if ($old_count == 0 and $old_no > 0)
  {
    $old_no = 0;
  }
  if ($new_count == 0 and $new_no > 0)
  {
    $new_no = 0;
  }

  $self->set_old_line_no ($old_no);
  $self->set_old_line_count ($old_count);
  $self->set_new_line_no ($new_no);
  $self->set_new_line_count ($new_count);

  return;
}

1;
