# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# GnomePatch looks like a mixed bag of code that includes parsing the
# annotated patch and generating the smaller patches from the
# annotated one.
package Kgps::GnomePatch;

use strict;
use v5.16;
use warnings;

use IO::File;

use Kgps::BinaryDiff;
use Kgps::CodeLine;
use Kgps::DiffHeader;
use Kgps::ListingInfo;
use Kgps::LocationCodeCluster;
use Kgps::LocationMarker;
use Kgps::NewAndGoneDetails;
use Kgps::OverlapInfo;
use Kgps::ParseContext;
use Kgps::Section;
use Kgps::SectionCode;
use Kgps::SectionOverlappedCode;
use Kgps::TextDiff;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::GnomePatch');
  my $self =
  {
    'listing_info' => Kgps::ListingInfo->new (),
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

  $self->{'p_c'} = Kgps::ParseContext->new ('intro', $ops);
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
        my $section = Kgps::Section->new ($name, $sections_count);

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
        my $details = Kgps::NewAndGoneDetails->new ($1, $2);
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
    my $diff_header = Kgps::DiffHeader->new ();
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
  my $diff = Kgps::TextDiff->new ();

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

  my $initial_marker = Kgps::LocationMarker->new ();

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

  my $last_cluster = Kgps::LocationCodeCluster->new ($initial_marker);
  my $continue_parsing_rest = 1;
  my $just_got_location_marker = 1;
  my $patch = $pc->get_patch ();
  my $sections_hash = $patch->get_sections_unordered ();
  my $sections_array = $patch->get_sections_ordered ();
  my $code = undef;
  my $just_ended_overlap = 0;

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
        if ($just_ended_overlap)
        {
          $just_ended_overlap = 0;
        }
        else
        {
          if ($just_got_location_marker)
          {
            $pc->die ("End of patch just after location marker.");
          }
          $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
        }
        $diff->push_cluster ($last_cluster);
        $continue_parsing_rest = 0;
        last;
      }
      if ($just_got_location_marker)
      {
        my $last = $sections_array->[-1];

        $code = Kgps::SectionCode->new ($last);
        $just_got_location_marker = 0;
      }
      $code->push_line (Kgps::CodeLine::Minus, '- ');
      $pc->unread_line ();
      next;
    }
    elsif ($line =~ /^@@/)
    {
      if ($just_got_location_marker)
      {
        $pc->die ("Two location markers in a row.");
      }

      my $marker = Kgps::LocationMarker->new ();

      if ($just_ended_overlap)
      {
        $just_ended_overlap = 0;
      }
      else
      {
        $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
        $code = undef;
      }
      $diff->push_cluster ($last_cluster);
      unless ($marker->parse_line ($line))
      {
        $pc->die ("Failed to parse location marker.");
      }
      $last_cluster = Kgps::LocationCodeCluster->new ($marker);
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
          if ($just_got_location_marker or $just_ended_overlap)
          {
            $just_got_location_marker = 0;
            $just_ended_overlap = 0;
          }
          else
          {
            $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
          }
          $code = Kgps::SectionCode->new ($section);
        }
      }
      elsif ($line =~ /^#\s*OVERLAP$/a)
      {
        if ($just_got_location_marker or $just_ended_overlap)
        {
          $just_got_location_marker = 0;
          $just_ended_overlap = 0;
        }
        else
        {
          $self->_push_section_code_to_cluster_or_die ($code, $last_cluster);
          $just_got_location_marker = 1;
        }
        $code = undef;
        $self->_handle_overlap ($last_cluster);
        $just_ended_overlap = 1;
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
      my $type = Kgps::CodeLine::get_type ($sigil);

      unless (defined ($type))
      {
        $pc->die ("Unknown type of line: $sigil.");
      }

      if ($just_got_location_marker or $just_ended_overlap)
      {
        my $last = $sections_array->[-1];

        $code = Kgps::SectionCode->new ($last);
        $just_got_location_marker = 0;
        $just_ended_overlap = 0;
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

sub _handle_overlap
{
  my ($self, $cluster) = @_;
  my $pc = $self->_get_pc ();
  my $stage = 'expect-outcome';
  my $outcome = [];
  my $context = [];
  my $new_context = [];
  my $section = undef;
  my $patch = $pc->get_patch ();
  my $sections_hash = $patch->get_sections_unordered ();
  my $context_line_idx = 0;
  my $code = undef;
  my $overlap_info = Kgps::OverlapInfo->new ();

  while ($stage ne 'done')
  {
    $self->_read_next_line_or_die ();

    my $line = $pc->get_line ();

    if ($stage eq 'expect-outcome')
    {
      if ($line =~ /^#\s*OUTCOME$/a)
      {
        $stage = 'outcome';
      }
      elsif ($line =~ /^#\s*SECTION:\s*\w+$/a)
      {
        $pc->die ("'#OUTCOME' should come before the first section");
      }
      else
      {
        $pc->die ("Expected #OUTCOME, got '$line'");
      }
    }
    elsif ($stage eq 'outcome')
    {
      if ($line =~ /^#\s*SECTION:\s*(\w+)$/a)
      {
        my $name = $1;

        unless (exists ($sections_hash->{$name}))
        {
          $pc->die ("Unknown section '$name'");
        }
        $section = $sections_hash->{$name};
        $stage = 'sections';
        $code = Kgps::SectionOverlappedCode->new ($section, $overlap_info);
      }
      elsif ($line =~ /^([- +])(.*)$/)
      {
        my $raw_sigil = $1;
        my $raw_line = $2;
        my $sigil = Kgps::CodeLine::get_type ($raw_sigil);

        unless (defined ($sigil))
        {
          $pc->die ("Unknown type of line: $raw_sigil.");
        }

        if ($sigil == Kgps::CodeLine::Minus or $sigil == Kgps::CodeLine::Space)
        {
          push (@{$context}, $raw_line);
        }

        if ($sigil == Kgps::CodeLine::Plus or $sigil == Kgps::CodeLine::Space)
        {
          push (@{$outcome}, $raw_line);
        }
      }
      elsif ($line =~ /^#\s*END_OVERLAP$/a)
      {
        $pc->die ("Premature end of overlapped patches, no sections specified");
      }
      elsif ($line =~ /^@@/)
      {
        $pc->die ("Overlapped patches across location markers are not supported.");
      }
      else
      {
        $pc->die ("Unknown line '$line' in overlap");
      }
    }
    elsif ($stage eq 'sections')
    {
      if ($line =~ /^#\s*SECTION:\s*(\w+)$/a)
      {
        my $new_name = $1;
        my $name = $section->get_name ();

        if ($new_name eq $name)
        {
          $pc->die ("Section '$name' again?");
        }

        unless (exists ($sections_hash->{$new_name}))
        {
          $pc->die ("Unknown section '$new_name'");
        }
        my $new_section = $sections_hash->{$new_name};

        if ($new_section->is_older_than ($section))
        {
          $pc->die ("Sections are out of order - section '$new_name' should come before section '$name' in overlap");
        }

        my $lines = $code->get_lines ();

        unless (scalar (@{$lines}) > 0)
        {
          $pc->die ("Empty section '$name' in overlap");
        }
        $self->_push_section_code_to_cluster_or_die ($code, $cluster);
        $section = $new_section;
        $context_line_idx = 0;
        $context = $new_context;
        $new_context = [];
        $code = Kgps::SectionOverlappedCode->new ($section, $overlap_info);
      }
      elsif ($line =~ /^([- +])(.*)$/)
      {
        my $raw_sigil = $1;
        my $raw_line = $2;
        my $sigil = Kgps::CodeLine::get_type ($raw_sigil);

        if ($sigil == Kgps::CodeLine::Space)
        {
          my $expected = $context->[$context_line_idx];

          if ($raw_line ne $expected)
          {
            $pc->die ("Got context '$raw_line', but expected '$expected'");
          }
          ++$context_line_idx;
          $code->push_line ($sigil, $raw_line);
          push (@{$new_context}, $raw_line);
        }
        elsif ($sigil == Kgps::CodeLine::Minus)
        {
          my $expected = $context->[$context_line_idx];

          if ($raw_line ne $expected)
          {
            $pc->die ("Got removed line '$raw_line', but expected '$expected'");
          }
          ++$context_line_idx;
          $code->push_line ($sigil, $raw_line);
        }
        elsif ($sigil == Kgps::CodeLine::Plus)
        {
          $code->push_line ($sigil, $raw_line);
          push (@{$new_context}, $raw_line);
        }
      }
      elsif ($line =~ /^#\s*END_OVERLAP$/a)
      {
        my $lines = $code->get_lines ();

        unless (scalar (@{$lines}) > 0)
        {
          my $name = $section->get_name ();

          $pc->die ("Empty section '$name' in overlap");
        }
        $self->_push_section_code_to_cluster_or_die ($code, $cluster);

        $context = $new_context;
        $new_context = [];

        my $context_len = scalar (@{$context});
        my $outcome_len = scalar (@{$outcome});
        my $min_length = $context_len;

        if ($min_length > $outcome_len)
        {
          $min_length = $outcome_len;
        }

        for my $line_idx (0 .. $min_length - 1)
        {
          my $context_line = $context->[$line_idx];
          my $outcome_line = $outcome->[$line_idx];

          if ($context_line ne $outcome_line)
          {
            $pc->die ("Overlapped patches do not produce the expected outcome. Expected '$outcome_line', got '$context_line'");
          }
        }

        if ($context_len > $outcome_len)
        {
          my $superfluous_line = $context->[$min_length];
          $pc->die ("Overlapped patches do not produce the expected outcome. Got too many lines, starting with '$superfluous_line'");
        }
        elsif ($outcome_len > $context_len)
        {
          my $missing_line = $outcome->[$min_length];
          $pc->die ("Overlapped patches do not produce the expected outcome. Missing some lines, starting with '$missing_line'");
        }
        $stage = 'done';
      }
      elsif ($line =~ /^@@/)
      {
        $pc->die ("Overlapped patches across location markers are not supported.");
      }
      else
      {
        $pc->die ("Unknown line '$line' in overlap");
      }
    }
  }
}

sub _push_section_code_to_cluster_or_die
{
  my ($self, $code, $cluster) = @_;
  my $pc = $self->_get_pc ();
  my $useless = 1;

  foreach my $line (@{$code->get_lines ()})
  {
    if ($line->get_sigil () != Kgps::CodeLine::Space)
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
  my $diff = Kgps::BinaryDiff->new ();
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

          $code = Kgps::SectionCode->new ($sections_hash->{$name});
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
      $code = Kgps::SectionCode->new ($sections_array->[-1]);
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

      $code->push_line (Kgps::CodeLine::Binary, $line);
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
