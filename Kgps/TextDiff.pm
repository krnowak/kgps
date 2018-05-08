# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# TextDiff is a representation of a single diff of a text file.
package Kgps::TextDiff;

use parent qw(Kgps::DiffBase);
use strict;
use warnings;
use v5.16;

use Kgps::CodeLine;
use Kgps::FinalCode;
use Kgps::ListingInfo;
use Kgps::LocationMarker;
use Kgps::NewAndGoneDetails;
use Kgps::TextFileStat;
use Kgps::TextFileStatSignsReal;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::TextDiff');
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
      # bleh
      if ($code->isa ('Kgps::SectionOverlappedCode'))
      {
        $self->_handle_section_overlapped_code ($code, $markers, $before_contexts, $sections_hash, $final_codes);
      }
      elsif ($code->isa ('Kgps::SectionCode'))
      {
        $self->_handle_section_code ($code, $markers, $before_contexts, $sections_hash, $final_codes);
      }
      else
      {
        die 'SHOULD NOT HAPPEN'
      }
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
  my $final_inner_correction = Kgps::LocationMarker->new_zero ();
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
  my %additions = map { $_->get_name () => Kgps::LocationMarker->new_zero () } @{$sections_array};

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

sub _handle_section_code
{
  my ($self, $code, $markers, $before_contexts, $sections_hash, $final_codes) = @_;
  my $section = $code->get_section ();
  my $section_name = $section->get_name ();
  my $final_marker = $markers->{$section_name}->clone ();
  my $final_code = Kgps::FinalCode->new ($final_marker);

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

sub _adapt_markers
{
  my ($self, $current_section, $current_line, $markers, $sections_hash) = @_;
  my @all_section_names = keys (%{$markers});
  my $sigil = $current_line->get_sigil ();

  foreach my $section_name (@all_section_names)
  {
    my $marker = $markers->{$section_name};
    my $section = $sections_hash->{$section_name};

    if ($sigil == Kgps::CodeLine::Plus)
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
    elsif ($sigil == Kgps::CodeLine::Minus)
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
    elsif ($sigil == Kgps::CodeLine::Space)
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

sub _handle_section_overlapped_code
{
  my ($self, $code, $markers, $before_contexts, $sections_hash, $final_codes) = @_;
  my $section = $code->get_section ();
  my $section_name = $section->get_name ();
  my $final_marker = $markers->{$section_name}->clone ();
  my $final_code = Kgps::FinalCode->new ($final_marker);
  my $overlap_info = $code->get_overlap_info ();

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
    $self->_adapt_overlapping_markers ($section, $line, $markers, $sections_hash, $overlap_info);
    # Adapt marker for current final code.
    $self->_adapt_final_marker ($line, $final_marker);
    # Adapt initial contexts for other sections.
    $self->_adapt_overlapping_before_contexts ($section, $line, $before_contexts, $sections_hash, $overlap_info);
    # Maybe push an after context to previous final codes. Will be
    # used when cleaning up context of each final code later.
    $self->_push_overlapping_after_context ($section, $line, $final_codes, $sections_hash, $overlap_info);
  }
  push (@{$final_codes->{$section_name}}, $final_code);
}

sub _adapt_overlapping_markers
{
  my ($self, $current_section, $current_line, $markers, $sections_hash, $overlap_info) = @_;
  my @all_section_names = keys (%{$markers});
  my $sections_between_overlapping = $self->_get_sections_between_overlapping ($current_section, $overlap_info, $sections_hash);
  my $sigil = $current_line->get_sigil ();
  my $current_section_marker = $markers->{$current_section->get_name ()};

  if ($sigil == Kgps::CodeLine::Plus)
  {
    $current_section_marker->inc_new_line_no ();
  }
  elsif ($sigil == Kgps::CodeLine::Minus)
  {
    $current_section_marker->inc_old_line_no ()
  }
  elsif ($sigil == Kgps::CodeLine::Space)
  {
    $current_section_marker->inc_old_line_no ();
    $current_section_marker->inc_new_line_no ();
  }

  foreach my $section (@{$sections_between_overlapping})
  {
    my $section_name = $section->get_name ();
    my $marker = $markers->{$section_name};

    if ($sigil == Kgps::CodeLine::Plus)
    {
      $marker->inc_old_line_no ();
      $marker->inc_new_line_no ();
    }
    elsif ($sigil == Kgps::CodeLine::Minus)
    {
      $marker->dec_old_line_no ();
      $marker->dec_new_line_no ();
    }
    elsif ($sigil == Kgps::CodeLine::Space)
    {
      $marker->inc_old_line_no ();
      $marker->inc_new_line_no ();
    }
  }
}

sub _adapt_overlapping_before_contexts
{
  my ($self, $current_section, $current_line, $before_contexts, $sections_hash, $overlap_info) = @_;
  my @all_section_names = keys (%{$before_contexts});
  my $sigil = $current_line->get_sigil ();
  my $context_line = Kgps::CodeLine->new (Kgps::CodeLine::Space, $current_line->get_line ());

  foreach my $code (@{$overlap_info->get_section_overlapped_codes ()})
  {
    if ($code->get_section ()->get_index () == $current_section->get_index ())
    {
      my $sections_before_first_overlapping = $self->_get_sections_between_overlapping (undef, $overlap_info, $sections_hash);

      for my $section (@{$sections_before_first_overlapping})
      {
        if ($sigil == Kgps::CodeLine::Space or $sigil == Kgps::CodeLine::Minus)
        {
          my $section_name = $section->get_name ();
          my $before_context = $before_contexts->{$section_name};

          $self->_append_context ($before_context, $context_line);
        }
      }
    }
    last;
  }

  if ($sigil == Kgps::CodeLine::Space)
  {
    my $current_before_context = $before_contexts->{$current_section->get_name ()};

    $self->_append_context ($current_before_context, $context_line);
  }

  my $sections_between_overlapping = $self->_get_sections_between_overlapping ($current_section, $overlap_info, $sections_hash);

  foreach my $section (@{$sections_between_overlapping})
  {
    if ($sigil == Kgps::CodeLine::Space or $sigil == Kgps::CodeLine::Plus)
    {
      my $before_context = $before_contexts->{$section->get_name ()};

      $self->_append_context ($before_context, $context_line);
    }
  }
}

sub _push_overlapping_after_context
{
  my ($self, $current_section, $current_line, $final_codes, $sections_hash, $overlap_info) = @_;
  my $sigil = $current_line->get_sigil ();
  my $context_line = Kgps::CodeLine->new (Kgps::CodeLine::Space, $current_line->get_line ());

  foreach my $code (@{$overlap_info->get_section_overlapped_codes ()})
  {
    if ($code->get_section ()->get_index () == $current_section->get_index ())
    {
      my $sections_before_first_overlapping = $self->_get_sections_between_overlapping (undef, $overlap_info, $sections_hash);

      for my $section (@{$sections_before_first_overlapping})
      {
        if ($sigil == Kgps::CodeLine::Space or $sigil == Kgps::CodeLine::Minus)
        {
          foreach my $final_code (@{$final_codes->{$section->get_name ()}})
          {
            $final_code->push_after_context_line ($context_line);
          }
        }
      }
    }
    last;
  }

  if ($sigil == Kgps::CodeLine::Space)
  {
    foreach my $final_code (@{$final_codes->{$current_section->get_name ()}})
    {
      $final_code->push_after_context_line ($context_line);
    }
  }

  my $sections_between_overlapping = $self->_get_sections_between_overlapping ($current_section, $overlap_info, $sections_hash);

  foreach my $section (@{$sections_between_overlapping})
  {
    if ($sigil == Kgps::CodeLine::Space or $sigil == Kgps::CodeLine::Plus)
    {
      foreach my $final_code (@{$final_codes->{$section->get_name ()}})
      {
        $final_code->push_after_context_line ($context_line);
      }
    }
  }
}

# $overlapping_section can be undef, will get all sections before the
# first overlapping section.
sub _get_sections_between_overlapping
{
  my ($self, $overlapping_section, $overlap_info, $sections_hash) = @_;
  my $next_is_next_overlapping_section = 0;
  my $next_overlapping_section = undef;

  unless (defined ($overlapping_section))
  {
    $next_is_next_overlapping_section = 1;
  }
  foreach my $code (@{$overlap_info->get_section_overlapped_codes ()})
  {
    my $section = $code->get_section ();

    if ($next_is_next_overlapping_section)
    {
      $next_overlapping_section = $section;
      last;
    }
    if ($section->get_index () == $overlapping_section->get_index ())
    {
      $next_is_next_overlapping_section = 1;
    }
  }

  my @sections_between_overlapping = ();

  foreach my $section_name (keys (%{$sections_hash}))
  {
    my $section = $sections_hash->{$section_name};

    if (defined ($overlapping_section))
    {
      unless ($section->is_younger_than ($overlapping_section))
      {
        next;
      }
    }
    unless (defined ($next_overlapping_section))
    {
      push (@sections_between_overlapping, $section);
      next;
    }
    if ($section->is_older_than ($next_overlapping_section))
    {
      push (@sections_between_overlapping, $section);
    }
  }

  return \@sections_between_overlapping;
}

sub _adapt_final_marker
{
  my ($self, $current_line, $marker) = @_;
  my $sigil = $current_line->get_sigil ();

  if ($sigil == Kgps::CodeLine::Plus)
  {
    $marker->inc_new_line_count ();
  }
  elsif ($sigil == Kgps::CodeLine::Minus)
  {
    $marker->inc_old_line_count ();
  }
  elsif ($sigil == Kgps::CodeLine::Space)
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

    if ($sigil == Kgps::CodeLine::Space or
        ($section->is_older_than ($current_section) and $sigil == Kgps::CodeLine::Minus) or
        ($section->is_younger_than ($current_section) and $sigil == Kgps::CodeLine::Plus))
    {
      $self->_append_context ($before_context, Kgps::CodeLine->new (Kgps::CodeLine::Space, $current_line->get_line ()));
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

    if ($sigil == Kgps::CodeLine::Space or
        ($section->is_older_than ($current_section) and $sigil == Kgps::CodeLine::Minus) or
        ($section->is_younger_than ($current_section) and $sigil == Kgps::CodeLine::Plus))
    {
      foreach my $final_code (@{$final_codes->{$section_name}})
      {
        $final_code->push_after_context_line (Kgps::CodeLine->new (Kgps::CodeLine::Space, $current_line->get_line ()));
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

  return map { Kgps::CodeLine::get_char ($_->get_sigil ()) . $_->get_line () } @{$lines};
}

sub _get_stats_for_final_codes
{
  my ($self, $final_codes) = @_;
  my $listing_info = Kgps::ListingInfo->new ();
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
      my $raw_sign = Kgps::CodeLine::get_char ($sigil);
      my $code_line = $line->get_line ();

      if ($sigil == Kgps::CodeLine::Plus)
      {
        ++$insertions;
      }
      elsif ($sigil == Kgps::CodeLine::Minus)
      {
        ++$deletions;
      }
    }
  }

  my $signs = Kgps::TextFileStatSignsReal->new ($insertions, $deletions);
  my $path = $self->_get_changed_file ();

  $summary->set_files_changed_count (1);
  $summary->set_insertions ($insertions);
  $summary->set_deletions ($deletions);
  $per_basename_stats->add_stat (Kgps::TextFileStat->new ($path, $signs));

  if ($self->get_from () eq '/dev/null')
  {
    my $details = Kgps::NewAndGoneDetails->new (Kgps::NewAndGoneDetails::Create, $mode);

    $new_and_gone_files->add_details ($self->get_to (), $details);
  }
  elsif ($self->get_to () eq '/dev/null')
  {
    my $details = Kgps::NewAndGoneDetails->new (Kgps::NewAndGoneDetails::Delete, $mode);

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
