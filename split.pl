#!/usr/bin/perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;
use warnings;
use v5.16;

use File::Path qw(make_path);
use File::Spec;
use IO::File;

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
package LocationMarker;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'LocationMarker');
  my $self =
  {
    'old_line_no' => undef,
    'old_line_count' => undef,
    'new_line_no' => undef,
    'new_line_count' => undef,
    'inline_context' => undef
  };

  $self = bless ($self, $class);

  return $self;
}

sub new_zero
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'LocationMarker');
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
  my $class = (ref ($self) or $self or 'LocationMarker');
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
}

sub get_old_line_no
{
  my ($self) = @_;

  return $self->{'old_line_no'};
}

sub inc_old_line_no
{
  my ($self) = @_;

  ++$self->{'old_line_no'};
}

sub set_old_line_count
{
  my ($self, $old_line_count) = @_;

  $self->{'old_line_count'} = $old_line_count;
}

sub get_old_line_count
{
  my ($self) = @_;

  return $self->{'old_line_count'};
}

sub inc_old_line_count
{
  my ($self) = @_;

  ++$self->{'old_line_count'};
}

sub set_new_line_no
{
  my ($self, $new_line_no) = @_;

  $self->{'new_line_no'} = $new_line_no;
}

sub get_new_line_no
{
  my ($self) = @_;

  return $self->{'new_line_no'};
}

sub inc_new_line_no
{
  my ($self) = @_;

  ++$self->{'new_line_no'};
}

sub set_new_line_count
{
  my ($self, $new_line_count) = @_;

  $self->{'new_line_count'} = $new_line_count;
}

sub get_new_line_count
{
  my ($self) = @_;

  return $self->{'new_line_count'};
}

sub inc_new_line_count
{
  my ($self) = @_;

  ++$self->{'new_line_count'};
}

sub set_inline_context
{
  my ($self, $inline_context) = @_;

  $self->{'inline_context'} = $inline_context;
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
}

1;

# Section describes the generated patch and its ancestor-descendant
# relation to other generated patches.
package Section;

sub new
{
  my ($type, $name, $index) = @_;
  my $class = (ref ($type) or $type or 'Section');
  my $self =
  {
    'name' => $name,
    'index' => $index,
    'subject' => undef,
    'author' => undef,
    'date' => undef,
    'subject' => undef,
    'message_lines' => undef,
  };

  $self = bless ($self, $class);

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

1;

# CodeLine is a representation of a single line of code in diff. It's
# the line in diff that starts with a single sigil (either +, - or
# space) and the rest of the line is the actual code.
package CodeLine;

use constant
{
  Plus => 0, # added line
  Minus => 1, # removed line
  Space => 2, # unchanged line
  Binary => 3  # binary line
};

my $type_to_char =
{
  Plus () => '+',
  Minus () => '-',
  Space () => ' '
};
my $char_to_type =
{
  '+' => Plus,
  '-' => Minus,
  ' ' => Space
};

sub get_char
{
  my ($type) = @_;

  if (exists ($type_to_char->{$type}))
  {
    return $type_to_char->{$type};
  }

  return undef;
}

sub get_type
{
  my ($char) = @_;

  if (exists ($char_to_type->{$char}))
  {
    return $char_to_type->{$char};
  }

  return undef;
}

sub new
{
  my ($type, $sigil, $line) = @_;
  my $class = (ref ($type) or $type or 'CodeLine');
  my $self =
  {
    'sigil' => $sigil,
    'line' => $line
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_sigil
{
  my ($self) = @_;

  return $self->{'sigil'};
}

sub get_line
{
  my ($self) = @_;

  return $self->{'line'};
}

1;

# CodeBase is a single chunk of changed code.
package CodeBase;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'CodeBase');
  my $self =
  {
    'lines' => []
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_lines
{
  my ($self) = @_;

  return $self->{'lines'};
}

sub push_line
{
  my ($self, $sigil, $code_line) = @_;
  my $lines = $self->get_lines ();
  my $line = CodeLine->new ($sigil, $code_line);

  push (@{$lines}, $line);
}

1;

# FinalCode is the final form of the single code chunk. It contains
# lines that already took the changes made in older generated patches
# into account.
package FinalCode;

use parent -norequire, qw(CodeBase);

sub new
{
  my ($type, $marker) = @_;
  my $class = (ref ($type) or $type or 'FinalCode');
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
    if ($line->get_sigil () == CodeLine::Space)
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
  my $additions = LocationMarker->new_zero ();
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
  $additions->set_old_line_count ($count);
  $additions->set_old_line_no ($line_no);
  $additions->set_new_line_count ($count);
  $additions->set_new_line_no ($line_no);
  $marker->add_marker ($additions);

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
  my $additions = LocationMarker->new_zero ();
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

  foreach my $line (@{$lines}[0 .. 2])
  {
    last unless (defined ($line));
    last if ($line->get_sigil () != CodeLine::Space);
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

  foreach my $line (reverse (@{$lines}[-3 .. -1]))
  {
    last unless (defined ($line));
    last if ($line->get_sigil () != CodeLine::Space);
    unshift (@context, $line);
  }

  return \@context;
}

1;

# SectionCode is a code chunk taken verbatim from the annotated patch.
package SectionCode;

use parent -norequire, qw(CodeBase);

sub new
{
  my ($type, $section) = @_;
  my $class = (ref ($type) or $type or 'SectionCode');
  my $self = $class->SUPER::new ();

  $self->{'section'} = $section;
  $self = bless ($self, $class);

  return $self;
}

sub get_section
{
  my ($self) = @_;

  return $self->{'section'};
}

1;

# LocationCodeCluster is a single code chunk that is being split
# between multiple sections.
package LocationCodeCluster;

sub new
{
  my ($type, $marker) = @_;
  my $class = (ref ($type) or $type or 'LocationCodeCluster');
  my $self =
  {
    'marker' => $marker,
    'section_codes' => []
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_section_codes
{
  my ($self) = @_;

  return $self->{'section_codes'};
}

sub push_section_code
{
  my ($self, $new_code) = @_;
  my $codes = $self->get_section_codes ();

  push (@{$codes}, $new_code);
}

sub get_marker
{
  my ($self) = @_;

  return $self->{'marker'};
}

1;

# DiffHeader is a representation of lines that come before the
# description of actual changes in the file. These are lines that look
# like:
#
# diff --git a/.bzrignore.moved b/.bzrignore.moved
# new file mode 100644
# index 0000000..f852cf1
package DiffHeader;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'DiffHeader');
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

# DiffBase is a base package for either textual or binary diffs.
package DiffBase;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'DiffBase');
  my $self =
  {
    'header' => undef
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_header
{
  my ($self) = @_;

  return $self->{'header'};
}

sub set_header
{
  my ($self, $header) = @_;

  $self->{'header'} = $header;
}

sub postprocess
{
  my ($self, $sections_array, $sections_hash) = @_;

  return $self->_postprocess_vfunc ($sections_array, $sections_hash);
}

1;

package TextFileStatSignsBase;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'TextFileStatSignsBase');
  my $self = {};

  $self = bless ($self, $class);

  return $self;
}

sub fill_context_info
{
  my ($self, $stat_render_context) = @_;

  $self->_fill_context_info_vfunc ($stat_render_context);
}

sub to_string
{
  my ($self, $stat_render_context) = @_;

  return $self->_to_string_vfunc ($stat_render_context);
}

1;

package TextFileStatSignsReal;

use parent -norequire, qw(TextFileStatSignsBase);

sub new
{
  my ($type, $insertions, $deletions) = @_;
  my $class = (ref ($type) or $type or 'TextFileStatSignsReal');
  my $self = $class->SUPER::new ();

  $self->{'insertions'} = $insertions;
  $self->{'deletions'} = $deletions;
  $self = bless ($self, $class);

  return $self;
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $total = $self->_get_insertions () + $self->_get_deletions ();

  $stat_render_context->feed_lines_changed_count ($total);
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $insertions = $self->_get_insertions ();
  my $deletions = $self->_get_deletions ();
  my $total = $insertions + $deletions;

  return $stat_render_context->render_text_rest ($total, $insertions, $deletions);
}

sub _get_insertions
{
  my ($self) = @_;

  return $self->{'insertions'};
}

sub _get_deletions
{
  my ($self) = @_;

  return $self->{'deletions'};
}

1;

# FileStatBase contains information about single file modification. It
# is a base package for representation of a line like:
#
# foo/file | 26 +
#
# or
#
# bar/file | Bin 64 -> 0 bytes
package FileStatBase;

use constant
{
  RelevantNo => 0,
  RelevantYes => 1,
  RelevantMaybe => 2
};

sub new
{
  my ($type, $path) = @_;
  my $class = (ref ($type) or $type or 'FileStatBase');
  my $self = {
    'path' => $path
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_path
{
  my ($self) = @_;

  return $self->{'path'};
}

sub is_relevant_for_path
{
  my ($self, $full_path) = @_;
  my $path = $self->get_path ();

  if ($path eq $full_path)
  {
    return RelevantYes;
  }

  my (undef, $full_dir, $full_basename) = File::Spec->splitpath ($full_path);
  my (undef, $dir, $basename) = File::Spec->splitpath ($path);

  if ($basename ne $full_basename)
  {
    return RelevantNo;
  }

  my @full_dirs = reverse (File::Spec->splitdir ($full_dir));
  my @dirs = reverse (File::Spec->splitdir ($dir));
  my $last_idx = scalar (@full_dirs);
  if ($last_idx > scalar (@dirs))
  {
    $last_idx = scalar (@dirs);
  }
  # We want index of last item in the array so decrement by one. We
  # want to skip comparing last item in the array, because it may be
  # '...', so decrement by one again.
  $last_idx -= 2;

  for my $idx (0 .. $last_idx)
  {
    if ($full_dirs[$idx] ne $dirs[$idx])
    {
      return RelevantNo;
    }
  }
  if ($dirs[$last_idx + 1] eq '...')
  {
    return RelevantMaybe;
  }
  if (scalar (@dirs) != scalar (@full_dirs))
  {
    return RelevantNo;
  }
  if ($dirs[$last_idx + 1] ne $full_dirs[$last_idx + 1])
  {
    return RelevantNo;
  }

  return RelevantYes;
}

sub fill_context_info
{
  my ($self, $stat_render_context) = @_;

  $stat_render_context->feed_path_length (length ($self->get_path ()));
  $self->_fill_context_info_vfunc ($stat_render_context);
}

sub to_string
{
  my ($self, $stat_render_context) = @_;

  return $self->_to_string_vfunc ($stat_render_context);
}

1;

# TextFileStat contains information stored in line like:
#
# foo/file | 26 +
package TextFileStat;

use parent -norequire, qw(FileStatBase);

sub new
{
  my ($type, $path, $signs) = @_;
  my $class = (ref ($type) or $type or 'TextFileStat');
  my $self = $class->SUPER::new ($path);

  $self->{'signs'} = $signs;
  $self = bless ($self, $class);

  return $self;
}

sub get_lines_changed_count
{
  my ($self) = @_;

  return $self->{'lines_changed_count'};
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $signs = $self->_get_signs ();

  $signs->fill_context_info ($stat_render_context);
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $signs = $self->_get_signs ();

  return $signs->to_string ($stat_render_context);
}

sub _get_signs
{
  my ($self) = @_;

  return $self->{'signs'};
}

1;

package NewAndGoneDetails;

use constant
{
  Create => 0,
  Delete => 1
};

sub new
{
  my ($type, $action, $mode) = @_;
  my $class = (ref ($type) or $type or 'NewAndGoneDetails');
  my $self = {
    'action' => $action,
    'mode' => $mode
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_action
{
  my ($self) = @_;

  return $self->{'action'};
}

sub get_mode
{
  my ($self) = @_;

  return $self->{'mode'};
}

1;

# BinaryFileStat contains information stored in line like:
#
# bar/file | Bin 64 -> 0 bytes
package BinaryFileStat;

use parent -norequire, qw(FileStatBase);

sub new
{
  my ($type, $path, $from_size, $to_size) = @_;
  my $class = (ref ($type) or $type or 'BinaryFileStat');
  my $self = $class->SUPER::new ($path);

  $self->{'from_size'} = $from_size;
  $self->{'to_size'} = $to_size;
  $self = bless ($self, $class);

  return $self;
}

sub get_from_size
{
  my ($self) = @_;

  return $self->{'from_size'};
}

sub get_to_size
{
  my ($self) = @_;

  return $self->{'to_size'};
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $from_size = $self->get_from_size ();
  my $to_size = $self->get_to_size ();
  my $bytes_word = 'bytes';

  if ($to_size == 0)
  {
    chop ($bytes_word);
  }

  return "Bin $from_size -> $to_size $bytes_word";
}

1;

package TextFileStatSignsDrawn;

use parent -norequire, qw(TextFileStatSignsBase);

sub new
{
  my ($type, $lines_changed_count, $plus_count, $minus_count) = @_;
  my $class = (ref ($type) or $type or 'TextFileStatSignsDrawn');
  my $self = $class->SUPER::new ();

  $self->{'lines_changed_count'} = $lines_changed_count;
  $self->{'plus_count'} = $plus_count;
  $self->{'minus_count'} = $minus_count;
  $self = bless ($self, $class);

  return $self;
}

sub _fill_context_info_vfunc
{
  my ($self, $stat_render_context) = @_;
  my $lines_changed_count = $self->_get_lines_changed_count ();

  $stat_render_context->feed_lines_changed_count ($lines_changed_count);
}

sub _to_string_vfunc
{
  my ($self, $stat_render_context) = @_;

  return '';
}

sub _get_lines_changed_count
{
  my ($self) = @_;

  return $self->{'lines_changed_count'};
}

1;

# BasenameStats contains information about modifications of all file
# with certain basename. So for changes like:
#
# foo/file | 26 +
# bar/file | Bin 64 -> 0 bytes
# bar/aaaa | 2  +-
#
# one BasenameStats instance will contain information about foo/file
# and bar/file, and another instance - about bar/aaaa.
package BasenameStats;

sub new
{
  my ($type) = @_;

  return _new_with_stats ($type, {});
}

sub get_bin_stats_for_basename
{
  my ($self, $basename) = @_;
  my $stats = $self->_get_stats ();
  my $bin_stats = [];

  if (exists ($stats->{$basename}))
  {
    for my $stat (@{$stats->{$basename}})
    {
      # bleh
      if ($stat->isa ('BinaryFileStat'))
      {
        push (@{$bin_stats}, $stat);
      }
    }
  }

  return $bin_stats;
}

sub add_stat
{
  my ($self, $stat) = @_;
  my $stats = $self->_get_stats ();
  my $path = $stat->get_path ();
  my $basename = (File::Spec->splitpath ($path))[2];

  unless (exists ($stats->{$basename}))
  {
    $stats->{$basename} = [];
  }

  push (@{$stats->{$basename}}, $stat);
}

sub add_file_stats
{
  my ($self, $path, $stats_line) = @_;
  my $stat = undef;

  if ($stats_line =~ /^\s*(\d+) (\+*)(-*)$/a)
  {
    my $plus_count = 0;
    my $minus_count = 0;

    if (defined ($2))
    {
      $plus_count = length ($2);
    }
    if (defined ($3))
    {
      $minus_count = length ($3);
    }

    my $signs = TextFileStatSignsDrawn->new ($1, $plus_count, $minus_count);

    $stat = TextFileStat->new ($path, $signs);
  }
  elsif ($stats_line =~ /^Bin (\d+) -> \d+ bytes?$/)
  {
    $stat = BinaryFileStat->new ($path, $1, $2);
  }

  unless (defined ($stat))
  {
    return 0;
  }

  $self->add_stat ($stat);
  return 1;
}

sub merge
{
  my ($self, $other) = @_;
  my $self_stats = $self->_get_stats ();
  my $other_stats = $other->_get_stats ();
  my $merged_stats = {};

  for my $basename (keys (%{$self_stats}), keys (%{$other_stats}))
  {
    my $self_array = [];
    my $other_array = [];

    if (exists ($self_stats->{$basename}))
    {
      $self_array = $self_stats->{$basename};
    }
    if (exists ($other_stats->{$basename}))
    {
      $self_array = $other_stats->{$basename};
    }

    $merged_stats->{$basename} = [@{$self_array}, @{$other_array}];
  }

  return BasenameStats->_new_with_stats ($merged_stats);
}

sub fill_context_info
{
  my ($self, $stat_render_context) = @_;

  for my $file_stats (values (%{$self->_get_stats ()}))
  {
    for my $file_stat (@{$file_stats})
    {
      $file_stat->fill_context_info ($stat_render_context);
    }
  }
}

sub to_lines
{
  my ($self, $stat_render_context) = @_;
  my %all_stats = ();

  for my $file_stats (values (%{$self->_get_stats ()}))
  {
    for my $file_stat (@{$file_stats})
    {
      $all_stats{$file_stat->get_path ()} = $file_stat;
    }
  }

  my @lines = ();
  for my $path (sort (keys (%all_stats)))
  {
    my $file_stat = $all_stats{$path};

    push (@lines, $stat_render_context->render_stat ($file_stat));
  }

  return @lines;
}

sub _get_stats
{
  my ($self) = @_;

  return $self->{'stats'};
}

sub _new_with_stats
{
  my ($type, $stats) = @_;
  my $class = (ref ($type) or $type or 'BasenameStats');
  my $self = {
    # basename to array of FileStatBase
    'stats' => $stats,
  };

  $self = bless ($self, $class);

  return $self;
}

1;

package ListingSummary;

sub new
{
  my ($type) = @_;

  return _new_with_numbers ($type, 0, 0, 0);
}

sub get_files_changed_count
{
  my ($self) = @_;

  return $self->{'files_changed_count'};
}

sub set_files_changed_count
{
  my ($self, $count) = @_;

  $self->{'files_changed_count'} = $count;
}

sub get_insertions
{
  my ($self) = @_;

  return $self->{'insertions'};
}

sub set_insertions
{
  my ($self, $count) = @_;

  $self->{'insertions'} = $count;
}

sub get_deletions
{
  my ($self) = @_;

  return $self->{'deletions'};
}

sub set_deletions
{
  my ($self, $count) = @_;

  $self->{'deletions'} = $count;
}

sub merge
{
  my ($self, $other) = @_;
  my $merged_files_changed_count = $self->get_files_changed_count () + $other->get_files_changed_count ();
  my $merged_insertions = $self->get_insertions () + $other->get_insertions ();
  my $merged_deletions = $self->get_deletions () + $other->get_deletions ();

  return ListingSummary->_new_with_numbers ($merged_files_changed_count, $merged_insertions, $merged_deletions);
}

sub to_string
{
  my ($self) = @_;
  my $files_changed_count = $self->get_files_changed_count ();
  my $insertions = $self->get_insertions ();
  my $deletions = $self->get_deletions ();
  my $files_word = 'files';

  if ($files_changed_count == 1)
  {
    chop ($files_word);
  }

  my $files_changed_part = " $files_changed_count $files_word changed";
  my $insertions_word = 'insertions';

  if ($insertions == 1)
  {
    chop ($insertions_word);
  }

  my $insertions_part = '';

  if ($insertions > 0 or $deletions == 0)
  {
    $insertions_part = ", $insertions $insertions_word(+)";
  }

  my $deletions_word = 'deletions';

  if ($deletions == 1)
  {
    chop ($deletions_word);
  }

  my $deletions_part = '';

  if ($deletions > 0 or $insertions == 0)
  {
    $deletions_part = ", $deletions $deletions_word(-)";
  }

  return "$files_changed_part$insertions_part$deletions_part";
}

sub _new_with_numbers
{
  my ($type, $files_changed_count, $insertions, $deletions) = @_;
  my $class = (ref ($type) or $type or 'ListingSummary');
  my $self = {
    'files_changed_count' => $files_changed_count,
    'insertions' => $insertions,
    'deletions' => $deletions
  };

  $self = bless ($self, $class);

  return $self;
}

1;

package NewAndGoneFiles;

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

  return NewAndGoneFiles->_new_with_files ($merged_files);
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

    if ($action == NewAndGoneDetails::Create)
    {
      $action_str = 'create';
    }
    elsif ($action == NewAndGoneDetails::Delete)
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
  my $class = (ref ($type) or $type or 'NewAndGoneFiles');
  my $self = {
    # path to NewAndGoneDetails
    'files' => $files
  };

  $self = bless ($self, $class);

  return $self;
}

1;

# ListingInfo contains the listing information of the patch. So it is
# a representation of lines in the patch like:
#
# .htaccess | 26 +
# gedit     | Bin 64 -> 0 bytes
# 1 file changed, 26 insertions(+), 0 deletions(-)
# delete mode 100755 gedit
package ListingInfo;

sub new
{
  my ($type) = @_;

  return _new_with_items ($type, BasenameStats->new (), ListingSummary->new (), NewAndGoneFiles->new ());
}

sub get_per_basename_stats
{
  my ($self) = @_;

  return $self->{'per_basename_stats'};
}

sub get_summary
{
  my ($self) = @_;

  return $self->{'summary'};
}

sub get_new_and_gone_files
{
  my ($self) = @_;

  return $self->{'new_and_gone_files'};
}

sub merge
{
  my ($self, $other) = @_;
  my $merged_per_basename_stats = $self->get_per_basename_stats ()->merge ($other->get_per_basename_stats ());
  my $merged_summary = $self->get_summary ()->merge ($other->get_summary ());
  my $merged_new_and_gone_files = $self->get_new_and_gone_files ()->merge ($other->get_new_and_gone_files ());

  unless (defined ($merged_per_basename_stats) and defined ($merged_summary) and defined ($merged_new_and_gone_files))
  {
    return undef;
  }

  return ListingInfo->_new_with_items ($merged_per_basename_stats, $merged_summary, $merged_new_and_gone_files);
}

sub _new_with_items
{
  my ($type, $per_basename_stats, $summary, $new_and_gone_files) = @_;
  my $class = (ref ($type) or $type or 'ListingInfo');
  my $self = {
    'per_basename_stats' => $per_basename_stats,
    'summary' => $summary,
    'new_and_gone_files' => $new_and_gone_files,
  };

  $self = bless ($self, $class);

  return $self;
}

1;

# TextDiff is a representation of a single diff of a text file.
package TextDiff;

use parent -norequire, qw(DiffBase);

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'TextDiff');
  my $self = $class->SUPER::new ();

  $self->{'clusters'} = [];
  $self->{'from'} = undef;
  $self->{'to'} = undef;

  $self = bless ($self, $class);

  return $self;
}

sub get_to
{
  my ($self) = @_;

  return $self->{'to'};
}

sub set_to
{
  my ($self, $to) = @_;

  $self->{'to'} = $to;
}

sub get_from
{
  my ($self) = @_;

  return $self->{'from'};
}

sub set_from
{
  my ($self, $from) = @_;

  $self->{'from'} = $from;
}

sub get_clusters
{
  my ($self) = @_;

  return $self->{'clusters'};
}

sub push_cluster
{
  my ($self, $new_cluster) = @_;
  my $clusters = $self->get_clusters ();

  push (@{$clusters}, $new_cluster);
}

sub _postprocess_vfunc
{
  my ($self, $sections_array, $sections_hash) = @_;
  # Keeps arrays of final codes.
  my $for_raw = $self->_create_array_for_each_section ($sections_array);
  # Additions for markers in code clusters in file to propagate line
  # changes done in previous clusters.
  my $marker_additions = $self->_create_marker_additions_for_each_section ($sections_array);

  foreach my $cluster (@{$self->get_clusters ()})
  {
    my $marker = $cluster->get_marker ();
    # Markers for each section for single code cluster. Each section
    # ends up having different numbers in its markers for the same
    # code cluster.
    my $markers = $self->_create_markers_for_each_section ($marker, $sections_array, $marker_additions);
    # The initial contexts for each section. Each section ends up
    # having different context in code cluster.
    my $before_contexts = $self->_create_array_for_each_section ($sections_array);
    # Array of final codes for each section. One final code for each
    # chunk of code delimited with SECTION comments.
    my $final_codes = $self->_create_array_for_each_section ($sections_array);

    foreach my $code (@{$cluster->get_section_codes ()})
    {
      my $section = $code->get_section ();
      my $section_name = $section->get_name ();
      my $lines_of_end_context_count = 0;
      my $final_marker = $markers->{$section_name}->clone ();
      my $final_code = FinalCode->new ($final_marker);

      # Setup initial context for final code - will be used when
      # cleaning up context of the final code later.
      {
        my @context_copy = @{$before_contexts->{$section_name}};

        $final_code->set_before_context (\@context_copy);
      }
      # Reset final code's marker line counts to zero. They will be
      # updated as we iterate through lines in code chunk.
      $final_marker->set_old_line_count (0);
      $final_marker->set_new_line_count (0);

      foreach my $line (@{$code->get_lines ()})
      {
        $final_code->push_line ($line->get_sigil (), $line->get_line ());
        # Adapt markers for other sections.
        $self->_adapt_markers ($section, $line, $markers, $sections_hash);
        # Adapt marker for current final code.
        $self->_adapt_final_marker ($line, $final_marker);
        # Adapt initial contexts for other sections.
        $self->_adapt_before_contexts ($section, $line, $before_contexts, $sections_hash);
        # Maybe push an after context to previous final codes. Will be
        # used when cleaning up context of each final code later.
        $self->_push_after_context ($section, $line, $final_codes, $sections_hash);
      }
      push (@{$final_codes->{$section_name}}, $final_code);
    }

    # Cleanup context of each final code and try to merge every
    # adjacent final code. Afterwards add them to array to create a
    # raw representation of final code.
    foreach my $section (@{$sections_array})
    {
      my $section_name = $section->get_name ();
      my $final_codes_for_section = $final_codes->{$section_name};

      foreach my $final_code (@{$final_codes_for_section})
      {
        $final_code->cleanup_context ();
      }

      my $new_final_codes_for_section = [];
      my $index = 0;

      while ($index < @{$final_codes_for_section})
      {
        my $final_code = $final_codes_for_section->[$index];
        my $next_index = $index + 1;

        while ($next_index < @{$final_codes_for_section})
        {
          my $next_final_code = $final_codes_for_section->[$next_index];

          last unless ($final_code->merge_final_code ($next_final_code));
          ++$next_index;
        }
        $index = $next_index;
        push (@{$new_final_codes_for_section}, $final_code);
      }

      if (@{$new_final_codes_for_section})
      {
        push (@{$for_raw->{$section_name}}, @{$new_final_codes_for_section});
      }
    }
  }

  # Prepare raw representations of final codes. When file is added or
  # deleted the code doing it has to have a different header - the
  # outer one. The rest of codes are making changes to already/still
  # existing file, so they need ordinary header - the inner one. Also,
  # for such files small corrections are needed to inner codes,
  # because of using special 0,0 marker value denoting file
  # creation/deletion. That special value is causing off-by-one errors
  # if not corrected in inner patches.
  my $header = $self->get_header ();
  my $action = $header->get_action ();
  my $inner_index_first = 0;
  my $inner_index_last = @{$sections_array} - 1;
  my $outer_section_index = undef;
  my $git_raw = {};
  my $final_inner_correction = LocationMarker->new_zero ();
  # Git version of a special header for sections doing the file
  # creation or deletion.
  my $git_header_outer = $self->_get_git_unidiff_header_for_outer ($header);
  # Git version of a typical header for section doing some changes to
  # a file.
  my $git_header_inner = $self->_get_git_unidiff_header_for_inner ($header);

  unless (defined ($action))
  {
    my $oldest_section_index_in_this_diff = 0;

    foreach my $section (@{$sections_array})
    {
      my $section_name = $section->get_name ();

      last if (@{$for_raw->{$section_name}});

      ++$oldest_section_index_in_this_diff;
    }

    die "SHOULD NOT HAPPEN" if $oldest_section_index_in_this_diff >= @{$sections_array};
  }
  elsif ($action eq "new file")
  {
    my $oldest_section_index_in_this_diff = 0;

    foreach my $section (@{$sections_array})
    {
      my $section_name = $section->get_name ();

      last if (@{$for_raw->{$section_name}});

      ++$oldest_section_index_in_this_diff;
    }

    die "SHOULD NOT HAPPEN" if $oldest_section_index_in_this_diff >= @{$sections_array};
    $inner_index_first = $oldest_section_index_in_this_diff + 1;
    $outer_section_index = $oldest_section_index_in_this_diff;
    $final_inner_correction->inc_old_line_no ();
  }
  elsif ($action eq "deleted file")
  {
    my $youngest_section_index_in_this_diff = -1;

    foreach my $section (reverse (@{$sections_array}))
    {
      my $section_name = $section->get_name ();

      last if (@{$for_raw->{$section_name}});

      --$youngest_section_index_in_this_diff;
    }

    die "SHOULD NOT HAPPEN" if -$youngest_section_index_in_this_diff > @{$sections_array};
    $inner_index_last = @{$sections_array} - 1 + $youngest_section_index_in_this_diff;
    $outer_section_index = $youngest_section_index_in_this_diff;
    $final_inner_correction->inc_new_line_no ();
  }

  my $stats = {};

  if (defined ($outer_section_index))
  {
    my $outer_section_name = $sections_array->[$outer_section_index]->get_name ();
    my $final_codes = $for_raw->{$outer_section_name};

    $git_raw->{$outer_section_name} = $self->_get_raw_text_for_final_codes ($git_header_outer, $final_codes);
    $stats->{$outer_section_name} = $self->_get_stats_for_final_codes ($final_codes);
  }

  my @inner_sections_slice = @{$sections_array}[$inner_index_first .. $inner_index_last];

  foreach my $section (@inner_sections_slice)
  {
    my $section_name = $section->get_name ();
    my $final_codes = $for_raw->{$section_name};

    foreach my $final_code (@{$final_codes})
    {
      my $final_marker = $final_code->get_marker ();

      $final_marker->add_marker ($final_inner_correction);
    }

    next unless (@{$final_codes});
    $git_raw->{$section_name} = $self->_get_raw_text_for_final_codes ($git_header_inner, $final_codes);
    $stats->{$section_name} = $self->_get_stats_for_final_codes ($final_codes);
  }

  return {'git-raw' => $git_raw, 'stats' => $stats};
}

sub _get_git_unidiff_header_for_outer
{
  my ($self, $header) = @_;
  my $from = $self->_maybe_prefix ('a', $self->get_from ());
  my $to = $self->_maybe_prefix ('b', $self->get_to ());
  my $action = $header->get_action ();
  my $mode = $header->get_mode ();
  my @lines = (
    "diff --git $from $to"
  );

  if (defined ($action))
  {
    push (@lines,
          "$action mode $mode",
          "index 111111..222222");
  }
  else
  {
    push (@lines,
          "index 111111..222222 $mode");
  }
  push (@lines,
        "--- $from",
        "+++ $to");
  return join ("\n", @lines);
}

sub _get_git_unidiff_header_for_inner
{
  my ($self, $header) = @_;
  my $file = $self->_get_changed_file ();
  my $from = $self->_maybe_prefix ('a', $file);
  my $to = $self->_maybe_prefix ('b', $file);
  my $mode = $header->get_mode ();

  return join ("\n",
               "diff --git $from $to",
               "index 111111..222222 $mode",
               "--- $from",
               "+++ $to");
}

sub _get_changed_file
{
  my ($self) = @_;
  my $file = $self->get_to ();

  if ($file eq '/dev/null')
  {
    $file = $self->get_from ();
  }

  return $file;
}

sub _maybe_prefix
{
  my ($self, $prefix, $path) = @_;

  if ($path eq '/dev/null')
  {
    return $path;
  }
  else
  {
    return $prefix . '/' . $path;
  }
}

sub _create_array_for_each_section
{
  my ($self, $sections_array) = @_;
  my %contexts = map { $_->get_name () => [] } @{$sections_array};

  return \%contexts;
}

sub _create_marker_additions_for_each_section
{
  my ($self, $sections_array) = @_;
  my %additions = map { $_->get_name () => LocationMarker->new_zero () } @{$sections_array};

  return \%additions;
}

sub _create_markers_for_each_section
{
  my ($self, $marker, $sections_array, $marker_additions) = @_;
  my $markers = {};

  foreach my $section (@{$sections_array})
  {
    my $section_name = $section->get_name ();
    my $addition = $marker_additions->{$section_name};
    my $section_marker = $marker->clone ();

    $section_marker->add_marker ($addition);
    $markers->{$section_name} = $section_marker;
  }

  return $markers;
}

sub _adapt_markers
{
  my ($self, $current_section, $current_line, $markers, $sections_hash) = @_;
  my @all_section_names = keys (%{$markers});
  my $sigil = $current_line->get_sigil ();

  foreach my $section_name (@all_section_names)
  {
    my $marker = $markers->{$section_name};
    my $section = $sections_hash->{$section_name};

    if ($sigil == CodeLine::Plus)
    {
      if ($section->is_younger_than ($current_section))
      {
        # old line no + 1
        # new line no + 1
        $marker->inc_old_line_no ();
        $marker->inc_new_line_no ();
      }
      elsif ($section->is_older_than ($current_section))
      {
        # nothing changes
      }
      else # same section
      {
        $marker->inc_new_line_no ();
        # new line no + 1
      }
    }
    elsif ($sigil == CodeLine::Minus)
    {
      if ($section->is_younger_than ($current_section))
      {
        # nothing changes
      }
      elsif ($section->is_older_than ($current_section))
      {
        $marker->inc_old_line_no ();
        $marker->inc_new_line_no ();
        # old line no + 1
        # new line no + 1
      }
      else # same section
      {
        $marker->inc_old_line_no ()
        # old line no + 1
      }
    }
    elsif ($sigil == CodeLine::Space)
    {
      $marker->inc_old_line_no ();
      $marker->inc_new_line_no ();
      if ($section->is_younger_than ($current_section))
      {
        # old line no + 1
        # new line no + 1
      }
      elsif ($section->is_older_than ($current_section))
      {
        # old line no + 1
        # new line no + 1
      }
      else # same section
      {
        # old line no + 1
        # new line no + 1
      }
    }
  }
}

sub _adapt_final_marker
{
  my ($self, $current_line, $marker) = @_;
  my $sigil = $current_line->get_sigil ();

  if ($sigil == CodeLine::Plus)
  {
    $marker->inc_new_line_count ();
  }
  elsif ($sigil == CodeLine::Minus)
  {
    $marker->inc_old_line_count ();
  }
  elsif ($sigil == CodeLine::Space)
  {
    $marker->inc_old_line_count ();
    $marker->inc_new_line_count ();
  }
}

sub _adapt_before_contexts
{
  my ($self, $current_section, $current_line, $before_contexts, $sections_hash) = @_;
  my @all_section_names = keys (%{$before_contexts});
  my $sigil = $current_line->get_sigil ();

  foreach my $section_name (@all_section_names)
  {
    my $before_context = $before_contexts->{$section_name};
    my $section = $sections_hash->{$section_name};

    if ($sigil == CodeLine::Space or
        ($section->is_older_than ($current_section) and $sigil == CodeLine::Minus) or
        ($section->is_younger_than ($current_section) and $sigil == CodeLine::Plus))
    {
      $self->_append_context ($before_context, CodeLine->new (CodeLine::Space, $current_line->get_line ()));
    }
  }
}

sub _push_after_context
{
  my ($self, $current_section, $current_line, $final_codes, $sections_hash) = @_;
  my @all_section_names = keys (%{$final_codes});
  my $sigil = $current_line->get_sigil ();

  foreach my $section_name (@all_section_names)
  {
    my $section = $sections_hash->{$section_name};

    if ($sigil == CodeLine::Space or
        ($section->is_older_than ($current_section) and $sigil == CodeLine::Minus) or
        ($section->is_younger_than ($current_section) and $sigil == CodeLine::Plus))
    {
      foreach my $final_code (@{$final_codes->{$section_name}})
      {
        $final_code->push_after_context_line (CodeLine->new (CodeLine::Space, $current_line->get_line ()));
      }
    }
  }
}

sub _append_context
{
  my ($self, $context, $line) = @_;

  push (@{$context}, $line);
  while (@{$context} > 3)
  {
    shift (@{$context});
  }
}

sub _get_raw_text_for_final_codes
{
  my ($self, $header, $final_codes) = @_;
  my @raw_codes = map { $self->_get_raw_text_for_final_code ($_) } @{$final_codes};

  return join ("\n",
               $header,
               @raw_codes);
}

sub _get_raw_text_for_final_code
{
  my ($self, $final_code) = @_;
  my $marker = $final_code->get_marker ();
  my $lines = $final_code->get_lines ();
  my @raw_lines = $self->_lines_to_string ($lines);

  return join ("\n",
               $self->_marker_to_string ($marker),
               @raw_lines);
}

sub _lines_to_string
{
  my ($self, $lines) = @_;

  return map { CodeLine::get_char ($_->get_sigil ()) . $_->get_line () } @{$lines};
}

sub _get_stats_for_final_codes
{
  my ($self, $final_codes) = @_;
  my $listing_info = ListingInfo->new ();
  my $per_basename_stats = $listing_info->get_per_basename_stats ();
  my $summary = $listing_info->get_summary ();
  my $new_and_gone_files = $listing_info->get_new_and_gone_files ();
  my $header = $self->get_header ();
  my $mode = $header->get_mode ();
  my $insertions = 0;
  my $deletions = 0;

  for my $final_code (@{$final_codes})
  {
    for my $line (@{$final_code->get_lines ()})
    {
      my $sigil = $line->get_sigil ();
      my $raw_sign = CodeLine::get_char ($sigil);
      my $code_line = $line->get_line ();

      if ($sigil == CodeLine::Plus)
      {
        ++$insertions;
      }
      elsif ($sigil == CodeLine::Minus)
      {
        ++$deletions;
      }
    }
  }

  my $signs = TextFileStatSignsReal->new ($insertions, $deletions);
  my $path = $self->_get_changed_file ();

  $summary->set_files_changed_count (1);
  $summary->set_insertions ($insertions);
  $summary->set_deletions ($deletions);
  $per_basename_stats->add_stat (TextFileStat->new ($path, $signs));

  if ($self->get_from () eq '/dev/null')
  {
    my $details = NewAndGoneDetails->new (NewAndGoneDetails::Create, $mode);

    $new_and_gone_files->add_details ($self->get_to (), $details);
  }
  elsif ($self->get_to () eq '/dev/null')
  {
    my $details = NewAndGoneDetails->new (NewAndGoneDetails::Delete, $mode);

    $new_and_gone_files->add_details ($self->get_from (), $details);
  }

  return $listing_info;
}

sub _marker_to_string
{
  my ($self, $marker) = @_;
  my @parts = ();
  my $old_line_count = $marker->get_old_line_count ();
  my $new_line_count = $marker->get_new_line_count ();
  my $inline_context = $marker->get_inline_context ();

  push (@parts, '@@ -', $marker->get_old_line_no ());
  if ($old_line_count != 1)
  {
    push (@parts, ',', $old_line_count);
  }
  push (@parts, ' +', $marker->get_new_line_no ());
  if ($new_line_count != 1)
  {
    push (@parts, ',', $new_line_count);
  }
  push (@parts, ' @@');

  if (defined ($inline_context))
  {
    push (@parts, ' ', $inline_context);
  }

  return join ('', @parts);
}

1;

# BinaryDiff is a representation of a diff of a binary file.
package BinaryDiff;

use parent -norequire, qw(DiffBase);

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'BinaryDiff');
  my $self = $class->SUPER::new ();

  $self->{'code'} = undef;
  $self->{'listing_info'} = undef;
  $self = bless ($self, $class);

  return $self;
}

sub get_code
{
  my ($self) = @_;

  return $self->{'code'};
}

sub set_code
{
  my ($self, $code) = @_;

  $self->{'code'} = $code;
}

sub get_listing_info
{
  my ($self) = @_;

  return $self->{'listing_info'};
}

sub set_listing_info
{
  my ($self, $listing_info) = @_;

  $self->{'listing_info'} = $listing_info;
}

sub _postprocess_vfunc
{
  my ($self, $sections_array, $sections_hash) = @_;
  my $code = $self->get_code ();
  my $name = $code->get_section ()->get_name ();
  my $raw = join ("\n",
                  $self->_get_diff_git_header (),
                  "GIT binary patch",
                  @{$self->_get_raw_lines ($code->get_lines ())},
                  "");
  my $raw_diff = {$name => $raw};
  my $big_listing_info = $self->get_listing_info ();
  my $big_new_and_gone_files = $big_listing_info->new_and_gone_files ();
  my $big_per_basename_stats = $big_listing_info->get_per_basename_stats ();
  my $listing_info = ListingInfo->new ();
  my $per_basename_stats = $listing_info->get_per_basename_stats ();
  my $summary = $listing_info->get_summary ();
  my $new_and_gone_files = $listing_info->new_and_gone_files ();
  my $header = $self->get_header ();
  my $path = $header->get_a ();
  my $details_from_big = $big_new_and_gone_files->get_details_for_path ($path);
  my $basename = (File::Spec->splitpath ($path))[2];
  my $maybe_relevant = undef;

  for my $bin_stat (@{$big_per_basename_stats->get_bin_stats_for_basename ($basename)})
  {
    my $relevancy = $bin_stat->is_relevant_for_path ($path);

    if ($relevancy == FileStatBase::RelevantYes)
    {
      $per_basename_stats->add_stat ($bin_stat);
      $maybe_relevant = undef;
      last;
    }
    if ($relevancy == FileStatBase::RelevantMaybe)
    {
      if (defined ($maybe_relevant))
      {
        # Meh, warn about ambiguity in overlong paths, maybe consider
        # adding a helper to GIT binary patch section.
        #
        # Try more heuristics with checking if the file is created or
        # deleted. Created files usually have from size 0, and deleted
        # files have to size 0.
      }
      else
      {
        $maybe_relevant = BinaryFileStat->new ($path, $bin_stat->get_from_size, $bin_stat->get_to_size ());
      }
    }
  }
  if (defined ($maybe_relevant))
  {
    $per_basename_stats->add_stat ($maybe_relevant);
  }

  $summary->set_files_changed_count (1);
  if (defined ($details_from_big))
  {
    $new_and_gone_files->add_details ($path, $details_from_big);
  }

  my $stats = {$name => $listing_info};
  my $raw_diffs_and_modes = {
    'git-raw' => $raw_diff,
    'stats' => $stats
  };

  return $raw_diffs_and_modes;
}

sub _get_diff_git_header
{
  my ($self) = @_;
  my $header = $self->get_header ();
  my $a = 'a/' . $header->get_a ();
  my $b = 'b/' . $header->get_b ();
  my $action = $header->get_action ();
  my $mode = $header->get_mode ();
  my $index_from = $header->get_index_from ();
  my $index_to = $header->get_index_to ();

  if (defined ($action))
  {
    return join ("\n",
                 "diff --git $a $b",
                 "$action mode $mode",
                 "index $index_from..$index_to");
  }
  return join ("\n",
               "diff --git $a $b",
               "index $index_from..$index_to $mode");
}

sub _get_raw_lines
{
  my ($self, $lines) = @_;
  my @raw_lines = map { $_->get_line () } @{$lines};

  return \@raw_lines;
}

1;

# Patch is a representation of the annotated patch.
package Patch;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Patch');
  my $self =
  {
    'author' => undef,
    'from_date' => undef,
    'patch_date' => undef,
    'subject' => undef,
    'message_lines' => [],
    'diffs' => [],
    'sections_ordered' => [],
    'sections_unordered' => {},
    'raw_diffs_and_modes' => {}
  };

  $self = bless ($self, $class);

  return $self;
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

sub get_from_date
{
  my ($self) = @_;

  return $self->{'from_date'};
}

sub set_from_date
{
  my ($self, $from_date) = @_;

  $self->{'from_date'} = $from_date;
}

sub get_patch_date
{
  my ($self) = @_;

  return $self->{'patch_date'};
}

sub set_patch_date
{
  my ($self, $patch_date) = @_;

  $self->{'patch_date'} = $patch_date;
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

sub get_message_lines
{
  my ($self) = @_;

  return $self->{'message_lines'};
}

sub add_message_line
{
  my ($self, $line) = @_;
  my $lines = $self->get_message_lines ();

  push (@{$lines}, $line);
}

sub get_diffs
{
  my ($self) = @_;

  return $self->{'diffs'};
}

sub add_diff
{
  my ($self, $diff) = @_;
  my $diffs = $self->get_diffs ();

  push (@{$diffs}, $diff);
}

sub get_last_diff
{
  my ($self) = @_;
  my $diffs = $self->get_diffs ();

  if (@{$diffs} > 0)
  {
    return @{$diffs}[-1];
  }

  return undef;
}

sub get_sections_ordered
{
  my ($self) = @_;

  return $self->{'sections_ordered'};
}

sub get_sections_unordered
{
  my ($self) = @_;

  return $self->{'sections_unordered'};
}

sub get_sections_count
{
  my ($self) = @_;
  my $count = @{$self->get_sections_ordered ()};

  return $count;
}

sub add_section
{
  my ($self, $section) = @_;
  my $ordered = $self->get_sections_ordered ();
  my $unordered = $self->get_sections_unordered ();
  my $name = $section->get_name ();

  if (exists ($unordered->{$name}))
  {
    return 0;
  }

  push (@{$ordered}, $section);
  $unordered->{$name} = $section;
  return 1;
}

sub get_raw_diffs_and_modes
{
  my ($self) = @_;

  return $self->{'raw_diffs_and_modes'};
}

sub add_raw_diffs_and_mode
{
  my ($self, $diffs_and_mode) = @_;
  my $raw_diffs_and_modes = $self->get_raw_diffs_and_modes ();
  my $git_diffs = $diffs_and_mode->{'git-raw'};
  my $stats = $diffs_and_mode->{'stats'};

  foreach my $section_name (keys (%{$git_diffs}))
  {
    unless (exists ($raw_diffs_and_modes->{$section_name}))
    {
      $raw_diffs_and_modes->{$section_name} = {'git-diffs' => [], 'stats' => ListingInfo->new ()};
    }

    push (@{$raw_diffs_and_modes->{$section_name}->{'git-diffs'}}, $git_diffs->{$section_name});
  }

  foreach my $section_name (keys (%{$stats}))
  {
    unless (exists ($raw_diffs_and_modes->{$section_name}))
    {
      $raw_diffs_and_modes->{$section_name} = {'git-diffs' => [], 'stats' => ListingInfo->new ()};
    }

    my $new_listing = $raw_diffs_and_modes->{$section_name}->{'stats'}->merge ($stats->{$section_name});

    unless (defined ($new_listing))
    {
      # TODO: just die.
      next;
    }
    $raw_diffs_and_modes->{$section_name}->{'stats'} = $new_listing;
  }
}

sub get_ordered_sectioned_raw_diffs_and_modes
{
  my ($self) = @_;
  my $sections_array = $self->get_sections_ordered ();
  my $raw_diffs_and_modes = $self->get_raw_diffs_and_modes ();
  my @sectioned_diffs_and_modes = ();

  foreach my $section (@{$sections_array})
  {
    my $section_name = $section->get_name ();

    if (exists ($raw_diffs_and_modes->{$section_name}))
    {
      my $diffs_and_modes =
      {
        'git-diffs' => $raw_diffs_and_modes->{$section_name}->{'git-diffs'},
        'section' => $section,
        'stats' => $raw_diffs_and_modes->{$section_name}->{'stats'}
      };
      push (@sectioned_diffs_and_modes, $diffs_and_modes);
    }
  }

  return \@sectioned_diffs_and_modes;
}

1;

# ParseContext describes the current state of parsing the annotated
# patch.
package ParseContext;

use constant
{
  PreviousLinesLimit => 3
};

sub new
{
  my ($type, $initial_mode, $ops) = @_;
  my $class = (ref ($type) or $type or 'ParseContext');
  my $self =
  {
    'file' => undef,
    'eof' => 1,
    'reached_eof' => 1,
    'filename' => undef,
    'chunks' => [],
    'mode' => $initial_mode,
    'line_number' => 0,
    'current_chunk' => undef,
    'ops' => $ops,
    'line' => undef,
    'unread_lines' => [],
    'previous_lines' => [],
    'patch' => Patch->new (),
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

package StatRenderContext;

use constant
{
  PrefixSpaceLength => 1,

  MaxFileStatPathLength => 50,
  MaxFileStatLineLength => 79
};

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'StatRenderContext');
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

# GnomePatch looks like a mixed bag of code that includes parsing the
# annotated patch and generating the smaller patches from the
# annotated one.
package GnomePatch;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'GnomePatch');
  my $self =
  {
    'listing_info' => ListingInfo->new (),
    'raw_diffs' => {},
    'default_data' => {}
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_listing_info
{
  my ($self) = @_;

  return $self->{'listing_info'};
}

sub get_raw_diffs
{
  my ($self) = @_;

  return $self->{'raw_diffs'};
}

sub get_default_data
{
  my ($self) = @_;

  return $self->{'default_data'};
}

sub process
{
  my ($self, $filename) = @_;

  $self->_prepare_parse_context ();
  $self->_load_file ($filename);
  $self->_parse_file ();
  $self->_cleanup ();
}

sub _prepare_parse_context
{
  my ($self) = @_;
  my $ops =
  {
    'intro' => sub { $self->_on_intro (@_); },
    'listing' => sub { $self->_on_listing (@_); },
    'rest' => sub { $self->_on_rest (@_); }
  };

  $self->{'p_c'} = ParseContext->new ('intro', $ops);
}

sub _load_file
{
  my ($self, $filename) = @_;
  my $pc = $self->_get_pc ();
  my $file = IO::File->new ($filename, 'r');

  unless (defined ($file))
  {
    die "Could not load '$filename'.";
  }

  $file->binmode (':utf8');
  $pc->setup_file ($file, $filename);
}

sub _parse_file
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();

  until ($pc->get_eof ())
  {
    $pc->run_op ();
  }
}

sub _on_intro
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $patch = $pc->get_patch ();
  my $stage = 'from-date';

  while ($stage ne 'done')
  {
    $self->_read_next_line_or_die ();
    my $line = $pc->get_line ();
    if ($self->_line_is_comment ($line))
    {
      # just a comment, skip it
    }
    elsif ($stage eq 'from-date')
    {
      if ($line =~ /^\s*From\s+\S+\s+(\S.*)$/)
      {
        $patch->set_from_date ($1);
        $stage = 'from-author';
      }
      else
      {
        $pc->die ("Expected a From hash line, got '$line'");
      }
    }
    elsif ($stage eq 'from-author')
    {
      if ($line =~ /^\s*From:\s*(\S.*)$/)
      {
        $patch->set_author ($1);
        $stage = 'patch-date';
      }
      else
      {
        $pc->die ("Expected a From author line, got '$line'");
      }
    }
    elsif ($stage eq 'patch-date')
    {
      if ($line =~ /^\s*Date:\s*(\S.*)$/)
      {
        $patch->set_patch_date ($1);
        $stage = 'subject';
      }
      else
      {
        $pc->die ("Expected a Date line, got '$line'");
      }
    }
    elsif ($stage eq 'subject')
    {
      if ($line =~ /^\s*Subject:\s*(?:\[\s*PATCH[^\]]*\])?\s*(\S.*)$/)
      {
        $patch->set_subject ($1);
        $stage = 'separator';
      }
      else
      {
        $pc->die ("Expected a Subject line, got '$line'");
      }
    }
    elsif ($stage eq 'separator')
    {
      if ($line eq '')
      {
        $stage = 'message';
      }
      else
      {
        $pc->die ("Expected an empty line, got '$line'");
      }
    }
    elsif ($stage eq 'message')
    {
      if ($line eq '---')
      {
        $stage = 'done';
      }
      else
      {
        $patch->add_message_line ($line);
      }
    }
  }
  $pc->set_mode ('listing');
}

sub _on_listing
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $patch = $pc->get_patch ();
  my $listing_info = $self->get_listing_info ();
  my $stage = 'sections';
  my $got_author = 0;
  my $got_date = 0;
  my $got_subject = 0;
  my $got_message = 0;

  while ($stage ne 'done')
  {
    $self->_read_next_line_or_die ();
    my $line = $pc->get_line ();
    if ($self->_line_is_comment ($line))
    {
      # just a comment, skip it
    }
    elsif ($stage eq 'sections')
    {
      if ($line =~ /^#\s*SECTION:\s*(\w+)\s*$/a)
      {
        my $name = $1;
        my $sections_count = $patch->get_sections_count ();
        my $section = Section->new ($name, $sections_count);

        unless ($patch->add_section ($section))
        {
          $pc->die ("Section '$name' specified twice.");
        }
        $got_author = 0;
        $got_date = 0;
        $got_subject = 0;
        $got_message = 0;
      }
      elsif ($line =~ /^#\s*AUTHOR:\s*(\S.*)$/)
      {
        my $author = $1;
        unless ($patch->get_sections_count ())
        {
          $pc->die ("'AUTHOR' clause needs to follow the 'SECTION' clause");
        }
        if ($got_author)
        {
          $pc->die ("Multiple 'AUTHOR' clauses for a single 'SECTION' clause");
        }
        my $section = @{$patch->get_sections_ordered ()}[-1];

        $section->set_author ($author);
        $got_author = 1;
      }
      elsif ($line =~ /^#\s*DATE:\s*(\S.*)$/)
      {
        my $date = $1;
        unless ($patch->get_sections_count ())
        {
          $pc->die ("'DATE' clause needs to follow the 'SECTION' clause");
        }
        if ($got_date)
        {
          $pc->die ("Multiple 'DATE' clauses for a single 'SECTION' clause");
        }
        my $section = @{$patch->get_sections_ordered ()}[-1];

        $section->set_date ($date);
        $got_date = 1;
      }
      elsif ($line =~ /^#\s*SUBJECT:\s*(\S.*)$/)
      {
        my $subject = $1;
        unless ($patch->get_sections_count ())
        {
          $pc->die ("'SUBJECT' clause needs to follow the 'SECTION' clause");
        }
        if ($got_subject)
        {
          $pc->die ("Multiple 'SUBJECT' clauses for a single 'SECTION' clause");
        }
        my $section = @{$patch->get_sections_ordered ()}[-1];

        $section->set_subject ($subject);
        $got_subject = 1;
      }
      elsif ($line =~ /#\s*MESSAGE_BEGIN\s*/)
      {
        unless ($patch->get_sections_count ())
        {
          $pc->die ("'MESSAGE_BEGIN' clause needs to follow the 'SECTION' clause");
        }
        if ($got_message)
        {
          $pc->die ("Multiple 'MESSAGE_BEGIN' clauses for a single 'SECTION' clause");
        }
        $stage = 'section-message';
        $got_message = 1;
      }
      elsif ($line =~ /#\s*MESSAGE_END\s*/)
      {
        $pc->die ("'MESSAGE_END' clause without 'MESSAGE_BEGIN'");
      }
      elsif ($line =~ /^\s+\S/a)
      {
        my $sections_count = $patch->get_sections_count ();

        unless ($sections_count)
        {
          $pc->die ("No sections specified.");
        }
        $stage = 'listing-per-file';
      }
      else
      {
        $pc->die ("Unknown line in sections.");
      }
    }
    elsif ($stage eq 'section-message')
    {
      if ($line =~ /#\s*MESSAGE_END\s*/)
      {
        $stage = 'sections';
      }
      elsif ($line =~ /^#/)
      {
        $pc->die ("Expected either a comment or MESSAGE_END clause or commit message linie");
      }
      else
      {
        my $section = @{$patch->get_sections_ordered ()}[-1];

        $section->add_message_line ($line);
      }
    }
    elsif ($stage eq 'listing-per-file')
    {
      if ($line =~ /^ (.*) \| (.*)$/)
      {
        my $basename_stats = $listing_info->get_per_basename_stats ();

        unless ($basename_stats->add_file_stats ($1, $2))
        {
          $pc->die ("Invalid file stats line");
        }
      }
      elsif ($line =~ /^ (\d+) files? changed(?:, (\d+) insertions?\(\+\))?(?:, (\d+) deletions?\(-\))?/a)
      {
        my $summary = $listing_info->get_summary ();

        $summary->set_files_changed_count ($1);
        if (defined ($2))
        {
          $summary->set_insertions ($2);
        }
        if (defined ($3))
        {
          $summary->set_deletions ($3);
        }
        $stage = 'listing-new-and-gone-files'
      }
      else
      {
        $pc->die ("Unknown line in listing, expected either file stats or changes summary");
      }
    }
    elsif ($stage eq 'listing-new-and-gone-files')
    {
      if ($line =~ /^ (\w+) mode (\d+) (.+)$/)
      {
        my $new_and_gone_files = $listing_info->get_new_and_gone_files ();
        my $details = NewAndGoneDetails->new ($1, $2);
        unless ($new_and_gone_files->add_details ($3, $details))
        {
          $pc->die ("Duplicated new or gone file details for path '$3'");
        }
      }
      elsif ($line eq '')
      {
        $stage = 'done';
      }
      else
      {
        $pc->die ("Unknown line in listing, expected new or gone file details");
      }
    }
  }
  $pc->set_mode ('rest');
}

sub _on_rest
{
  my ($self) = @_;
  my $loop = 1;

  while ($loop)
  {
    $self->_handle_index_lines ();
    $loop = $self->_handle_diff_lines ();
    $self->_postprocess_diff ();
  }
}

sub _handle_index_lines
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();

  $self->_read_next_line_or_die ();

  my $word = $self->_get_first_word ();

  if (defined ($word) and $word eq 'diff')
  {
    # XXX: This section of code is rather incorrect - there can be
    # more lines in this part of diff. But for my ordinary use no such
    # diffs existed.
    my $diff_header = DiffHeader->new ();
    my $line = $pc->get_line ();

    unless ($diff_header->parse_diff_line ($line))
    {
      $pc->die ("Malformed diff line.");
    }

    $self->_read_next_line_or_die ();
    $line = $pc->get_line ();
    if ($diff_header->parse_mode_line ($line))
    {
      $self->_read_next_line_or_die ();
      $line = $pc->get_line ();
    }

    unless ($diff_header->parse_index_line ($line))
    {
      $pc->die ("Expected 'index'.");
    }

    $pc->set_current_diff_header ($diff_header);
  }
  else
  {
    $pc->die ("Expected 'diff --git'.");
  }
}

sub _handle_diff_lines
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $continue_parsing_rest = 1;

  $self->_read_next_line_or_die ();
  if ($pc->get_line () =~ /^---\s+\S/)
  {
    $continue_parsing_rest = $self->_handle_text_patch ();
  }
  elsif ($pc->get_line () eq 'GIT binary patch')
  {
    $continue_parsing_rest = $self->_handle_binary_patch ();
  }
  else
  {
    $pc->die ("Expected '--- <path>' or 'GIT binary patch'.");
  }

  return $continue_parsing_rest;
}

sub _handle_text_patch
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $diff_header = $pc->get_current_diff_header_or_die ();
  my $diff = TextDiff->new ();

  $diff->set_header ($diff_header);
  if ($pc->get_line () =~ /^---\s+(.+)/)
  {
    my $from = $1;

    if ($from =~ m!^a/(.*)$!)
    {
      $from = $1;
    }
    $diff->set_from ($from);
  }
  else
  {
    $pc->die ("Expected '---'.");
  }
  $self->_read_next_line_or_die ();

  if ($pc->get_line () =~ /^\+\+\+\s+(.+)/)
  {
    my $to = $1;

    if ($to =~ m!^b/(.*)$!)
    {
      $to = $1;
    }
    $diff->set_to ($to);
  }
  else
  {
    $pc->die ("Expected '+++'.");
  }
  $self->_read_next_line_or_die ();

  my $initial_marker = LocationMarker->new ();

  if ($pc->get_line () =~ /^@@/)
  {
    unless ($initial_marker->parse_line ($pc->get_line ()))
    {
      $pc->die ("Failed to parse location marker.");
    }
  }
  else
  {
    $pc->die ("Expected '\@\@'.");
  }

  my $last_cluster = LocationCodeCluster->new ($initial_marker);
  my $continue_parsing_rest = 1;
  my $just_got_location_marker = 1;
  my $patch = $pc->get_patch ();
  my $sections_hash = $patch->get_sections_unordered ();
  my $sections_array = $patch->get_sections_ordered ();
  my $code = undef;

  while ($pc->read_next_line ())
  {
    my $line = $pc->get_line ();

    # Stupid line maybe denoting an end of patch - depends on whether
    # next line is still proper patch line or git's version number. In
    # latter case - it is end of patch.
    if ($line eq '-- ')
    {
      $self->_read_next_line_or_die ();
      if ($pc->get_line () =~ /^\d+\.\d+\.\d+$/)
      {
        if ($just_got_location_marker)
        {
          $pc->die ("End of patch just after location marker.");
        }
        $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
        $diff->push_cluster ($last_cluster);
        $continue_parsing_rest = 0;
        last;
      }
      if ($just_got_location_marker)
      {
        my $last = $sections_array->[-1];

        $code = SectionCode->new ($last);
        $just_got_location_marker = 0;
      }
      $code->push_line (CodeLine::Minus, '- ');
      $pc->unread_line ();
      next;
    }
    elsif ($line =~ /^@@/)
    {
      if ($just_got_location_marker)
      {
        $pc->die ("Two location markers in a row.");
      }

      my $marker = LocationMarker->new ();

      $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
      $code = undef;
      $diff->push_cluster ($last_cluster);
      unless ($marker->parse_line ($line))
      {
        $pc->die ("Failed to parse location marker.");
      }
      $last_cluster = LocationCodeCluster->new ($marker);
      $just_got_location_marker = 1;
    }
    elsif ($line =~ /^#/)
    {
      if ($line =~ /^#\s*SECTION:\s*(\w+)$/a)
      {
        my $name = $1;

        unless (exists ($sections_hash->{$name}))
        {
          $pc->die ("Unknown section '$name'.");
        }

        my $section = $sections_hash->{$name};

        if (defined ($code) and $code->get_section ()->get_name () eq $name)
        {
          # ignore the sections line, we already are in this section.
        }
        else
        {
          if ($just_got_location_marker)
          {
            $just_got_location_marker = 0;
          }
          else
          {
            $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
          }
          $code = SectionCode->new ($section);
        }
      }
      elsif ($self->_line_is_comment ($line))
      {
        # it's a comment, skip it
      }
      else
      {
        $pc->die ("Malformed comment.");
      }
    }
    elsif ($line =~ /^([- +])(.*)$/)
    {
      my $sigil = $1;
      my $code_line = $2;
      my $type = CodeLine::get_type ($sigil);

      unless (defined ($type))
      {
        $pc->die ("Unknown type of line: $sigil.");
      }

      if ($just_got_location_marker)
      {
        my $last = $sections_array->[-1];

        $code = SectionCode->new ($last);
        $just_got_location_marker = 0;
      }
      $code->push_line ($type, $code_line);
    }
    else
    {
      $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
      $diff->push_cluster ($last_cluster);
      $pc->unread_line ();
      last;
    }
  }
  $patch->add_diff ($diff);

  unless ($continue_parsing_rest)
  {
    $pc->exhaust_the_file ();
  }

  return $continue_parsing_rest;
}

sub _push_section_code_to_cluster_or_die
{
  my ($self, $code, $cluster) = @_;
  my $pc = $self->_get_pc ();
  my $useless = 1;

  foreach my $line (@{$code->get_lines ()})
  {
    if ($line->get_sigil () != CodeLine::Space)
    {
      $useless = 0;
      last;
    }
  }
  if ($useless)
  {
    $pc->die ("Useless section.");
  }
  else
  {
    $cluster->push_section_code ($code);
  }
}

sub _handle_binary_patch
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $continue_parsing_rest = 1;
  my $first_try = 1;
  my $code = undef;
  my $diff_header = $pc->get_current_diff_header_or_die ();
  my $diff = BinaryDiff->new ();
  my $patch = $pc->get_patch ();

  $diff->set_header ($diff_header);
  $diff->set_listing_info ($self->get_listing_info ());
  while ($pc->read_next_line ())
  {
    my $line = $pc->get_line ();

    if ($first_try)
    {
      my $sections_hash = $patch->get_sections_unordered ();
      my $sections_array = $patch->get_sections_ordered ();

      if ($line =~ /^#/)
      {
        if ($line =~ /^#\s*SECTION:\s*(\w+)$/a)
        {
          my $name = $1;

          $first_try = 0;
          unless (exists ($sections_hash->{$name}))
          {
            $pc->die ("Unknown section '$name'.");
          }

          $code = SectionCode->new ($sections_hash->{$name});
        }
        elsif ($self->_line_is_comment ($line))
        {
          # just a comment, skip it
        }
        else
        {
          $pc->die ("Malformed comment.");
        }
        next;
      }
      $first_try = 0;
      $code = SectionCode->new ($sections_array->[-1]);
      redo;
    }
    if ($line eq '-- ')
    {
      $continue_parsing_rest = 0;
      last;
    }
    elsif ($line =~ /^#/)
    {
      if ($line =~ /^#\s*SECTION:/)
      {
        $pc->die ("Section comment in the middle of binary patch.");
      }
      elsif ($line =~ /\s/)
      {
        $pc->die ("Malformed comment in the middle of binary patch.");
      }
    }
    else
    {
      my $word = $self->_get_first_word ();

      if (defined ($word) and $word ne 'literal')
      {
        $pc->unread_line ();
        last;
      }

      $code->push_line (CodeLine::Binary, $line);
    }
  }
  $diff->set_code ($code);
  $patch->add_diff ($diff);

  unless ($continue_parsing_rest)
  {
    $pc->exhaust_the_file ();
  }

  return $continue_parsing_rest;
}

sub _line_is_comment
{
  my ($self, $line) = @_;

  if ($line =~ /^#\s*COMMENT:/ or $line =~ /^#\s*#/)
  {
    return 1;
  }

  return 0;
}

sub _postprocess_diff
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $diff = $pc->get_last_diff_or_die ();
  my $patch = $pc->get_patch ();
  my $sections_array = $patch->get_sections_ordered ();
  my $sections_hash = $patch->get_sections_unordered ();
  my $raw_diffs_and_mode = $diff->postprocess ($sections_array, $sections_hash);

  $patch->add_raw_diffs_and_mode ($raw_diffs_and_mode);
}

sub _get_first_word
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();

  if ($pc->get_line () =~ /^(\w+)\s/a)
  {
    return $1;
  }

  return undef;
}

sub _read_next_line_or_die
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();

  unless ($pc->read_next_line ())
  {
    $pc->die ("Unexpected EOF.");
  }
}

sub _cleanup
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $patch = $pc->get_patch ();

  $self->{'raw_diffs'} = $patch->get_ordered_sectioned_raw_diffs_and_modes ();
  $self->{'default_data'} = {
    'author' => $patch->get_author (),
    'subject' => $patch->get_subject (),
    'from_date' => $patch->get_from_date (),
    'patch_date' => $patch->get_patch_date (),
    'message' => $patch->get_message_lines (),
  };
  delete ($self->{'p_c'});
}

sub _get_pc
{
  my ($self) = @_;

  return $self->{'p_c'};
}

1;

package Options;

sub get
{
  my ($opt_specs, $cmdline) = @_;
  my $opts = {};

  for my $spec (keys (%{$opt_specs}))
  {
    my $value_ref = $opt_specs->{$spec};

    if (ref ($value_ref) ne 'SCALAR')
    {
      die "passed target variable for '$spec' is not a scalar ref";
    }
    my @parts = split (/=/, $spec);
    my $type = 'b';
    if (scalar (@parts) > 1)
    {
      if (scalar (@parts) > 2)
      {
        die "too many equals in '$spec'";
      }
      if (length ($parts[1]) == 0)
      {
        die "invalid empty option type in '$spec'";
      }
      unless ($parts[1] eq 's' or $parts[1] eq 'i' or $parts[1] eq 'b')
      {
        die "invalid type in '$spec'";
      }
      $type = $parts[1];
    }
    @parts = split (/\|/, $parts[0]);
    my $short_opt = undef;
    my $long_opt = undef;
    if (scalar (@parts) == 0)
    {
      die "no option name passed in '$spec'";
    }
    elsif (scalar (@parts) > 2)
    {
      die "too many option names passed in '$spec'";
    }
    else
    {
      my $opt = $parts[0];
      if (substr ($opt, 0, 1) eq '-')
      {
        die "no leading dash allowed in option name in '$spec'";
      }
      my $opt_len = length ($opt);
      if ($opt_len == 0)
      {
        die "empty option name passed in '$spec'";
      }
      elsif ($opt_len == 1)
      {
        $short_opt = "-$opt";
      }
      else
      {
        $long_opt = "--$opt";
      }
      if (scalar (@parts) > 1)
      {
        $opt = $parts[1];
        if (substr ($opt, 0, 1) eq '-')
        {
          die "no leading dash allowed in option name in '$spec'";
        }
        $opt_len = length ($opt);
        if ($opt_len == 0)
        {
          die "empty option name passed in '$spec'";
        }
        elsif ($opt_len == 1)
        {
          if (defined ($short_opt))
          {
            die "short option already specified in '$spec'";
          }
          $short_opt = "-$opt";
        }
        else
        {
          if (defined ($long_opt))
          {
            die "long option already specified in '$spec'";
          }
          $long_opt = "--$opt";
        }
      }
    }
    my $opt_state = {
      'type' => $type,
      'visited_through' => undef,
      'value_ref' => $value_ref
    };
    if (defined ($long_opt))
    {
      $opts->{$long_opt} = $opt_state;
    }
    if (defined ($short_opt))
    {
      $opts->{$short_opt} = $opt_state;
    }
  }

  my $arg_for_opt = undef;
  while (scalar (@{$cmdline}))
  {
    my $arg = shift (@{$cmdline});

    if (defined ($arg_for_opt))
    {
      my $state = $opts->{$arg_for_opt};
      my $type = $state->{'type'};
      my $value_ref = $state->{'value_ref'};

      if ($type eq 's')
      {
        ${$value_ref} = $arg;
      }
      elsif ($type eq 'i')
      {
        if ($arg =~ /^(\d+)$/a)
        {
          ${$value_ref} = $1;
        }
        else
        {
          die "'$arg' for '$arg_for_opt' is not an integer";
        }
      }
      else
      {
        die "invalid type '$type', should not happen";
      }
      $arg_for_opt = undef;
    }
    elsif ($arg =~ /^(-[^-][^=]*)=(.*)$/)
    {
      my $opt = $1;
      die "short options (like '$opt') should be separated with whitespace from values";
    }
    elsif ($arg =~ /^(--[^-][^=]+)=(.*)$/)
    {
      my $opt = $1;
      my $value = $2;
      unless (exists ($opts->{$opt}))
      {
        die "unknown option '$opt'";
      }
      my $state = $opts->{$opt};
      my $visited_through = $state->{'visited_through'};
      if (defined ($visited_through))
      {
        die "'$opt' specified twice, first time through $visited_through";
      }
      $state->{'visited_through'} = $opt;
      my $type = $state->{'type'};
      if ($type eq 'b')
      {
        die "unexpected assignment to boolean option '$1'";
      }
      else
      {
        my $value_ref = $state->{'value_ref'};

        if ($type eq 's')
        {
          ${$value_ref} = $value;
        }
        elsif ($type eq 'i')
        {
          if ($value =~ /^(\d+)$/a)
          {
            ${$value_ref} = $1;
          }
          else
          {
            die "'$arg' for '$arg_for_opt' is not an integer";
          }
        }
        else
        {
          die "invalid type '$type', should not happen";
        }
      }
    }
    elsif ($arg =~ /^(--?[^=]+)$/)
    {
      my $opt = $1;
      unless (exists ($opts->{$opt}))
      {
        die "unknown option '$opt'";
      }
      my $state = $opts->{$opt};
      my $visited_through = $state->{'visited_through'};
      if (defined ($visited_through))
      {
        die "'$opt' specified twice, first time through $visited_through";
      }
      $state->{'visited_through'} = $opt;
      my $type = $state->{'type'};
      if ($type eq 'b')
      {
        my $value_ref = $state->{'value_ref'};

        ${$value_ref} = 1;
      }
      else
      {
        $arg_for_opt = $opt;
      }
    }
    else
    {
      unshift (@{$cmdline}, $arg);
      last;
    }
  }
}

1;

package main;

sub generate_git_patches {
  my ($p, $output_directory) = @_;
  my $default_data = $p->get_default_data ();
  my $entries = $p->get_raw_diffs ();
  my $patches_count = @{$entries};

  foreach my $entry (@{$entries})
  {
    my $diff = join ('', @{$entry->{'git-diffs'}});
    my $section = $entry->{'section'};
    my $stats = $entry->{'stats'};
    my $section_name = $section->get_name ();
    my $patch_index = $section->get_index () + 1;
    my $number = sprintf ("%04d", $patch_index);
    my $subject = $section->get_subject ();

    unless (defined ($subject))
    {
      $subject = $default_data->{'subject'};
      unless (defined ($subject))
      {
        die "no subject for section $section_name";
      }
    }

    my $subject_for_patch_name = $subject;
    $subject_for_patch_name =~ s/[^\w.]+/-/ag;
    $subject_for_patch_name =~ s/^-+//ag;
    $subject_for_patch_name =~ s/-+$//ag;
    $subject_for_patch_name = substr ($subject_for_patch_name, 0, 52);

    my $patch_name = "$number-$subject_for_patch_name.patch";
    my $patch_file = File::Spec->catfile ($output_directory, $patch_name);
    my $file = IO::File->new ($patch_file, 'w');

    unless (defined ($file))
    {
      die "Could not open '$patch_file' for writing.";
    }

    my $from_date = $default_data->{'from_date'};
    my $author = $section->get_author ();
    unless (defined ($author))
    {
      $author = $default_data->{'author'};
      unless (defined ($author))
      {
        die "no author for section $section_name";
      }
    }

    my $patch_date = $section->get_date ();
    unless (defined ($patch_date))
    {
      $patch_date = $default_data->{'patch_date'};
      unless (defined ($patch_date))
      {
        die "no patch date for section $section_name";
      }
    }

    my $message_lines = $section->get_message_lines ();
    unless (defined ($message_lines))
    {
      $message_lines = $default_data->{'message'};
      # This is never undef, it can be just an empty arrayref.
    }

    my $stat_render_context = StatRenderContext->new ();
    my $per_basename_stats = $stats->get_per_basename_stats ();
    my $summary = $stats->get_summary ();
    my $new_and_gone_files = $stats->get_new_and_gone_files ();

    $per_basename_stats->fill_context_info ($stat_render_context);

    my $contents = join ("\n",
                         "From 1111111111111111111111111111111111111111 $from_date",
                         "From: $author",
                         "Date: $patch_date",
                         "Subject: [PATCH $patch_index/$patches_count] $subject",
                         '',
                         @{$message_lines},
                         '---',
                         $per_basename_stats->to_lines ($stat_render_context),
                         $summary->to_string (),
                         $new_and_gone_files->to_lines (),
                         '',
                         $diff,
                         '-- ',
                         '0.0.0',
                         '',
                         '');

    $file->binmode (':utf8');
    $file->print ($contents);
  }
}

my $input_patch = 'old-gnome-3.4.patch';
my $output_directory = '.';

Options::get({'output-directory=s' => \$output_directory,
              'input-patch=s' => \$input_patch}, \@ARGV);

my $mp_error;
make_path($output_directory, {'error' => \$mp_error});
if ($mp_error && @{$mp_error})
{
  for my $diag (@{$mp_error})
  {
    my ($dir, $msg) = %{$diag};
    if ($dir eq '')
    {
      say "General error: $msg";
    }
    else
    {
      say "Problem creating directory $dir: $msg";
    }
  }
  die;
}

my $p = GnomePatch->new ();

$p->process ($input_patch);
generate_git_patches ($p, $output_directory);
