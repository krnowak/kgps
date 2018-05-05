# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

# ListingInfo contains the listing information of the patch. So it is
# a representation of lines in the patch like:
#
# .htaccess | 26 +
# gedit     | Bin 64 -> 0 bytes
# 1 file changed, 26 insertions(+), 0 deletions(-)
# delete mode 100755 gedit
package Kgps::ListingInfo;

use strict;
use v5.16;
use warnings;

use Kgps::BasenameStats;
use Kgps::ListingSummary;
use Kgps::NewAndGoneFiles;

sub new
{
  my ($type) = @_;

  return _new_with_items ($type, Kgps::BasenameStats->new (), Kgps::ListingSummary->new (), Kgps::NewAndGoneFiles->new ());
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

  return Kgps::ListingInfo->_new_with_items ($merged_per_basename_stats, $merged_summary, $merged_new_and_gone_files);
}

sub _new_with_items
{
  my ($type, $per_basename_stats, $summary, $new_and_gone_files) = @_;
  my $class = (ref ($type) or $type or 'Kgps::ListingInfo');
  my $self = {
    'per_basename_stats' => $per_basename_stats,
    'summary' => $summary,
    'new_and_gone_files' => $new_and_gone_files,
  };

  $self = bless ($self, $class);

  return $self;
}

1;
