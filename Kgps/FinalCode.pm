# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# FinalCode is the final form of the single code chunk. It contains
# lines that already took the changes made in older generated patches
# into account.
package Kgps::FinalCode;

use parent qw(Kgps::CodeBase);
use strict;
use v5.16;
use warnings;

use Kgps::CodeLine;
use Kgps::LocationMarker;
use Kgps::Misc;

sub new
{
  my ($type, $marker) = @_;
  my $class = (ref ($type) or $type or 'Kgps::FinalCode');
  my $self = $class->SUPER::new ();

  $self->{'marker'} = $marker;
  $self->{'bare_marker'} = undef;
  $self->{'before_context'} = [];
  $self->{'after_context'} = [];
  $self = bless ($self, $class);

  return $self;
}

sub get_marker
{
  my ($self) = @_;

  return $self->{'marker'};
}

sub get_before_context
{
  my ($self) = @_;

  return $self->{'before_context'};
}

sub set_before_context
{
  my ($self, $context) = @_;

  $self->{'before_context'} = $context;
}

sub get_after_context
{
  my ($self) = @_;

  return $self->{'after_context'};
}

sub push_after_context_line
{
  my ($self, $line) = @_;
  my $after = $self->get_after_context ();

  push (@{$after}, $line);
}

sub set_bare_marker
{
  my ($self, $marker) = @_;

  $self->{'bare_marker'} = $marker;
}

sub get_bare_marker
{
  my ($self) = @_;

  return $self->{'bare_marker'};
}

sub cleanup_context
{
  my ($self) = @_;
  my $initial_context_count = 0;
  my $final_context_count = 0;
  my $modification_met = 0;
  my $lines = $self->get_lines ();

  # Compute lengths of context in lines.
  foreach my $line (@{$lines})
  {
    if ($line->get_sigil () == Kgps::CodeLine::Space)
    {
      if ($modification_met)
      {
        ++$final_context_count;
      }
      else
      {
        ++$initial_context_count;
      }
    }
    else
    {
      $modification_met = 1;
      $final_context_count = 0;
    }
  }

  # Append/prepend context to lines.
  my $before_context = $self->get_before_context ();
  my $after_context = $self->get_after_context ();
  my $marker = $self->get_marker ();
  my $additions = Kgps::LocationMarker->new_zero ();
  my $count = @{$before_context} + @{$after_context};
  my $line_no = -@{$before_context};

  unshift (@{$lines}, @{$before_context});
  push (@{$lines}, @{$after_context});
  $initial_context_count += @{$before_context};
  $final_context_count += @{$after_context};

  # Reduce context to three lines.
  if ($initial_context_count > 3)
  {
    my $cut = $initial_context_count - 3;

    splice (@{$lines}, 0, $cut);
    $count -= $cut;
    $line_no += $cut;
    $initial_context_count = 3;
  }
  if ($final_context_count > 3)
  {
    my $cut = $final_context_count - 3;

    splice (@{$lines}, -$cut, $cut);
    $count -= $cut;
    $final_context_count = 3;
  }

  # Update marker.
  $additions->set_old_line_no ($line_no);
  $additions->set_old_line_count ($count);
  $additions->set_new_line_no ($line_no);
  $additions->set_new_line_count ($count);
  $marker->add_marker ($additions);
  $marker->sanitize ();

  # Setup bare marker (for easy computing whether two final codes can be merged).
  my $bare_marker = $marker->clone ();

  $additions->set_old_line_count (-$initial_context_count - $final_context_count);
  $additions->set_new_line_count (-$initial_context_count - $final_context_count);
  $additions->set_old_line_no ($initial_context_count);
  $additions->set_new_line_no ($initial_context_count);
  $bare_marker->add_marker ($additions);
  $self->set_bare_marker ($bare_marker);
}

sub merge_final_code
{
  my ($self, $other) = @_;
  my $bare_marker = $self->get_bare_marker ();
  my $other_bare_marker = $other->get_bare_marker ();
  my $length_of_context_in_between = $other_bare_marker->get_new_line_no () - $bare_marker->get_new_line_no () - $bare_marker->get_new_line_count ();

  return 0 if $length_of_context_in_between > 6;

  my $lines = $self->get_lines ();
  my $other_lines = $other->get_lines ();
  my $additions = Kgps::LocationMarker->new_zero ();
  my $marker = $self->get_marker ();
  my $other_marker = $other->get_marker ();
  my @after = @{$self->_get_after_context_from_lines ()};
  my @before = reverse (@{$other->_get_before_context_from_lines ()});
  my @context_in_between = ();

  # Prepare new inside context if there is going to be one.
  if ($length_of_context_in_between > 0)
  {
    my $left = $length_of_context_in_between;
    my $to_take = ((@after > $left) ? $left : @after);

    push (@context_in_between, @after[0 .. $to_take - 1]);
    $left -= $to_take;

    if ($left > 0)
    {
      $to_take = ((@before > $left) ? $left : @before);
      push (@context_in_between, reverse (@before[0 .. $to_take - 1]));
      $left -= $to_take;

      die "SHOULD NOT HAPPEN" if $left > 0;
    }
  }

  # Remove the old inside context and insert new one.
  splice (@{$lines}, -@after) if (@after);
  splice (@{$other_lines}, 0, @before) if (@before);

  push (@{$lines}, @context_in_between, @{$other_lines});

  # Update marker.
  my $common_count = @context_in_between - @after - @before;
  my $old_count = $other_marker->get_old_line_count () + $common_count;
  my $new_count = $other_marker->get_new_line_count () + $common_count;

  $additions->set_old_line_count ($old_count);
  $additions->set_new_line_count ($new_count);
  $marker->add_marker ($additions);

  # Update bare marker.
  my $new_before_context = $self->_get_before_context_from_lines ();
  my $new_after_context = $self->_get_after_context_from_lines ();
  my $line_no = @{$new_before_context};
  my $count = -@{$new_before_context} - @{$new_after_context};

  $additions->set_old_line_count ($count);
  $additions->set_new_line_count ($count);
  $additions->set_old_line_no ($line_no);
  $additions->set_new_line_no ($line_no);
  $bare_marker = $marker->clone ();
  $bare_marker->add_marker ($additions);
  $self->set_bare_marker ($bare_marker);

  return 1;
}

# Usable after cleaning up context.
sub _get_before_context_from_lines
{
  my ($self) = @_;
  my $lines = $self->get_lines ();
  my @context = ();

  foreach my $line (Kgps::Misc::first_n ($lines, 3))
  {
    last if ($line->get_sigil () != Kgps::CodeLine::Space);
    push (@context, $line);
  }

  return \@context;
}

# Usable after cleaning up context.
sub _get_after_context_from_lines
{
  my ($self) = @_;
  my $lines = $self->get_lines ();
  my @context = ();

  foreach my $line (reverse (Kgps::Misc::last_n ($lines, 3)))
  {
    last if ($line->get_sigil () != Kgps::CodeLine::Space);
    unshift (@context, $line);
  }

  return \@context;
}

1;
