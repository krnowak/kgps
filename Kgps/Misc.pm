# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::Misc;

use strict;
use v5.16;
use warnings;

use List::Util;

sub first_n
{
  my ($aref, $n) = @_;
  my $max_idx = List::Util::min (scalar (@{$aref}), $n) - 1;

  return @{$aref}[0 .. $max_idx];
}

sub last_n
{
  my ($aref, $n) = @_;
  my $max_idx = List::Util::min (scalar (@{$aref}), $n) * -1;

  if ($max_idx < 0)
  {
    return @{$aref}[$max_idx .. -1];
  }

  return ();
}

sub to_num
{
  my ($stuff) = @_;

  return 0 unless (defined ($stuff));
  return 0 if ($stuff eq '');

  return 0 + $stuff;
}

1;
