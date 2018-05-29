# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::ListingAuxChanges;

use strict;
use v5.16;
use warnings;

sub new
{
  my ($type) = @_;

  return _new_with_files ($type, []);
}

sub add_details
{
  my ($self, $details) = @_;
  my $files = $self->_get_files ();

  push (@{$files}, $details);
}

sub merge
{
  my ($self, $other) = @_;
  my $self_files = $self->_get_files ();
  my $other_files = $other->_get_files ();
  my $merged_files = [ @{$self_files}, @{$other_files} ];

  return Kgps::ListingAuxChanges->_new_with_files ($merged_files);
}

sub to_lines
{
  my ($self) = @_;
  my $files = $self->_get_files ();
  my @lines = ();
  my @sorted_details = map { $_->[1] } sort { $a->[0] cmp $b->[0] } map { [$_->get_path (), $_ ] } @{$files};

  for my $details (@sorted_details)
  {
    push (@lines, $details->to_lines ());
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
  my $class = (ref ($type) or $type or 'Kgps::ListingAuxChanges');
  my $self = {
    # path to ListingAuxChangesDetailsBase
    'files' => $files,
  };

  $self = bless ($self, $class);

  return $self;
}

1;
