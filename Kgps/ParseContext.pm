# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# ParseContext describes the current state of parsing the annotated
# patch.
package Kgps::ParseContext;

use strict;
use v5.16;
use warnings;

use Kgps::Patch;

use constant
{
  PreviousLinesLimit => 3
};

sub new
{
  my ($type, $initial_mode, $ops) = @_;
  my $class = (ref ($type) or $type or 'Kgps::ParseContext');
  my $self =
  {
    'file' => undef,
    'eof' => 1,
    'reached_eof' => 1,
    'filename' => undef,
    'mode' => $initial_mode,
    'line_number' => 0,
    'ops' => $ops,
    'line' => undef,
    'unread_lines' => [],
    'previous_lines' => [],
    'patch' => Kgps::Patch->new (),
    'current_diff_header' => undef
  };

  $self = bless ($self, $class);

  return $self;
}

sub setup_file
{
  my ($self, $file, $filename) = @_;

  $self->{'file'} = $file;
  $self->_set_eof (0);
  $self->{'reached_eof'} = 0;
  $self->{'filename'} = $filename;
}

sub get_file
{
  my ($self) = @_;

  return $self->{'file'};
}

sub get_filename
{
  my ($self) = @_;

  return $self->{'filename'};
}

sub get_patch
{
  my ($self) = @_;

  return $self->{'patch'};
}

sub get_eof
{
  my ($self) = @_;

  return $self->{'eof'};
}

sub _reached_eof
{
  my ($self) = @_;

  return $self->{'reached_eof'};
}

sub _set_eof
{
  my ($self, $eof) = @_;

  $self->{'eof'} = $eof;
  if ($eof)
  {
    $self->{'reached_eof'} = 1;
  }
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

sub get_line
{
  my ($self) = @_;

  return $self->{'line'};
}

sub set_line
{
  my ($self, $line) = @_;

  $self->{'line'} = $line;
}

sub unread_line
{
  my ($self) = @_;
  my $unread_lines = $self->_get_unread_lines ();
  my $line = $self->get_line ();
  my $previous_lines = $self->_get_previous_lines ();

  if (defined ($line))
  {
    push (@{$unread_lines}, $line);
  }
  $line = pop (@{$previous_lines});
  $self->set_line ($line);
  $self->_set_eof (0);
  $self->dec_line_no ();
}

sub read_next_line
{
  my ($self) = @_;
  my $old_line = $self->get_line ();

  if (defined ($old_line))
  {
    my $prev_lines = $self->_get_previous_lines ();
    until (scalar (@{$prev_lines}) < PreviousLinesLimit) {
      shift (@{$prev_lines});
    }
    push (@{$prev_lines}, $old_line);
  }

  my $unread_lines = $self->_get_unread_lines ();
  my $line = pop (@{$unread_lines});

  if (defined ($line))
  {
    $self->set_line ($line);
    $self->inc_line_no ();
    $self->_set_eof (0);
  }
  elsif ($self->_reached_eof ())
  {
    if (defined ($old_line))
    {
      $self->set_line (undef);
      $self->inc_line_no ();
    }
    $self->_set_eof (1);
  }
  else
  {
    my $file = $self->get_file ();

    $line = $file->getline ();
    if (defined ($line))
    {
      chomp ($line);
      $self->set_line ($line);
      $self->inc_line_no ();
      $self->_set_eof (0);
    }
    else
    {
      if (defined ($old_line))
      {
        $self->set_line (undef);
      }
      $self->inc_line_no ();
      $self->_set_eof (1);
    }
  }

  return not $self->get_eof ();
}

sub _get_previous_lines
{
  my ($self) = @_;

  return $self->{'previous_lines'};
}

sub _get_unread_lines
{
  my ($self) = @_;

  return $self->{'unread_lines'};
}

sub run_op
{
  my ($self) = @_;
  my $ops = $self->{'ops'};
  my $mode = $self->get_mode ();

  unless (exists ($ops->{$mode}))
  {
    $self->die ("Unknown patch mode: '$mode'.");
  }

  $ops->{$mode} ();
}

sub get_line_no
{
  my ($self) = @_;

  return $self->{'line_number'};
}

sub inc_line_no
{
  my ($self) = @_;

  $self->_mod_line_no (1);
}

sub dec_line_no
{
  my ($self) = @_;

  if ($self->get_line_no () > 0)
  {
    $self->_mod_line_no (-1);
  }
}

sub _mod_line_no
{
  my ($self, $increment) = @_;

  $self->{'line_number'} += $increment;
}

sub die
{
  my ($self, $message) = @_;
  my $filename = $self->get_filename ();
  my $line_no = $self->get_line_no ();

  die "$filename:$line_no - $message";
}

sub get_last_diff_or_die
{
  my ($self) = @_;
  my $patch = $self->get_patch ();
  my $diff = $patch->get_last_diff ();

  unless (defined ($diff))
  {
    $self->die ("Expected a diff to exist.");
  }

  return $diff;
}

sub exhaust_the_file
{
  my ($self) = @_;

  while ($self->read_next_line ()) {};
}

sub get_current_diff_header
{
  my ($self) = @_;

  return $self->{'current_diff_header'};
}

sub set_current_diff_header
{
  my ($self, $current_diff_header) = @_;

  $self->{'current_diff_header'} = $current_diff_header;
}

sub get_current_diff_header_or_die
{
  my ($self) = @_;
  my $diff_header = $self->get_current_diff_header ();

  unless (defined ($diff_header))
  {
    $self->die ("Expected diff header to exist.");
  }

  return $diff_header;
}

1;
