# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Kgps::Options;

use strict;
use v5.16;
use warnings;

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
      'value_ref' => $value_ref,
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

  return;
}

1;
