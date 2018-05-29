# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::DiffHeaderParser;

use strict;
use v5.16;
use warnings;

use Kgps::DiffHeader;
use Kgps::DiffHeaderCommon;
use Kgps::DiffHeaderPartContents;
use Kgps::DiffHeaderPartContentsMode;
use Kgps::DiffHeaderPartMode;
use Kgps::DiffHeaderPartRename;
use Kgps::DiffHeaderSpecificCreated;
use Kgps::DiffHeaderSpecificDeleted;
use Kgps::DiffHeaderSpecificExisting;
use Kgps::Misc;

use constant
{
  PartStageDiff => 0, # expect diff --git line
  PartStageDetermine => 1, # expect a line that will determine which
                           # specific header we are parsing
  PartStageCreatedMode => 2,
  PartStageCreatedIndexNoMode => 3,
  PartStageDeletedMode => 4,
  PartStageDeletedIndexNoMode => 5,
  PartStageExistingModeOrRenameOrAnyIndex => 6,
  PartStageExistingModeThenRenameOrIndexNoModeOrDone => 7,
  PartStageExistingRenameOrIndexNoModeOrDone => 8,
  PartStageExistingRenameThenIndexNoModeOrDone => 9,
  PartStageExistingIndexNoModeOrDone => 10,
  PartStageExistingIndexNoModeThenDone => 11,
  PartStageExistingRenameThenIndexOrDone => 12,
  PartStageExistingIndexOrDone => 13,
  PartStageExistingIndexThenDone => 14,
  PartStageDoneConsumed => 15,
  PartStageDoneNotConsumed => 16,

  LineStageNone => 0,
  LineStageOldMode => 1,
  LineStageNewMode => 2,
  LineStageSimilarityIndex => 3,
  LineStageRenameFrom => 4,
  LineStageRenameTo => 5,
  LineStageIndexNoMode => 6,
  LineStageIndex => 7,
  LineStageNewFile => 8,
  LineStageDeletedFile => 9,
  LineStageDiff => 10,

  FeedStageOk => 0,
  FeedStageNeedMore => 1,

  DiffTypeUnknown => 0,
  DiffTypeCreated => 1,
  DiffTypeDeleted => 2,
  DiffTypeExisting => 3,

  ParseMoreLinesNeeded => 0,
  ParseDoneConsumed => 1, # done with parsing diff header, fed line
                          # was consumed
  ParseDoneNotConsumed => 2, # done with parsing diff header, fed line
                             # was not a part of a header, not
                             # consumed
  ParseFail => 3,

  _NextStep => 4, # not returned to caller, basically try to perform
                  # whatever next step in parsing
};

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Kgps::DiffHeaderParser');
  my $self =
  {
    'part_stage' => PartStageDiff,
    'line_stage' => LineStageNone,
    'feed_stage' => FeedStageNeedMore,
    'last_line_stage' => LineStageNone,
    'diff_type' => DiffTypeUnknown,
    'failure' => undef,
  };

  $self = bless ($self, $class);

  return $self;
}

sub feed_line
{
  my ($self, $line) = @_;
  my $parse_status = _NextStep;

  $self->_set_feed_stage (FeedStageOk);
  while ($parse_status == _NextStep)
  {
    if ($self->_get_feed_stage () == FeedStageNeedMore)
    {
      $parse_status = ParseMoreLinesNeeded;
      next;
    }
    $self->_do_line_stage ($line);
    $self->_set_line_stage (LineStageNone);
    if (defined ($self->get_failure ()))
    {
      $parse_status = ParseFail;
      next;
    }
    $parse_status = $self->_do_part_stage ($line);
  }

  return $parse_status;
}

sub get_diff_header
{
  my ($self) = @_;
  my $part_stage = $self->_get_part_stage ();

  if (defined ($self->get_failure ()))
  {
    return undef;
  }

  if ($part_stage == PartStageDoneConsumed or $part_stage == PartStageDoneNotConsumed)
  {
    return $self->_create_diff_header ();
  }

  return undef;
}

sub get_failure
{
  my ($self) = @_;

  return $self->{'failure'};
}

sub _get_feed_stage
{
  my ($self) = @_;

  return $self->{'feed_stage'};
}

sub _do_line_stage
{
  my ($self, $line) = @_;
  my $line_stage = $self->_get_line_stage ();

  if ($line_stage == LineStageNone)
  {
    # nothing to do
  }
  elsif ($line_stage == LineStageOldMode)
  {
    # new mode 100644
    if ($line =~ /^old mode (\d{6})/a)
    {
      $self->_set_part_mode_value ('old', $1);
    }
    else
    {
      $self->_set_failure ('expected "old mode <mode>"');
    }
  }
  elsif ($line_stage == LineStageNewMode)
  {
    # new mode 100755
    if ($line =~ /^new mode (\d{6})/a)
    {
      $self->_set_part_mode_value ('new', $1);
    }
    else
    {
      $self->_set_failure ('expected "new mode <mode>"');
    }
  }
  elsif ($line_stage == LineStageSimilarityIndex)
  {
    # similarity index 66%
    if ($line =~ /^similarity index (\d{1,3})%$/a)
    {
      $self->_set_part_rename_value ('index', $1);
    }
    else
    {
      $self->_set_failure ('expected "similarity index <percentage>%"');
    }
  }
  elsif ($line_stage == LineStageRenameFrom)
  {
    # rename from z
    if ($line =~ /^rename from (.*)$/)
    {
      $self->_set_part_rename_value ('from', $1);
    }
    else
    {
      $self->_set_failure ('expected "rename from <path>"');
    }
  }
  elsif ($line_stage == LineStageRenameTo)
  {
    # rename to Y
    if ($line =~ /^rename to (.*)$/)
    {
      $self->_set_part_rename_value ('to', $1);
    }
    else
    {
      $self->_set_failure ('expected "rename to <path>"');
    }
  }
  elsif ($line_stage == LineStageIndexNoMode)
  {
    # index 3bd1f0e..86e041d
    if ($line =~ /^index ([0-9a-f]+)\.\.([0-9a-f]+)$/)
    {
      $self->_set_part_index_no_mode_value ('from', $1);
      $self->_set_part_index_no_mode_value ('to', $2);
    }
    else
    {
      $self->_set_failure ('expected "index <from hash>..<to hash>"');
    }
  }
  elsif ($line_stage == LineStageIndex)
  {
    # index 86e041d..3ae2f37 100644
    if ($line =~ /^index ([0-9a-f]+)\.\.([0-9a-f]+) (\d{6})$/a)
    {
      $self->_set_part_index_value ('from', $1);
      $self->_set_part_index_value ('to', $2);
      $self->_set_part_index_value ('mode', $3);
    }
    else
    {
      $self->_set_failure ('expected "index <from hash>..<to hash>"');
    }
  }
  elsif ($line_stage == LineStageNewFile)
  {
    # new file mode 100755
    if ($line =~ /^new file mode (\d{6})$/a)
    {
      $self->_set_part_new_file_value ('mode', $1);
    }
    else
    {
      $self->_set_failure ('expected "new file mode <mode>"');
    }
  }
  elsif ($line_stage == LineStageDeletedFile)
  {
    # deleted file mode 100755
    if ($line =~ /^deleted file mode (\d{6})$/a)
    {
      $self->_set_part_deleted_file_value ('mode', $1);
    }
    else
    {
      $self->_set_failure ('expected "deleted file mode <mode>"');
    }
  }
  elsif ($line_stage == LineStageDiff)
  {
    # diff --git a/y b/y
    if ($line =~ m!^diff --git a/(.+) b/(.+)$!)
    {
      $self->_set_part_diff_value ('a', $1);
      $self->_set_part_diff_value ('b', $2);
    }
    else
    {
      $self->_set_failure ('expected "diff --git a/<path> b/<path>"');
    }
  }
  else
  {
    die "Unhandled line stage '$line_stage'";
  }
}

sub _set_part_mode_value
{
  my ($self, $key, $value) = @_;

  $self->_set_specific_part_value ($key, $value, 'mode');
}

sub _set_part_rename_value
{
  my ($self, $key, $value) = @_;

  $self->_set_specific_part_value ($key, $value, 'rename');
}

sub _set_part_index_no_mode_value
{
  my ($self, $key, $value) = @_;

  $self->_set_specific_part_value ($key, $value, 'index_no_mode');
}

sub _set_part_index_value
{
  my ($self, $key, $value) = @_;

  $self->_set_specific_part_value ($key, $value, 'index');
}

sub _set_part_new_file_value
{
  my ($self, $key, $value) = @_;

  $self->_set_specific_part_value ($key, $value, 'new_file');
}

sub _set_part_deleted_file_value
{
  my ($self, $key, $value) = @_;

  $self->_set_specific_part_value ($key, $value, 'deleted_file');
}

sub _set_part_diff_value
{
  my ($self, $key, $value) = @_;

  $self->_set_specific_part_value ($key, $value, 'diff');
}

sub _set_specific_part_value
{
  my ($self, $key, $value, $part_data_key) = @_;
  my $specific_part_data = $self->_get_specific_part_data ($part_data_key);

  $specific_part_data->{$key} = $value;
}

sub _do_part_stage
{
  my ($self, $line) = @_;
  my $part_stage = $self->_get_part_stage ();
  my $last_line_stage = $self->_get_last_line_stage ();
  my $line_stage = LineStageNone;
  my $feed_stage = FeedStageOk;
  my $diff_type = DiffTypeUnknown;

  if ($part_stage == PartStageDiff)
  {
    if ($last_line_stage == LineStageDiff)
    {
      $feed_stage = FeedStageNeedMore;
      $part_stage = PartStageDetermine;
    }
    else
    {
      $line_stage = LineStageDiff;
    }
  }
  elsif ($part_stage == PartStageDetermine)
  {
    my $first = _get_first_word ($line);

    if ($first eq 'new')
    {
      $part_stage = PartStageCreatedMode;
      $diff_type = DiffTypeCreated;
    }
    elsif ($first eq 'deleted')
    {
      $part_stage = PartStageDeletedMode;
      $diff_type = DiffTypeDeleted;
    }
    else
    {
      $part_stage = PartStageExistingModeOrRenameOrAnyIndex;
      $diff_type = DiffTypeExisting;
    }
  }
  elsif ($part_stage == PartStageCreatedMode)
  {
    if ($last_line_stage == LineStageNewFile)
    {
      $feed_stage = FeedStageNeedMore;
      $part_stage = PartStageCreatedIndexNoMode;
    }
    else
    {
      $line_stage = LineStageNewFile;
    }
  }
  elsif ($part_stage == PartStageCreatedIndexNoMode)
  {
    if ($last_line_stage == LineStageIndexNoMode)
    {
      $part_stage = PartStageDoneConsumed;
    }
    else
    {
      $line_stage = LineStageIndexNoMode;
    }
  }
  elsif ($part_stage == PartStageDeletedMode)
  {
    if ($last_line_stage == LineStageDeletedFile)
    {
      $feed_stage = FeedStageNeedMore;
      $part_stage = PartStageDeletedIndexNoMode;
    }
    else
    {
      $line_stage = LineStageDeletedFile;
    }
  }
  elsif ($part_stage == PartStageDeletedIndexNoMode)
  {
    if ($last_line_stage == LineStageIndexNoMode)
    {
      $part_stage = PartStageDoneConsumed;
    }
    else
    {
      $line_stage = LineStageIndexNoMode;
    }
  }
  elsif ($part_stage == PartStageExistingModeOrRenameOrAnyIndex)
  {
    my $first = _get_first_word ($line);

    if ($first eq 'old')
    {
      $part_stage = PartStageExistingModeThenRenameOrIndexNoModeOrDone;
    }
    elsif ($first eq 'similarity')
    {
      $part_stage = PartStageExistingRenameThenIndexOrDone;
    }
    elsif ($first eq 'index')
    {
      $part_stage = PartStageExistingIndexThenDone;
    }
    else
    {
      $self->_set_failure ('failed to determine a part of the diff header, expected either "old mode" or "similarity index" or "index"');
      return ParseFail;
    }
  }
  elsif ($part_stage == PartStageExistingModeThenRenameOrIndexNoModeOrDone)
  {
    if ($last_line_stage == LineStageOldMode)
    {
      $feed_stage = FeedStageNeedMore;
      $line_stage = LineStageNewMode;
    }
    elsif ($last_line_stage == LineStageNewMode)
    {
      $feed_stage = FeedStageNeedMore;
      $part_stage = PartStageExistingRenameOrIndexNoModeOrDone;
    }
    else
    {
      $line_stage = LineStageOldMode;
    }
  }
  elsif ($part_stage == PartStageExistingRenameOrIndexNoModeOrDone)
  {
    my $first = _get_first_word ($line);

    if ($first eq 'similarity')
    {
      $part_stage = PartStageExistingRenameThenIndexNoModeOrDone;
    }
    elsif ($first eq 'index')
    {
      $part_stage = PartStageExistingIndexNoModeThenDone;
    }
    else
    {
      $part_stage = PartStageDoneNotConsumed;
    }
  }
  elsif ($part_stage == PartStageExistingRenameThenIndexNoModeOrDone)
  {
    if ($last_line_stage == LineStageSimilarityIndex)
    {
      $feed_stage = FeedStageNeedMore;
      $line_stage = LineStageRenameFrom;
    }
    elsif ($last_line_stage == LineStageRenameFrom)
    {
      $feed_stage = FeedStageNeedMore;
      $line_stage = LineStageRenameTo;
    }
    elsif ($last_line_stage == LineStageRenameTo)
    {
      $feed_stage = FeedStageNeedMore;
      $part_stage = PartStageExistingIndexNoModeOrDone;
    }
    else
    {
      $line_stage = LineStageSimilarityIndex;
    }
  }
  elsif ($part_stage == PartStageExistingIndexNoModeOrDone)
  {
    my $first = _get_first_word ($line);

    if ($first eq 'index')
    {
      $part_stage = PartStageExistingIndexNoModeThenDone;
    }
    else
    {
      $part_stage = PartStageDoneNotConsumed;
    }
  }
  elsif ($part_stage == PartStageExistingIndexNoModeThenDone)
  {
    if ($last_line_stage == LineStageIndexNoMode)
    {
      $part_stage = PartStageDoneConsumed;
    }
    else
    {
      $line_stage = LineStageIndexNoMode;
    }
  }
  elsif ($part_stage == PartStageExistingRenameThenIndexOrDone)
  {
    if ($last_line_stage == LineStageSimilarityIndex)
    {
      $feed_stage = FeedStageNeedMore;
      $line_stage = LineStageRenameFrom;
    }
    elsif ($last_line_stage == LineStageRenameFrom)
    {
      $feed_stage = FeedStageNeedMore;
      $line_stage = LineStageRenameTo;
    }
    elsif ($last_line_stage == LineStageRenameTo)
    {
      $feed_stage = FeedStageNeedMore;
      $part_stage = PartStageExistingIndexOrDone;
    }
    else
    {
      $line_stage = LineStageSimilarityIndex;
    }

  }
  elsif ($part_stage == PartStageExistingIndexOrDone)
  {
    my $first = _get_first_word ($line);

    if ($first eq 'index')
    {
      $part_stage = PartStageExistingIndexThenDone;
    }
    else
    {
      $part_stage = PartStageDoneNotConsumed;
    }
  }
  elsif ($part_stage == PartStageExistingIndexThenDone)
  {
    if ($last_line_stage == LineStageIndex)
    {
      $part_stage = PartStageDoneConsumed;
    }
    else
    {
      $line_stage = LineStageIndex;
    }
  }
  elsif ($part_stage == PartStageDoneConsumed)
  {
    return ParseDoneConsumed;
  }
  elsif ($part_stage == PartStageDoneNotConsumed)
  {
    return ParseDoneNotConsumed;
  }
  else
  {
    die "Unhandled part stage '$part_stage'";
  }

  $self->_set_feed_stage ($feed_stage);
  $self->_set_line_stage_if_any ($line_stage);
  $self->_set_part_stage ($part_stage);
  $self->_set_diff_type_if_any ($diff_type);

  return _NextStep;
}

sub _set_feed_stage
{
  my ($self, $feed_stage) = @_;

  $self->{'feed_stage'} = $feed_stage;
}

sub _set_line_stage_if_any
{
  my ($self, $new_line_stage) = @_;
  my $line_stage = $self->_get_line_stage ();

  if ($new_line_stage != LineStageNone)
  {
    $self->_set_line_stage ($new_line_stage);
  }
}

sub _set_line_stage
{
  my ($self, $new_line_stage) = @_;
  my $line_stage = $self->_get_line_stage ();

  $self->{'last_line_stage'} = $line_stage;
  $self->{'line_stage'} = $new_line_stage;
}

sub _get_first_word
{
  my ($line) = @_;
  my $first = Kgps::Misc::first_word ($line);

  unless (defined ($first))
  {
    $first = '';
  }

  return $first;
}

sub _get_line_stage
{
  my ($self) = @_;

  return $self->{'line_stage'};
}

sub _set_failure
{
  my ($self, $failure) = @_;

  $self->{'failure'} = $failure;
}

sub _set_part_stage
{
  my ($self, $part_stage) = @_;

  $self->{'part_stage'} = $part_stage;
}

sub _get_part_stage
{
  my ($self) = @_;

  return $self->{'part_stage'};
}

sub _get_last_line_stage
{
  my ($self) = @_;

  return $self->{'last_line_stage'};
}

sub _set_diff_type_if_any
{
  my ($self, $diff_type) = @_;

  if ($diff_type != DiffTypeUnknown)
  {
    $self->_set_diff_type ($diff_type);
  }
}

sub _set_diff_type
{
  my ($self, $diff_type) = @_;

  $self->{'diff_type'} = $diff_type;
}

sub _create_diff_header
{
  my ($self) = @_;
  my $diff_type = $self->_get_diff_type ();

  if ($diff_type == DiffTypeUnknown)
  {
    return undef;
  }
  elsif ($diff_type == DiffTypeCreated)
  {
    return $self->_create_diff_header_with_created ();
  }
  elsif ($diff_type == DiffTypeDeleted)
  {
    return $self->_create_diff_header_with_deleted ();
  }
  elsif ($diff_type == DiffTypeExisting)
  {
    return $self->_create_diff_header_with_existing ();
  }
  else
  {
    die "Unhandled diff type '$diff_type'";
  }
}

sub _get_diff_type
{
  my ($self) = @_;

  return $self->{'diff_type'};
}

sub _create_diff_header_with_created
{
  my ($self) = @_;
  my $mode = $self->_get_part_new_file_value ('mode');
  my $part_contents = $self->_create_part_contents ();
  my $diff_specific = Kgps::DiffHeaderSpecificCreated->new ($mode, $part_contents);

  return $self->_create_diff_header_with_specific ($diff_specific);
}

sub _create_diff_header_with_deleted
{
  my ($self) = @_;
  my $mode = $self->_get_part_deleted_file_value ('mode');
  my $part_contents = $self->_create_part_contents ();
  my $diff_specific = Kgps::DiffHeaderSpecificDeleted->new ($mode, $part_contents);

  return $self->_create_diff_header_with_specific ($diff_specific);
}

sub _create_diff_header_with_existing
{
  my ($self) = @_;
  my $part_mode = $self->_maybe_create_part_mode ();
  my $part_rename = $self->_maybe_create_part_rename ();
  my $part_contents = $self->_maybe_create_any_part_contents ();
  my $diff_specific = Kgps::DiffHeaderSpecificExisting->new ($part_mode, $part_rename, $part_contents);

  return $self->_create_diff_header_with_specific ($diff_specific);
}

sub _create_diff_header_with_specific
{
  my ($self, $diff_specific) = @_;
  my $diff_a = $self->_get_part_diff_value ('a');
  my $diff_b = $self->_get_part_diff_value ('b');
  my $diff_common = Kgps::DiffHeaderCommon->new ($diff_a, $diff_b);

  return Kgps::DiffHeader->new_relaxed ($diff_common, $diff_specific);
}

sub _maybe_create_part_mode
{
  my ($self) = @_;

  unless ($self->_has_mode_part_data ())
  {
    return undef;
  }

  my $old_mode = $self->_get_part_mode_value ('old');
  my $new_mode = $self->_get_part_mode_value ('new');

  return Kgps::DiffHeaderPartMode->new ($old_mode, $new_mode);
}

sub _maybe_create_part_rename
{
  my ($self) = @_;

  unless ($self->_has_rename_part_data ())
  {
    return undef;
  }

  my $similarity_index = $self->_get_part_rename_value ('index');
  my $from = $self->_get_part_rename_value ('from');
  my $to = $self->_get_part_rename_value ('to');

  return Kgps::DiffHeaderPartRename->new ($similarity_index, $from, $to);
}

sub _maybe_create_any_part_contents
{
  my ($self) = @_;

  if ($self->_has_mode_part_data ())
  {
    return $self->_maybe_create_part_contents ();
  }
  else
  {
    return $self->_maybe_create_part_contents_mode ();
  }
}

sub _maybe_create_part_contents
{
  my ($self) = @_;

  unless ($self->_has_index_no_mode_part_data ())
  {
    return undef;
  }

  return $self->_create_part_contents ();
}

sub _maybe_create_part_contents_mode
{
  my ($self) = @_;

  unless ($self->_has_index_part_data ())
  {
    return undef;
  }

  my $from_hash = $self->_get_part_index_value ('from');
  my $to_hash = $self->_get_part_index_value ('to');
  my $mode = $self->_get_part_index_value ('mode');

  return Kgps::DiffHeaderPartContentsMode->new ($from_hash, $to_hash, $mode);
}

sub _has_mode_part_data
{
  my ($self) = @_;

  return $self->_has_specific_part_data ('mode');
}

sub _has_rename_part_data
{
  my ($self) = @_;

  return $self->_has_specific_part_data ('rename');
}

sub _has_index_no_mode_part_data
{
  my ($self) = @_;

  return $self->_has_specific_part_data ('index_no_mode');
}

sub _has_index_part_data
{
  my ($self) = @_;

  return $self->_has_specific_part_data ('index');
}

sub _has_specific_part_data
{
  my ($self, $part_data_key) = @_;
  my $part_data = $self->_get_part_data ();

  return exists ($part_data->{$part_data_key});
}

sub _create_part_contents
{
  my ($self) = @_;
  my $from_hash = $self->_get_part_index_no_mode_value ('from');
  my $to_hash = $self->_get_part_index_no_mode_value ('to');

  return Kgps::DiffHeaderPartContents->new ($from_hash, $to_hash);
}

sub _get_part_mode_value
{
  my ($self, $key) = @_;

  $self->_get_specific_part_value ($key, 'mode');
}

sub _get_part_rename_value
{
  my ($self, $key) = @_;

  $self->_get_specific_part_value ($key, 'rename');
}

sub _get_part_index_no_mode_value
{
  my ($self, $key) = @_;

  $self->_get_specific_part_value ($key, 'index_no_mode');
}

sub _get_part_index_value
{
  my ($self, $key) = @_;

  $self->_get_specific_part_value ($key, 'index');
}

sub _get_part_new_file_value
{
  my ($self, $key) = @_;

  $self->_get_specific_part_value ($key, 'new_file');
}

sub _get_part_deleted_file_value
{
  my ($self, $key) = @_;

  $self->_get_specific_part_value ($key, 'deleted_file');
}

sub _get_part_diff_value
{
  my ($self, $key) = @_;

  $self->_get_specific_part_value ($key, 'diff');
}

sub _get_specific_part_value
{
  my ($self, $key, $part_data_key) = @_;
  my $specific_part_data = $self->_get_specific_part_data ($part_data_key);

  return $specific_part_data->{$key};
}

sub _get_specific_part_data
{
  my ($self, $key) = @_;
  my $part_data = $self->_get_part_data ();
  my $specific_part_data = $part_data->{$key};

  unless (defined ($specific_part_data))
  {
    $specific_part_data = $part_data->{$key} = {};
  }

  return $specific_part_data;
}

sub _get_part_data
{
  my ($self) = @_;
  my $data_key = 'part_data';
  my $part_data = $self->{$data_key};

  unless (defined ($part_data))
  {
    $part_data = $self->{$data_key} = {};
  }

  return $part_data;
}

1;
