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

use File::Path qw(make_path);
use File::Spec;
use List::Util;
use IO::Dir;

package Log;

my $enable_dbg = 0;

sub dbg
{
  our $enable_dbg;
  if ($enable_dbg)
  {
    say @_;
  }
}

package Script;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'Script');
  my $self = {
    # just lines, without newlines
    'init' => [],
    # just lines, without newlines
    'pragmas' => [],
    # just pkgs
    'std' => [],
    # truncated Kgps package names (without the 'Kgps::' part)
    'kgps' => [],
    # just lines, without newlines
    'rest' => []
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_init
{
  my ($self) = @_;

  return $self->{'init'};
}

sub add_init
{
  my ($self, $line) = @_;
  my $init = $self->get_init ();

  push (@{$init}, $line);
}

sub get_pragmas
{
  my ($self) = @_;

  return $self->{'pragmas'};
}

sub add_pragmas
{
  my ($self, $line) = @_;
  my $pragmas = $self->get_pragmas ();

  push (@{$pragmas}, $line);
}

sub get_std
{
  my ($self) = @_;

  return $self->{'std'};
}

sub add_std
{
  my ($self, $pkg) = @_;
  my $std = $self->get_std ();

  push (@{$std}, $pkg);
}

sub get_kgps
{
  my ($self) = @_;

  return $self->{'kgps'};
}

sub add_kgps
{
  my ($self, $pkg) = @_;
  my $kgps = $self->get_kgps ();

  push (@{$kgps}, $pkg);
}

sub get_rest
{
  my ($self) = @_;

  return $self->{'rest'};
}

sub add_rest
{
  my ($self, $line) = @_;
  my $rest = $self->get_rest ();

  push (@{$rest}, $line);
}

1;

package Pm;

sub new
{
  my ($type, $trunc_pkg) = @_;
  my $class = (ref ($type) or $type or 'Pm');
  my $self = {
    # a truncated pkg name (without the 'Kgps::' part)
    'trunc_pkg' => $trunc_pkg,
    # just lines, without newlines
    'init' => [],
    # just lines, without newlines
    'pkg_part' => [],
    # name of the pkg parent, from 'use parent' pragma
    'parent' => undef,
    # just lines, without newlines
    'pragmas' => [],
    # pairs of pkg and line without newline
    'std' => [],
    # truncated Kgps package names (without the 'Kgps::' part)
    'kgps' => [],
    # just lines, without newlines
    'rest' => []
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_trunc_pkg
{
  my ($self) = @_;

  return $self->{'trunc_pkg'};
}

sub get_init
{
  my ($self) = @_;

  return $self->{'init'};
}

sub add_init
{
  my ($self, $line) = @_;
  my $init = $self->get_init ();

  push (@{$init}, $line);
}

sub get_pkg_part
{
  my ($self) = @_;

  return $self->{'pkg_part'};
}

sub add_pkg_part
{
  my ($self, $line) = @_;
  my $pkg_part = $self->get_pkg_part ();

  push (@{$pkg_part}, $line);
}

sub get_parent
{
  my ($self) = @_;

  return $self->{'parent'};
}

sub set_parent
{
  my ($self, $parent) = @_;

  $self->{'parent'} = $parent;
}

sub get_pragmas
{
  my ($self) = @_;

  return $self->{'pragmas'};
}

sub add_pragmas
{
  my ($self, $line) = @_;
  my $pragmas = $self->get_pragmas ();

  push (@{$pragmas}, $line);
}

sub get_std
{
  my ($self) = @_;

  return $self->{'std'};
}

sub add_std
{
  my ($self, $pkg) = @_;
  my $std = $self->get_std ();

  push (@{$std}, $pkg);
}

sub get_kgps
{
  my ($self) = @_;

  return $self->{'kgps'};
}

sub add_kgps
{
  my ($self, $pkg) = @_;
  my $kgps = $self->get_kgps ();

  push (@{$kgps}, $pkg);
}

sub get_rest
{
  my ($self) = @_;

  return $self->{'rest'};
}

sub add_rest
{
  my ($self, $line) = @_;
  my $rest = $self->get_rest ();

  push (@{$rest}, $line);
}

1;

package GenerationData;

sub new
{
  my ($type) = @_;
  my $class = (ref ($type) or $type or 'GenerationData');
  my $self = {
    # just pkgs
    'std' => [],
    # truncated Kgps package names (without the 'Kgps::' part)
    'kgps' => []
  };

  $self = bless ($self, $class);

  return $self;
}

sub get_std
{
  my ($self) = @_;

  return $self->{'std'};
}

sub add_std
{
  my ($self, $pkg) = @_;
  my $std = $self->get_std ();

  push (@{$std}, $pkg);
}

sub get_kgps
{
  my ($self) = @_;

  return $self->{'kgps'};
}

sub add_kgps
{
  my ($self, $pkg) = @_;
  my $kgps = $self->get_kgps ();

  push (@{$kgps}, $pkg);
}

1;

package main;

sub empty_aref
{
  my ($aref) = @_;

  if (scalar (@{$aref}) == 0)
  {
    return 1;
  }
  return 0;
}

sub parse_kgps
{
  my ($dir) = @_;
  my $filename = File::Spec->catfile ($dir, 'kgps');
  my $fd = IO::File->new ($filename, 'r');
  my $stage = 'license';
  my $script = Script->new ();

  die unless (defined ($fd));

  while (defined (my $line = $fd->getline ()))
  {
    chomp ($line);
    if ($stage eq 'license')
    {
      if ($line eq '')
      {
        die 'expected some license blurb in main script' if (empty_aref ($script->get_init ()));
        $stage = 'pragmas';
      }
      elsif ($line =~ /^\s*#/)
      {
        $script->add_init ($line);
      }
      else
      {
        die 'expected only comments in initial part in main script';
      }
    }
    elsif ($stage eq 'pragmas')
    {
      if ($line eq '')
      {
        die 'expected some pragmas in main script' if (empty_aref ($script->get_pragmas ()));
        $stage = 'std_or_kgps';
      }
      elsif ($line =~ /^use\s+[^:\s]+;$/)
      {
        $script->add_pragmas ($line);
      }
      else
      {
        die 'expected a "use" clause with some pragma in main script';
      }
    }
    elsif ($stage eq 'std_or_kgps')
    {
      if ($line =~ /^use\s+Kgps::(\S+);$/)
      {
        my $trunc_pkg = $1;

        $script->add_kgps ($trunc_pkg);
        $stage = 'kgps';
      }
      elsif ($line =~ /^use\s+([A-Z]\S+);$/)
      {
        my $pkg = $1;

        $script->add_std ($pkg);
        $stage = 'std';
      }
      else
      {
        die 'expected a "use" clause with either package from stdlib or Kgps in main script';
      }
    }
    elsif ($stage eq 'std')
    {
      if ($line eq '')
      {
        die 'expected some use of std pkgs in main script' if (empty_aref ($script->get_std ()));
        $stage = 'kgps';
      }
      elsif ($line =~ /^use\s+(\S+);$/)
      {
        my $pkg = $1;

        $script->add_std ($pkg);
      }
      else
      {
        die 'expected a "use" clause with a package from stdlib in main script';
      }
    }
    elsif ($stage eq 'kgps')
    {
      if ($line eq '')
      {
        die 'expected some use of Kgps pkgs in main script' if (empty_aref ($script->get_kgps ()));
        $stage = 'rest';
      }
      elsif ($line =~ /^use\s+Kgps::(\S+);$/)
      {
        my $trunc_pkg = $1;

        $script->add_kgps ($trunc_pkg);
      }
      else
      {
        die 'expected a "use" clause with a package from Kgps in main script';
      }
    }
    elsif ($stage eq 'rest')
    {
      $script->add_rest ($line);
    }
    else
    {
      die;
    }
  }

  return $script;
}

sub parse_kgps_pm
{
  my ($dir, $file_in_kgps_dir) = @_;
  my (undef, $dirs, $pm_filename) = File::Spec->splitpath ($file_in_kgps_dir);
  my @dirs = File::Spec->splitdir ($dirs);
  my @trunc_pkg_parts = (@dirs);
  if ($pm_filename =~ /^(.+?)\.pm$/)
  {
    my $last_part = $1;
    push (@trunc_pkg_parts, $last_part);
  }
  else
  {
    die 'expected to load a file ending with ".pm"';
  }
  my $trunc_pkg = join('::', @trunc_pkg_parts);
  my $pm_path = File::Spec->catfile ($dir, 'Kgps', $file_in_kgps_dir);
  my $fd = IO::File->new ($pm_path, 'r');
  my $stage = 'license';
  my $pm = Pm->new ($trunc_pkg);

  die unless (defined ($fd));

  while (defined (my $line = $fd->getline ()))
  {
    chomp ($line);
    if ($stage eq 'license')
    {
      if ($line eq '')
      {
        die 'expected some license blurb in pm' if (empty_aref ($pm->get_init ()));
        $stage = 'package_part';
      }
      elsif ($line =~ /^#/)
      {
        $pm->add_init ($line);
      }
      else
      {
        die 'expected only comments in initial part in pm';
      }
    }
    elsif ($stage eq 'package_part')
    {
      if ($line eq '')
      {
        die 'expected some lines in package part (at least the "package" clause) in pm' if (empty_aref ($pm->get_pkg_part ()));
        $stage = 'pragmas';
      }
      elsif ($line =~ /^package Kgps::(\S+);$/)
      {
        my $check_trunc_pkg = $1;
        my $trunc_pkg = $pm->get_trunc_pkg ();

        die "$check_trunc_pkg is not equal $trunc_pkg in pm" if ($check_trunc_pkg ne $trunc_pkg);

        $pm->add_pkg_part ($line);
      }
      elsif ($line =~ /^#/)
      {
        $pm->add_pkg_part ($line);
      }
      else
      {
        die 'expected either comments or "package" clause in package part in pm';
      }
    }
    elsif ($stage eq 'pragmas')
    {
      if ($line eq '')
      {
        die 'expected some pragmas in pm' if (empty_aref ($pm->get_pragmas ()));
        $stage = 'std_kgps_or_rest';
      }
      elsif ($line =~ /^use\s+parent\s+qw\(Kgps::(\S+?)\);$/)
      {
        my $parent = $1;

        die if (defined ($pm->get_parent ()));

        $pm->set_parent ($parent);
        $pm->add_pragmas ($line);
      }
      elsif ($line =~ /^use\s+[^:\s]+;$/)
      {
        $pm->add_pragmas ($line);
      }
      else
      {
        die 'expected a "use" clause with some pragma in pm';
      }
    }
    elsif ($stage eq 'std_kgps_or_rest')
    {
      if ($line =~ /^use\s+Kgps::(\S+);$/)
      {
        my $trunc_pkg = $1;

        $pm->add_kgps ($trunc_pkg);
        $stage = 'kgps';
      }
      elsif ($line =~ /^use\s+([A-Z]\S+);$/)
      {
        my $pkg = $1;

        $pm->add_std ($pkg);
        $stage = 'std';
      }
      elsif ($line !~ /^use\s+/ or $line =~ /^use\s+constant/)
      {
        $pm->add_rest ($line);
        $stage = 'rest';
      }
      else
      {
        die 'expected no "use" clauses in rest in pm';
      }
    }
    elsif ($stage eq 'std')
    {
      if ($line eq '')
      {
        die 'expected some use of std pkgs in pm' if (empty_aref ($pm->get_std ()));
        $stage = 'kgps_or_rest';
      }
      elsif ($line =~ /^use\s+(\S+);$/)
      {
        my $pkg = $1;

        $pm->add_std ($pkg);
      }
      else
      {
        die 'expected a "use" clause with a package from stdlib in pm';
      }
    }
    elsif ($stage eq 'kgps_or_rest')
    {
      if ($line =~ /^use\s+Kgps::(\S+);$/)
      {
        my $trunc_pkg = $1;

        $pm->add_kgps ($trunc_pkg);
        $stage = 'kgps';
      }
      elsif ($line !~ /^use\s+/ or $line =~ /^use\s+constant/)
      {
        $pm->add_rest ($line);
        $stage = 'rest';
      }
      else
      {
        die 'expected no "use" clauses in rest in pm';
      }
    }
    elsif ($stage eq 'kgps')
    {
      if ($line eq '')
      {
        die 'expected some use of Kgps pkgs in pm' if (empty_aref ($pm->get_kgps ()));
        $stage = 'rest';
      }
      elsif ($line =~ /^use\s+Kgps::(\S+);$/)
      {
        my $trunc_pkg = $1;

        $pm->add_kgps ($trunc_pkg);
      }
      else
      {
        die 'expected a "use" clause with a package from Kgps in pm';
      }
    }
    elsif ($stage eq 'rest')
    {
      $pm->add_rest ($line);
    }
    else
    {
      die;
    }
  }

  return $pm;
}

sub get_generation_data
{
  my ($script, $kgps_to_pm) = @_;
  my @kgps_queue = map { [$_] } @{$script->get_kgps ()};
  my %imported_kgps = ();
  my %visited_kgps = ();
  my %used_std = ();
  my $generation_data = GenerationData->new ();

  foreach my $pkg (@{$script->get_std ()})
  {
    $generation_data->add_std ($pkg);
    $used_std{$pkg} = 1;
  }
  Log::dbg ('initial queue: [', join ('], [', map { join (', ', @{$_}) } @kgps_queue), ']');
  Log::dbg ('initial std: [', join (', ', @{$generation_data->get_std ()}), ']');
  while (scalar (@kgps_queue))
  {
    my $trail = shift (@kgps_queue);
    my $kgps = pop (@{$trail});

    Log::dbg ($kgps, ': [', join (", ", @{$trail}), ']');

    if (exists ($imported_kgps{$kgps}))
    {
      Log::dbg ($kgps, ' is already imported');
    }
    else
    {
      if (defined (List::Util::first { $_ eq $kgps } @{$trail}))
      {
        die "recursive import of $kgps: @{$trail}"
      }

      my $pm = $kgps_to_pm->{$kgps};
      my $do_import = 1;

      if (exists ($visited_kgps{$kgps}))
      {
        Log::dbg ("$kgps was already visited");
        my $parent = $pm->get_parent ();

        if (defined ($parent) and not exists ($imported_kgps{$parent}))
        {
          Log::dbg ("$kgps has parent $parent and it has not yet been imported, will not import $kgps then");
          $do_import = 0;
        }
        else
        {
          foreach my $sub_kgps (@{$pm->get_kgps ()})
          {
            unless (exists ($imported_kgps{$sub_kgps}))
            {
              Log::dbg ("$sub_kgps has not yet been imported, will not import $kgps then");
              $do_import = 0;
              last;
            }
          }
        }
      }
      else
      {
        Log::dbg ("$kgps is visited for the first time");
        $visited_kgps{$kgps} = 1;

        my @new_queue_head = ();
        my $parent = $pm->get_parent ();

        if (defined ($parent) and not exists ($imported_kgps{$parent}))
        {
          push (@new_queue_head, [@{$trail}, $kgps, $parent]);
          $do_import = 0;
          Log::dbg ($kgps, ' has parent ', $parent, ' and it has not yet been imported, will not import ', $kgps, ' then, but adding [', join (', ', @{$new_queue_head[-1]}), '] to queue');
        }
        foreach my $sub_kgps (@{$pm->get_kgps ()})
        {
          unless (exists ($imported_kgps{$sub_kgps}))
          {
            push (@new_queue_head, [@{$trail}, $kgps, $sub_kgps]);
            $do_import = 0;
            Log::dbg ("$sub_kgps has not yet been imported, will not import $kgps then, but adding [", join (', ', @{$new_queue_head[-1]}), '] to queue');
          }
        }

        unshift (@kgps_queue, @new_queue_head);

        foreach my $pkg (@{$pm->get_std ()})
        {
          unless (exists ($used_std{$pkg}))
          {
            Log::dbg ("$kgps imports $pkg, adding it to data then");
            $generation_data->add_std ($pkg);
          }
          else
          {
            Log::dbg ("$kgps imports $pkg, but it is already imported");
          }
        }
      }

      if ($do_import)
      {
        Log::dbg ("importing $kgps");
        $imported_kgps{$kgps} = 1;
        $generation_data->add_kgps ($kgps);
        if (scalar (@{$trail}) > 0)
        {
          Log::dbg ('prepending [', join (', ', @{$trail}), '] to queue');
          unshift (@kgps_queue, $trail);
        }
      }
    }
    Log::dbg ('---');
    Log::dbg ('');
  }

  return $generation_data;
}

if (scalar (@ARGV) > 0)
{
  my $flag = shift (@ARGV);
  if ($flag eq '-d' or $flag eq '--debug')
  {
    $Log::enable_dbg = 1;
  }
  else
  {
    die "unknown flag '$flag'";
  }
}
die if (scalar (@ARGV) > 0);

my (undef, $dir, undef) = File::Spec->splitpath ($0);
my $kgps_dir = File::Spec->catdir ($dir, 'Kgps');
my $dirfd = IO::Dir->new ($kgps_dir);

die unless (defined ($dirfd));

my $script = parse_kgps ($dir);
my $kgps_to_pm = {};

while (defined (my $entry = $dirfd->read ()))
{
  next if $entry !~ /\.pm$/;
  my $pm = parse_kgps_pm ($dir, $entry);
  $kgps_to_pm->{$pm->get_trunc_pkg ()} = $pm;
}

$dirfd->close ();

my $generation_data = get_generation_data ($script, $kgps_to_pm);

my $out = IO::File->new (File::Spec->catfile($dir, 'kgps-standalone'), 'w');

for my $line (@{$script->get_init ()})
{
  $out->say ($line);
}
$out->say ('');
$out->say ('# THIS FILE IS GENERATED, DO NOT EDIT!');
$out->say ('');
for my $line (sort (@{$script->get_pragmas ()}))
{
  $out->say ($line);
}
$out->say ('');
for my $pkg (sort (@{$generation_data->get_std ()}))
{
  $out->say ('use ', $pkg, ';');
}
$out->say ('');
for my $kgps (@{$generation_data->get_kgps ()})
{
  my $pm = $kgps_to_pm->{$kgps};
  my $parent = $pm->get_parent ();

  for my $line (@{$pm->get_pkg_part ()})
  {
    $out->say ($line);
  }
  $out->say ('');

  if (defined ($parent))
  {
    $out->say ('use parent -norequire, qw(Kgps::', $parent, ');');
    $out->say ('');
  }

  for my $line (@{$pm->get_rest ()})
  {
    $out->say ($line);
  }
  $out->say ('');
}
for my $line (@{$script->get_rest ()})
{
  $out->say ($line);
}
chmod (0755, $out);
$out->close ();

1;
