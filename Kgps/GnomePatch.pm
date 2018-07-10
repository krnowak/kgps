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
use Kgps::CustomizationCreate;
use Kgps::CustomizationDelete;
use Kgps::CustomizationIndex;
use Kgps::CustomizationMode;
use Kgps::CustomizationRename;
use Kgps::Date;
use Kgps::DateInc;
use Kgps::DiffHeaderParser;
use Kgps::FileStateBuilder;
use Kgps::ListingAuxChangesDetailsCreate;
use Kgps::ListingAuxChangesDetailsDelete;
use Kgps::ListingAuxChangesDetailsMode;
use Kgps::ListingAuxChangesDetailsModeRename;
use Kgps::ListingAuxChangesDetailsRename;
use Kgps::ListingInfo;
use Kgps::LocationCodeCluster;
use Kgps::LocationMarker;
use Kgps::Misc;
use Kgps::OverlapInfo;
use Kgps::ParseContext;
use Kgps::Section;
use Kgps::SectionCode;
use Kgps::SectionOverlappedCode;
use Kgps::SectionRanges;
use Kgps::TextDiff;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::GnomePatch');
  my $self =
  {
    'listing_info' => Kgps::ListingInfo->new (),
    'raw_diffs' => {},
    'default_data' => {},
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

  return;
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

  return;
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

  return;
}

sub _parse_file
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();

  until ($pc->get_eof ())
  {
    $pc->run_op ();
  }

  return;
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
        my $date = Kgps::Date->create ($1);

        unless (defined ($date))
        {
          $pc->die ("Invalid date in a Date line");
        }
        $patch->set_patch_date ($date);
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

  return;
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
  my $last_rename_aux_data = undef;

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
      if ($line =~ /^#\s*DATE_INC:\s*(\d*):(\d*):(\d*):(\d*)(?:\s+(\w+))?\s*$/a)
      {
        my $days = Kgps::Misc::to_num ($1);
        my $hours = Kgps::Misc::to_num ($2);
        my $minutes = Kgps::Misc::to_num ($3);
        my $seconds = Kgps::Misc::to_num ($4);
        my $mode = $5;

        if ($mode eq '')
        {
          $mode = 'UPTO';
        }
        if ($mode eq 'UPTO')
        {
          $mode = Kgps::DateInc::Upto;
        }
        elsif ($mode eq 'FROM')
        {
          $mode = Kgps::DateInc::From;
        }
        else
        {
          $pc->die ('Invalid increment mode in DATE_INC clause, needs to be either FROM or UPTO');
        }
        if ($patch->get_sections_count ())
        {
          $pc->die ("'DATE_INC' clause needs to precede any 'SECTION' clause");
        }
        if (defined ($patch->get_date_inc ()))
        {
          $pc->die ("Multiple 'DATE_INC' clauses for a patch");
        }
        $patch->set_date_inc (Kgps::DateInc->new ($days, $hours, $minutes, $seconds, $mode));
      }
      elsif ($line =~ /^#\s*SECTION:\s*(\w+)\s*$/a)
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
        my $raw = $1;

        unless ($patch->get_sections_count ())
        {
          $pc->die ("'DATE' clause needs to follow the 'SECTION' clause");
        }
        if ($got_date)
        {
          $pc->die ("Multiple 'DATE' clauses for a single 'SECTION' clause");
        }

        my $section = @{$patch->get_sections_ordered ()}[-1];
        my $date = Kgps::Date->create ($raw);

        unless (defined ($date))
        {
          $pc->die ("Invalid date in 'DATE' clause");
        }

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
        $stage = 'listing-aux-changes'
      }
      else
      {
        $pc->die ("Unknown line in listing, expected either file stats or changes summary");
      }
    }
    elsif ($stage eq 'listing-aux-changes')
    {
      if ($line =~ /^ create mode (\d+) (.+)$/)
      {
        my $mode = $1;
        my $path = $2;
        my $listing_aux_changes = $listing_info->get_aux_changes ();

        if (defined ($last_rename_aux_data))
        {
          my $last_old_path = $last_rename_aux_data->{'old_path'};
          my $last_new_path = $last_rename_aux_data->{'new_path'};
          my $last_similarity_index = $last_rename_aux_data->{'similarity_index'};
          my $details = Kgps::ListingAuxChangesDetailsRename->new ($last_old_path, $last_new_path, $last_similarity_index);

          $listing_aux_changes->add_details ($details);
          $last_rename_aux_data = undef;
        }

        my $details = Kgps::ListingAuxChangesDetailsCreate->new ($mode, $path);

        $listing_aux_changes->add_details ($details);
      }
      elsif ($line =~ /^ delete mode (\d+) (.+)$/)
      {
        my $mode = $1;
        my $path = $2;
        my $listing_aux_changes = $listing_info->get_aux_changes ();

        if (defined ($last_rename_aux_data))
        {
          my $last_old_path = $last_rename_aux_data->{'old_path'};
          my $last_new_path = $last_rename_aux_data->{'new_path'};
          my $last_similarity_index = $last_rename_aux_data->{'similarity_index'};
          my $details = Kgps::ListingAuxChangesDetailsRename->new ($last_old_path, $last_new_path, $last_similarity_index);

          $listing_aux_changes->add_details ($details);
          $last_rename_aux_data = undef;
        }

        my $details = Kgps::ListingAuxChangesDetailsDelete->new ($mode, $path);

        $listing_aux_changes->add_details ($details);
      }
      elsif ($line =~ /^ rename (.+) => (.+) \((\d{1,3})%\)$/)
      {
        my $old_path = $1;
        my $new_path = $2;
        my $similarity_index = $3;
        my $listing_aux_changes = $listing_info->get_aux_changes ();

        if (defined ($last_rename_aux_data))
        {
          my $last_old_path = $last_rename_aux_data->{'old_path'};
          my $last_new_path = $last_rename_aux_data->{'new_path'};
          my $last_similarity_index = $last_rename_aux_data->{'similarity_index'};
          my $details = Kgps::ListingAuxChangesDetailsRename->new ($last_old_path, $last_new_path, $last_similarity_index);

          $listing_aux_changes->add_details ($details);
          $last_rename_aux_data = undef;
        }

        $last_rename_aux_data = {
          'old_path' => $old_path,
          'new_path' => $new_path,
          'similarity_index' => $similarity_index,
        };
      }
      elsif ($line =~ /^ mode change (\d{6}) => (\d{6}) (.+)$/)
      {
        my $old_mode = $1;
        my $new_mode = $2;
        my $path = $3;
        my $listing_aux_changes = $listing_info->get_aux_changes ();

        if (defined ($last_rename_aux_data))
        {
          my $last_old_path = $last_rename_aux_data->{'old_path'};
          my $last_new_path = $last_rename_aux_data->{'new_path'};
          my $last_similarity_index = $last_rename_aux_data->{'similarity_index'};
          my $details = Kgps::ListingAuxChangesDetailsRename->new ($last_old_path, $last_new_path, $last_similarity_index);

          $listing_aux_changes->add_details ($details);
          $last_rename_aux_data = undef;
        }

        my $details = Kgps::ListingAuxChangesDetailsMode->new ($old_mode, $new_mode, $path);

        $listing_aux_changes->add_details ($details);
      }
      elsif ($line =~ /^ mode change (\d{6}) => (\d{6})$/)
      {
        my $old_mode = $1;
        my $new_mode = $2;
        my $listing_aux_changes = $listing_info->get_aux_changes ();

        unless (defined ($last_rename_aux_data))
        {
          $pc->die ("Expected a preceding line to contain rename info");
        }

        my $last_old_path = $last_rename_aux_data->{'old_path'};
        my $last_new_path = $last_rename_aux_data->{'new_path'};
        my $last_similarity_index = $last_rename_aux_data->{'similarity_index'};
        my $details = Kgps::ListingAuxChangesDetailsModeRename->new ($last_old_path, $last_new_path, $last_similarity_index, $old_mode, $new_mode);

        $listing_aux_changes->add_details ($details);
        $last_rename_aux_data = undef;
      }
      elsif ($line eq '')
      {
        $patch->wrap_sections ();
        $stage = 'done';
      }
      else
      {
        $pc->die ("Unknown line in listing, expected auxiliary details");
      }
    }
  }
  $pc->set_mode ('rest');

  return;
}

sub _on_rest
{
  my ($self) = @_;
  my $loop = 1;

  while ($loop)
  {
    $self->_handle_diff_header_lines ();
    $loop = $self->_handle_diff_lines ();
    $self->_postprocess_diff ();
  }

  return;
}

sub _handle_diff_header_lines
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $mode = 'basic';

  $self->_read_next_line_or_die ();

  if ($pc->get_line () =~ /^#\s*DIFF_HEADER$/a)
  {
    $mode = 'full';
  }
  else
  {
    $pc->unread_line ();
  }

  my $diff_header_parser = Kgps::DiffHeaderParser->new ();
  my $result = Kgps::DiffHeaderParser::ParseMoreLinesNeeded;

  while ($result == Kgps::DiffHeaderParser::ParseMoreLinesNeeded)
  {
    $self->_read_next_line_or_die ();
    $result = $diff_header_parser->feed_line ($pc->get_line ());
  }
  if ($result == Kgps::DiffHeaderParser::ParseFail)
  {
    $pc->die ($diff_header_parser->get_failure ());
  }
  if ($result == Kgps::DiffHeaderParser::ParseDoneNotConsumed)
  {
    $pc->unread_line ();
  }

  my $header = $diff_header_parser->get_diff_header ();
  $pc->set_current_diff_header ($header);
  if ($mode eq 'basic')
  {
    my $patch = $pc->get_patch ();
    my $sections_array = $patch->get_sections_ordered ();
    my $default_section = $header->pick_default_section ($sections_array);
    my $headers_for_sections = {};
    my $allowed_section_ranges = $header->get_initial_section_ranges ($sections_array, $default_section);

    $pc->set_headers_for_sections ($headers_for_sections);
    $pc->set_allowed_section_ranges ($allowed_section_ranges);

    return;
  }

  my $stage = 'section-line';
  my $allowed_customizations = $header->get_allowed_customizations ();
  my $builder = Kgps::FileStateBuilder->new ();
  my $file_state = $header->get_pre_file_state ($builder);
  my $got_rename_customization_for_section = 0;
  my $got_mode_customization_for_section = 0;
  my $got_index_customization_for_section = 0;
  my $got_no_customization_for_section = 1;
  my $got_section_in_last_line = 0;
  my $got_at_least_one_customization = 0;
  my $last_section = undef;
  my $last_section_file_state = undef;
  my $headers_for_sections = {};
  my $allowed_section_ranges = undef;

  while ($stage ne 'done')
  {
    $self->_read_next_line_or_die ();

    my $line = $pc->get_line ();

    if ($stage eq 'section-line')
    {
    HACK_HACK:
      if ($line =~ /^#\s*END_DIFF_HEADER\s*$/a)
      {
        if ($got_at_least_one_customization)
        {
          if ($got_section_in_last_line)
          {
            $pc->die ('TODO: something about an empty section while we arely have some customizations');
          }

          my $post_file_state = $header->get_post_file_state ($builder);

          unless ($file_state->is_same ($post_file_state))
          {
            $pc->die ('TODO: file state is diff');
          }

          $headers_for_sections->{$last_section->get_name ()} = $file_state->generate_diff_header ($last_section_file_state);
          unless (defined ($allowed_section_ranges))
          {
            my $patch = $pc->get_patch ();
            my $sections_array = $patch->get_sections_ordered ();
            my $start_section = $sections_array->[0];
            my $end_section = $sections_array->[-1];

            $allowed_section_ranges = Kgps::SectionRanges->new ($start_section, $end_section);
          }
        }
        elsif ($got_section_in_last_line)
        {
          my $patch = $pc->get_patch ();
          my $sections_array = $patch->get_sections_ordered ();

          $headers_for_sections->{$last_section->get_name ()} = $header->with_bogus_values ();
          $allowed_section_ranges = $header->get_initial_section_ranges ($sections_array, $last_section);
        }
        else
        {
          my $patch = $pc->get_patch ();
          my $sections_array = $patch->get_sections_ordered ();
          my $default_section = $header->pick_default_section ($sections_array);

          $headers_for_sections = {};
          $allowed_section_ranges = $header->get_initial_section_ranges ($sections_array, $default_section);
        }
        $stage = 'done';
      }
      elsif ($line =~ /^#\s*SECTION:\s+(\S+)\s*$/a)
      {
        my $section_name = $1;

        if ($got_section_in_last_line)
        {
          $pc->die ('TODO: something about an empty section while another one was specified');
        }

        my $patch = $pc->get_patch ();
        my $sections_hash = $patch->get_sections_unordered ();

        unless (exists ($sections_hash->{$section_name}))
        {
          $pc->die ("Unknown section '$section_name'.");
        }

        my $section = $sections_hash->{$section_name};

        $got_rename_customization_for_section = 0;
        $got_mode_customization_for_section = 0;
        $got_index_customization_for_section = 0;
        $got_no_customization_for_section = 1;
        $got_section_in_last_line = 1;
        if (defined ($last_section))
        {
          if ($last_section->get_name () eq $section_name)
          {
            $pc->die ('TODO: Something about duplicated section clauses');
          }
          if ($last_section->is_younger_than ($section))
          {
            $pc->die ('TODO: something about previous section being younger than the following one, lack of order, yadda yadda');
          }
          $headers_for_sections->{$last_section->get_name ()} = $file_state->generate_diff_header ($last_section_file_state);
        }
        $last_section = $section;
        $last_section_file_state = $file_state;
        $stage = 'sections';
      }
      else
      {
        $pc->die ('TODO: unknown line');
      }
    }
    elsif ($stage eq 'sections')
    {
      if ($line =~ /^#\s*END_DIFF_HEADER$/a)
      {
        goto HACK_HACK;
      }
      elsif ($line =~ /^#\s*SECTION:\s+(\S+)$/a)
      {
        goto HACK_HACK;
      }
      elsif ($line =~ /^#\s*CREATE\s+(\S+)\s+(\d{6})$/a)
      {
        my $path = $1;
        my $mode = $2;

        unless ($allowed_customizations->is_create_allowed ())
        {
          $pc->die ('CREATE customization is not allowed for this diff header');
        }

        my $customization = Kgps::CustomizationCreate->new ($path, $mode);

        $file_state = $file_state->apply_create_customization ($customization, $got_no_customization_for_section);
        $got_no_customization_for_section = 0;
        unless (defined ($file_state))
        {
          $pc->die ('TODO: undefined file state in create');
        }
        $stage = 'section-line';
        $got_at_least_one_customization = 1;
        $got_section_in_last_line = 0;

        my $patch = $pc->get_patch ();
        my $sections_array = $patch->get_sections_ordered ();
        my $end_section = $sections_array->[-1];

        unless (defined ($allowed_section_ranges))
        {
          $allowed_section_ranges = Kgps::SectionRanges->new_empty ();
        }
        $allowed_section_ranges->add_range ($last_section, $end_section);
      }
      elsif ($line =~ /^#\s*DELETE\s+(\S+)\s+(\d{6})$/a)
      {
        my $path = $1;
        my $mode = $2;

        unless ($allowed_customizations->is_delete_allowed ())
        {
          $pc->die ('DELETE customization is not allowed for this diff header');
        }

        my $customization = Kgps::CustomizationDelete->new ($path, $mode);

        $file_state = $file_state->apply_delete_customization ($customization, $got_no_customization_for_section);
        $got_no_customization_for_section = 0;
        unless (defined ($file_state))
        {
          $pc->die ('TODO: undefined file state in delete');
        }
        $stage = 'section-line';
        $got_at_least_one_customization = 1;
        $got_section_in_last_line = 0;

        my $patch = $pc->get_patch ();
        my $sections_array = $patch->get_sections_ordered ();
        my $start_section = $sections_array->[0];

        if (defined ($allowed_section_ranges))
        {
          $allowed_section_ranges->terminate_last_range_at ($last_section);
        }
        else
        {
          $allowed_section_ranges = Kgps::SectionRanges->new ($start_section, $last_section);
        }
      }
      elsif ($line =~ /^#\s*MODE\s+(\d{6})\s+(\d{6})$/a)
      {
        my $old_mode = $1;
        my $new_mode = $2;

        unless ($allowed_customizations->is_mode_allowed ())
        {
          $pc->die ('MODE customization is not allowed for this diff header');
        }
        if ($got_mode_customization_for_section)
        {
          $pc->die ('TODO: mode duplicated');
        }
        $got_mode_customization_for_section = 1;

        my $customization = Kgps::CustomizationMode->new ($old_mode, $new_mode);

        $file_state = $file_state->apply_mode_customization ($customization, $got_no_customization_for_section);
        $got_no_customization_for_section = 0;
        unless (defined ($file_state))
        {
          $pc->die ('TODO: undefined file state in mode');
        }
        $got_at_least_one_customization = 1;
        $got_section_in_last_line = 0;
      }
      elsif ($line =~ /^#\s*RENAME\s+(\S+)\s+(\S+)$/a)
      {
        my $old_path = $1;
        my $new_path = $2;

        unless ($allowed_customizations->is_rename_allowed ())
        {
          $pc->die ('RENAME customization is not allowed for this diff header');
        }
        if ($got_rename_customization_for_section)
        {
          $pc->die ('TODO: rename duplicated');
        }
        $got_rename_customization_for_section = 1;

        my $customization = Kgps::CustomizationRename->new ($old_path, $new_path);

        $file_state = $file_state->apply_rename_customization ($customization, $got_no_customization_for_section);
        $got_no_customization_for_section = 0;
        unless (defined ($file_state))
        {
          $pc->die ('TODO: undefined file state in rename');
        }
        $got_at_least_one_customization = 1;
        $got_section_in_last_line = 0;
      }
      elsif ($line =~ /^#\s*INDEX$/a)
      {
        unless ($allowed_customizations->is_index_allowed ())
        {
          $pc->die ('INDEX customization is not allowed for this diff header');
        }
        if ($got_index_customization_for_section)
        {
          $pc->die ('TODO: index duplicated');
        }
        $got_index_customization_for_section = 1;

        my $customization = Kgps::CustomizationIndex->new ();

        $file_state = $file_state->apply_index_customization ($customization, $got_no_customization_for_section);
        $got_no_customization_for_section = 0;
        unless (defined ($file_state))
        {
          $pc->die ('TODO: undefined file state in index');
        }
        $got_at_least_one_customization = 1;
        $got_section_in_last_line = 0;
      }
      else
      {
        $pc->die ('TODO: unknown line');
      }
    }
    else
    {
      $pc->die ('TODO: unknown stage');
    }
  }

  $pc->set_headers_for_sections ($headers_for_sections);
  $pc->set_allowed_section_ranges ($allowed_section_ranges);

  return;
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
  my $allowed_section_ranges = $pc->get_allowed_section_ranges ();
  my $allowed_types_of_lines = Kgps::SectionRanges::NotInRange;

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
        my $last = $allowed_section_ranges->get_last_allowed_section ();

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

        $allowed_types_of_lines = $allowed_section_ranges->is_in_range ($section);
        if ($allowed_types_of_lines == Kgps::SectionRanges::NotInRange)
        {
          $pc->die ("Section '$name' is not allowed in this diff");
        }
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

      if ($type != Kgps::CodeLine::Plus and $allowed_types_of_lines == Kgps::SectionRanges::AdditionsOnly)
      {
        $pc->die ("Only additions are allowed in section TODO_SOME_SECTION_NAME");
      }
      if ($type != Kgps::CodeLine::Minus and $allowed_types_of_lines == Kgps::SectionRanges::DeletionsOnly)
      {
        $pc->die ("Only deletions are allowed in section TODO_SOME_SECTION_NAME");
      }

      if ($just_got_location_marker or $just_ended_overlap)
      {
        my $last = $allowed_section_ranges->get_last_allowed_section ();

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
  my $allowed_section_ranges = $pc->get_allowed_section_ranges ();
  my $allowed_types_of_lines = Kgps::SectionRanges::NotInRange;

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
        $allowed_types_of_lines = $allowed_section_ranges->is_in_range ($section);
        if ($allowed_types_of_lines == Kgps::SectionRanges::NotInRange)
        {
          $pc->die ("Section '$name' is not allowed in this diff");
        }
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

        $allowed_types_of_lines = $allowed_section_ranges->is_in_range ($new_section);
        if ($allowed_types_of_lines == Kgps::SectionRanges::NotInRange)
        {
          $pc->die ("Section '$new_name' is not allowed in this diff");
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

        if ($sigil != Kgps::CodeLine::Plus and $allowed_types_of_lines == Kgps::SectionRanges::AdditionsOnly)
        {
          $pc->die ("Only additions are allowed in section TODO_SOME_SECTION_NAME");
        }
        if ($sigil != Kgps::CodeLine::Minus and $allowed_types_of_lines == Kgps::SectionRanges::DeletionsOnly)
        {
          $pc->die ("Only deletions are allowed in section TODO_SOME_SECTION_NAME");
        }

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

  return;
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

  return;
}

sub _handle_binary_patch
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();
  my $continue_parsing_rest = 1;
  my $first_try = 1;
  my $diff = Kgps::BinaryDiff->new ();
  my $patch = $pc->get_patch ();
  my $headers_for_sections = $pc->get_headers_for_sections ();
  my @section_names = keys (%{$headers_for_sections});

  if (scalar (@section_names) > 1)
  {
    $pc->die ('Specifying alternate diff headers for binary patches is not supported');
  }
  unless (scalar (@section_names))
  {
    my $allowed_section_ranges = $pc->get_allowed_section_ranges ();
    my $last_allowed = $allowed_section_ranges->get_last_allowed_section ();
    my $diff_header = $pc->get_current_diff_header_or_die ();

    @section_names = ($last_allowed->get_name ());
    $headers_for_sections = {$section_names[0] => $diff_header->with_bogus_values ()};
  }

  my $section_name = $section_names[0];
  my $sections_hash = $patch->get_sections_unordered ();
  my $section = $sections_hash->{$section_name};
  my $code = Kgps::SectionCode->new ($section);

  $diff->set_header ($headers_for_sections->{$section_name});
  $diff->set_listing_info ($self->get_listing_info ());
  while ($pc->read_next_line ())
  {
    my $line = $pc->get_line ();

    if ($line eq '-- ')
    {
      $continue_parsing_rest = 0;
      last;
    }
    elsif ($self->_line_is_comment ($line))
    {
      # just a comment, skip it
    }
    elsif ($line =~ /^#/)
    {
      $pc->die ("Invalid clause in the middle of binary patch.");
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
  my $headers_for_sections = $pc->get_headers_for_sections ();
  my $raw_diffs_and_mode = $diff->postprocess ($sections_array, $sections_hash, $headers_for_sections);

  $patch->add_raw_diffs_and_mode ($raw_diffs_and_mode);

  return;
}

sub _get_first_word
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();

  return Misc::first_word ($pc->get_line ());
}

sub _read_next_line_or_die
{
  my ($self) = @_;
  my $pc = $self->_get_pc ();

  unless ($pc->read_next_line ())
  {
    $pc->die ("Unexpected EOF.");
  }

  return;
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
    'date_inc' => $patch->get_date_inc (),
    'message' => $patch->get_message_lines (),
  };
  delete ($self->{'p_c'});

  return;
}

sub _get_pc
{
  my ($self) = @_;

  return $self->{'p_c'};
}

1;
