package Getopt::App;
use feature qw(:5.16);
use strict;
use warnings;
use utf8;

use Carp qw(croak);
use Getopt::Long ();
use Scalar::Util qw(looks_like_number);

sub capture {
  my ($app, $argv) = @_;
  my ($exit_value, $stderr, $stdout) = (-1, '', '');

  local *STDERR;
  local *STDOUT;
  open STDERR, '>', \$stderr;
  open STDOUT, '>', \$stdout;
  ($!, $@) = (0, '');
  eval {
    $exit_value = $app->($argv || [@ARGV]);
    1;
  } or do {
    print STDERR $@;
    $exit_value = int $!;
  };

  return [$stdout, $stderr, $exit_value];
}

sub import {
  my ($class, @flags) = @_;
  my $caller = caller;

  $_->import for qw(strict warnings utf8);
  feature->import(':5.16');

  my $skip_default;
  no strict qw(refs);
  while (my $flag = shift @flags) {
    if ($flag eq '-capture') {
      *{"$caller\::capture"} = \&capture;
      $skip_default = 1;
    }
    elsif ($flag eq '-signatures') {
      require experimental;
      experimental->import(qw(signatures));
    }
  }

  unless ($skip_default) {
    *{"$caller\::new"} = \&new unless $caller->can('new');
    *{"$caller\::run"} = \&run;
  }
}

sub new {
  my $class = shift;
  bless @_ ? @_ > 1 ? {@_} : {%{$_[0]}} : {}, ref $class || $class;
}

sub run {
  my @rules = @_;
  my $class = $Getopt::App::APP_CLASS || caller;
  return sub { local $Getopt::App::APP_CLASS = $class; run(@_, @rules) }
    if !$Getopt::App::APP_CLASS and defined wantarray;

  my $cb   = pop @rules;
  my $argv = ref $rules[0] eq 'ARRAY' ? shift @rules : [@ARGV];

  my $app = $class->new;
  _hook($app, pre_process_argv => $argv);

  my @configure
    = $app->can('getopt_configure')
    ? $app->getopt_configure
    : qw(bundling no_auto_abbrev no_ignore_case pass_through require_order);

  my $prev  = Getopt::Long::Configure(@configure);
  my $valid = Getopt::Long::GetOptionsFromArray($argv, $app, @rules) ? 1 : 0;
  Getopt::Long::Configure($prev);
  _hook($app, post_process_argv => $argv, {valid => $valid});

  my $exit_value = $valid ? $app->$cb(@$argv) : 1;
  _hook($app, post_process_exit_value => \$exit_value);
  $exit_value = 0       unless looks_like_number $exit_value;
  exit(int $exit_value) unless $Getopt::App::APP_CLASS;
  return $exit_value;
}

sub _hook {
  my ($app, $name) = (shift, shift);
  my $hook = $app->can("getopt_$name") || __PACKAGE__->can("_hook_$name");
  $app->$hook(@_) if $hook;
}

sub _hook_post_process_argv {
  my ($app, $argv, $state) = @_;
  return unless $state->{valid};
  return unless $argv->[0] and $argv->[0] =~ m!^-!;
  $! = 1;
  die "Invalid argument or argument order: @$argv\n";
}

1;

=encoding utf8

=head1 NAME

Getopt::App - Write and test your script with ease

=head1 SYNOPSIS

=head2 The script file

  #!/usr/bin/env perl
  package My::Script;
  use Getopt::App -signatures;

  # See "APPLICATION METHODS"
  sub getopt_post_process_argv ($app, $argv, $state) { ... }
  sub getopt_configure ($app) { ... }

  # run() must be the last statement in the script
  run(

    # Specify your Getopt::Long options
    'h|help',
    'v+',
    'name=s',

    # Here is the main sub that will run the script
    sub ($app, @extra) {
      say $app->{name} // 'no name'; # access command line options
      return 42; # Reture value is used as exit code
    }
  );

=head2 Running the script

The example script above can be run like any other script:

  $ my-script --name superwoman; # prints "superwoman"
  $ echo $? # 42

=head2 Testing

  use Test::More;
  use Cwd qw(abs_path);
  use Getopt::App -capture;

  # Sourcing the script returns a callback
  my $app = do(abs_path('./bin/myapp'));

  # The callback can be called with any @ARGV
  subtest name => sub {
    my $got = capture($app, [qw(--name superwoman)]);
    is $got->[0], "superwoman\n", 'stdout';
    is $got->[1], '', 'stderr';
    is $got->[2], 42, 'exit value';
  };

  done_testing;

=head1 DESCRIPTION

L<Getopt::App> is a module that helps you structure your scripts and integrates
L<Getopt::Long> with a very simple API. In addition it makes it very easy to
test your script, since the script file can be sourced without actually being
run.

=head1 APPLICATION METHODS

These methods are optional, but can be defined in your script to override the
default behavior.

=head2 getopt_configure

  @configure = $app->getopt_configure;

This method can be defined if you want L<Getopt::Long/Configure> to be set up
differently. The default return value is:

  qw(bundling no_auto_abbrev no_ignore_case pass_through require_order)

The default return value is currently EXPERIMENTAL.

=head2 getopt_post_process_argv

  $bool = $app->getopt_post_process_argv([@ARGV], {%state});

This method can be used to post process the options. C<%state> contains a key
"valid" which is true or false, depending on the return value from
L<Getopt::Long/GetOptionsFromArray>.

This method can C<die> and optionally set C<$!> to avoid calling the function
passed to L</run>.

The default behavior is to check if the first item in C<$argv> starts with a
hyphen, and C<die> with an error message if so:

  Invalid argument or argument order: @$argv\n

=head2 getopt_post_process_exit_value

  $app->getopt_post_process_exit_value($exit_value_ref);

A hook to be run after the C</run> function has been called. C<$exit_value_ref>
is a scalar ref, holding the return value from L</run> which could be any
value, not just 0-255. This value can then be changed to change the exit value
from the program.

  sub getopt_post_process_exit_value ($app, $exit_value) {
    $$exit_value = int(1 + rand 10);
  }

=head2 getopt_pre_process_argv

  $app->getopt_pre_process_argv($argv);

This method can be defined to pre-process C<$argv> before it is passed on to
L<Getopt::Long/GetOptionsFromArray>. Example:

  sub getopt_pre_process_argv ($app, $argv) {
    $app->{sub_command} = shift @$argv if @$argv and $argv->[0] =~ m!^[a-z]!;
  }

This method can C<die> and optionally set C<$!> to avoid calling the actual
L</run> function.

=head1 EXPORTED FUNCTIONS

=head2 capture

  use Getopt::App -capture;
  my $app = do '/path/to/repo/bin/myapp';
  my $array_ref = capture($app, [@ARGV]); # [$stdout, $stderr, $exit_value]

Used to run an C<$app> and capture STDOUT, STDERR and the exit value in that
order in C<$array_ref>. This function will also capture C<die>. C<$@> will be
set and captured in the second C<$array_ref> element, and C<$exit_value> will
be set to C<$!>.

=head2 new

  my $obj = new($class, %args);
  my $obj = new($class, \%args);

This function is exported into the caller package so we can construct a new
object:

  my $app = Application::Class->new(\%args);

It will I<not> be exported if it is already defined in the script.

=head2 run

  # Run a code block on valid @ARGV
  run(@rules, sub ($app, @extra) { ... });

  # For testing
  my $cb = run(@rules, sub ($app, @extra) { ... });
  my $exit_value = $cb->([@ARGV]);

L</run> can be used to call a callback when valid command line options is
provided. On invalid arguments, warnings will be issued and the program exit
with C<$?> set to 1.

C<$app> inside the callback is a hash blessed to the caller package. The keys
in the hash are the parsed command line options, while C<@extra> is the extra
unparsed command line options.

C<@rules> are the same options as L<Getopt::Long> can take. Example:

  # app.pl -vv --name superwoman -o OptX cool beans
  run(qw(h|help v+ name=s o=s@), sub ($app, @extra) {
    die "No help here" if $app->{h};
    warn $app->{v};    # 2
    warn $app->{name}; # "superwoman"
    warn @{$app->{o}}; # "OptX"
    warn @extra;       # "cool beans"
    return 0;          # Used as exit code
  });

In the example above, C<@extra> gets populated, since there is a non-flag value
"cool" after a list of valid command line options.

=head1 METHODS

=head2 import

  use Getopt::App;
  use Getopt::App @flags;

=over 2

=item * Default

  use Getopt::App;

Passing in no flags will export the default functions L</new> and L</run>. In
addition it will save you from a lot of typing, since it will also import the
following:

  use strict;
  use warnings;
  use utf8;
  use feature ':5.16';

=item * Signatures

  use Getopt::App -signatures;

Same as L</Default>, but will also import L<experimental/signatures>. This
requires Perl 5.20+.

=item * Capture

  use Getopt::App -capture;

This will only export L</capture>.

=back

=head1 COPYRIGHT AND LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
