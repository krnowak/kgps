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
use Kgps::DiffHeader;
use Kgps::DiffHeaderCommon;
use Kgps::DiffHeaderPartContentsMode;
use Kgps::DiffHeaderSpecificExisting;
use Kgps::FileStateBuilder;
use Kgps::FinalCode;
use Kgps::LocationMarker;
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
  my ($self, $sections_array, $sections_hash, $headers_for_sections) = @_;
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

  my $header = $self->get_header ();
  my $git_raw = {};
  my @used_section_names = ();

  for my $section (@{$sections_array})
  {
    my $section_name = $section->get_name ();
    if (scalar (@{$for_raw->{$section_name}}))
    {
      push (@used_section_names, $section_name);
    }
  }

  my %headers_for_used_sections = $self->_get_headers_for_used_sections ($sections_hash, \@used_section_names, $headers_for_sections);
  my $stats = {};

  for my $section_name (keys (%headers_for_used_sections))
  {
    my $diff_header = $headers_for_used_sections{$section_name};
    my $final_codes = $for_raw->{$section_name};

    $git_raw->{$section_name} = $self->_get_raw_text_for_final_codes ($diff_header, $final_codes);
    $stats->{$section_name} = $self->_get_stats_for_final_codes ($diff_header, $final_codes);
  }

  return {'git-raw' => $git_raw, 'stats' => $stats};
}

sub _get_headers_for_used_sections
{
  my ($self, $sections_hash, $used_section_names, $headers_for_sections) = @_;
  my %used_section_name_to_header = map { $_ => undef } @{$used_section_names};

  unless (scalar (keys (%{$headers_for_sections})))
  {
    my $header = $self->get_header ();
    my @sections = map { $sections_hash->{$_} } @{$used_section_names};
    my $default_section = $header->pick_default_section (\@sections);

    $headers_for_sections =
    {
      $default_section->get_name () => $header->with_bogus_values (),
    };
  }

  my %section_name_to_header = (%used_section_name_to_header, %{$headers_for_sections});
  my @sorted_section_header_pairs =
      map { $_->[0] }
      sort { $a->[1] <=> $b->[1] }
      map { [[$sections_hash->{$_}, $section_name_to_header{$_}], $sections_hash->{$_}->get_index ()] }
      keys (%section_name_to_header);
  my @sorted_defined_headers = map { $_->[1] } grep { defined ($_->[1]) } @sorted_section_header_pairs;
  my $header_idx = 0;
  my $any_idx = 0;
  my $have_headers = 1;
  my $builder = Kgps::FileStateBuilder->new ();

  unless (scalar (@sorted_defined_headers))
  {
    die;
  }

  while ($any_idx < scalar (@sorted_section_header_pairs) and $have_headers)
  {
    my $pair = $sorted_section_header_pairs[$any_idx];

    if (defined ($pair->[1]))
    {
      $header_idx++;
      if ($header_idx == scalar (@sorted_defined_headers))
      {
        $header_idx--;
        $have_headers = 0;
      }

      my $section_name = $pair->[0]->get_name ();
      if (exists ($used_section_name_to_header{$section_name}))
      {
        $pair->[1] = $pair->[1]->with_index ();
      }
      else
      {
        $pair->[1] = $pair->[1]->without_index ();
      }
    }
    else
    {
      my $header = $sorted_defined_headers[$header_idx];
      my $common = $header->get_diff_common ();
      my $specific = $header->_get_diff_specific ();
      my $file_state = $specific->get_pre_file_state ($builder, $common);
      my $wrapper = $file_state->get_wrapper ();
      my $data = $wrapper->get_data_or_undef ();

      unless (defined ($data))
      {
        die;
      }

      my $path = $data->get_path ();
      my $mode = $data->get_mode ();

      $pair->[1] = _create_contents_only_diff_header ($path, $mode);
    }
    $any_idx++;
  }
  while ($any_idx < scalar (@sorted_section_header_pairs))
  {
    my $pair = $sorted_section_header_pairs[$any_idx];

    if (defined ($pair->[1]))
    {
      die;
    }

    my $header = $sorted_defined_headers[$header_idx];
    my $common = $header->get_diff_common ();
    my $specific = $header->_get_diff_specific ();
    my $file_state = $specific->get_post_file_state ($builder, $common);
    my $wrapper = $file_state->get_wrapper ();
    my $data = $wrapper->get_data_or_undef ();

    unless (defined ($data))
    {
      die;
    }

    my $path = $data->get_path ();
    my $mode = $data->get_mode ();

    $pair->[1] = _create_contents_only_diff_header ($path, $mode);
    $any_idx++;
  }

  return map { $_->[0]->get_name () => $_->[1] } @sorted_section_header_pairs;
}

sub _create_contents_only_diff_header
{
  my ($path, $mode) = @_;
  my $common = Kgps::DiffHeaderCommon->new ($path, $path);
  my $part_contents_mode = Kgps::DiffHeaderPartContentsMode->new ('1' x 7, '2' x 7, $mode);
  my $specific = Kgps::DiffHeaderSpecificExisting->new (undef, undef, $part_contents_mode);

  return Kgps::DiffHeader->new_strict ($common, $specific);
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

sub _adapt_additions
{
  my ($self, $current_section, $current_line, $additions, $sections_hash) = @_;
  my @all_section_names = keys (%{$additions});
  my $sigil = $current_line->get_sigil ();

  foreach my $section_name (@all_section_names)
  {
    my $marker = $additions->{$section_name};
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
        $marker->dec_old_line_no ();
        $marker->dec_new_line_no ();
        # old line no - 1
        # new line no - 1
      }
      elsif ($section->is_older_than ($current_section))
      {
        # nothing changes
      }
      else # same section
      {
        $marker->dec_new_line_no ();
        # new line no - 1
      }
    }
  }
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
        _double_old_inc ($marker);
        _double_new_inc ($marker);
      }
      elsif ($section->is_older_than ($current_section))
      {
        # nothing changes
      }
      else # same section
      {
        _double_new_inc ($marker);
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
        _double_old_inc ($marker);
        _double_new_inc ($marker);
      }
      else # same section
      {
        _double_old_inc ($marker);
      }
    }
    elsif ($sigil == Kgps::CodeLine::Space)
    {
      _double_old_inc ($marker);
      _double_new_inc ($marker);
    }
  }
}

sub _double_old_inc
{
  my ($marker) = @_;

  if ($marker->inc_old_line_no () == 1)
  {
    $marker->inc_old_line_no ();
  }
}

sub _double_new_inc
{
  my ($marker) = @_;

  if ($marker->inc_new_line_no () == 1)
  {
    $marker->inc_new_line_no ();
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
  my ($self, $diff_header, $final_codes) = @_;
  my @text_diff_lines = ();

  if (scalar (@{$final_codes}))
  {
    my @raw_codes = map { $self->_get_raw_text_for_final_code ($_) } @{$final_codes};
    my $from = $diff_header->get_text_from ();
    my $to = $diff_header->get_text_to ();

    push (@text_diff_lines,
          "--- $from",
          "+++ $to",
          @raw_codes);
  }

  return join ("\n",
               $diff_header->to_lines (),
               @text_diff_lines,
               '');
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
  my ($self, $header, $final_codes) = @_;
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
  my $path = $header->get_basename_stat_path ();
  my $stat = Kgps::TextFileStat->new_with_real_signs ($path, $signs);

  return $header->get_stats ($stat);
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
