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

use File::Path;
use File::Spec;
use IO::File;

use Kgps::GnomePatch;
use Kgps::Options;
use Kgps::StatRenderContext;

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

    my $stat_render_context = Kgps::StatRenderContext->new ();
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

my $output_directory = '.';

Kgps::Options::get({'output-directory|o=s' => \$output_directory}, \@ARGV);

if (scalar (@ARGV) == 0)
{
  say "No path to annotated git patch given";
  die;
}
if (scalar (@ARGV) > 1)
{
  say "Too many paths passed";
  die;
}

my $input_patch = $ARGV[0];

my $mp_error;
File::Path::make_path($output_directory, {'error' => \$mp_error});
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

my $p = Kgps::GnomePatch->new ();

$p->process ($input_patch);
generate_git_patches ($p, $output_directory);
