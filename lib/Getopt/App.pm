package Getopt::App;
use feature qw(:5.16);
use strict;
use warnings;
use utf8;

use Carp qw(croak);
use Getopt::Long ();
use Scalar::Util qw(looks_like_number);

sub import {
  my ($class, @flags) = @_;

  my $caller = caller;
  croak "@{[(caller)[1]]} must have a package definition!" if $caller eq 'main';

  $_->import for qw(strict warnings utf8);
  feature->import(':5.16');

  no strict qw(refs);
  *{"$caller\::new"} = \&new unless $caller->can('new');
  *{"$caller\::run"} = \&run;
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
  my @configure
    = $app->can('getopt_configure')
    ? $app->getopt_configure
    : qw(bundling no_auto_abbrev no_ignore_case pass_through require_order);

  my $prev  = Getopt::Long::Configure(@configure);
  my $valid = Getopt::Long::GetOptionsFromArray($argv, $app, @rules) ? 1 : 0;
  Getopt::Long::Configure($prev);
  _hook($app, post_process_argv => $argv, {valid => $valid});

  my $exit_value = $valid ? $app->$cb(@$argv) : 1;
  $exit_value = 0 unless looks_like_number $exit_value;
  exit(int $exit_value) unless $Getopt::App::APP_CLASS;
  return $exit_value;
}

sub _hook {
  my ($app, $name) = (shift, shift);
  my $hook = $app->can("getopt_$name") || __PACKAGE__->can("_hook_$name");
  $app->$hook(@_);
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
  sub getopt_post_process_argv ($app, $argv) { ... }
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

  # Sourcing the script returns a callback
  my $app = do(abs_path('./bin/myapp'));

  # The callback can be called with any @ARGV
  is $app->([qw(--name superwoman)]), 42, 'script ran as expected';

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

=head1 EXPORTED FUNCTIONS

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

  package My::Script;
  use Getopt::App;
  use Getopt::App -signatures;

The above will save you from a lot of typing, since it's the same as:

  use strict;
  use warnings;
  use utf8;
  use feature ':5.16';
  sub run { Getopt::App::run(@_) }

  # Optional - Requires perl 5.26
  use experimental qw(signatures)

Note that the file this module is imported into I<must> have a package
definition!

=head1 COPYRIGHT AND LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
