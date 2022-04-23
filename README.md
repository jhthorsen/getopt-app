# NAME

Getopt::App - Write and test your script with ease

# SYNOPSIS

## The script file

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

## Running the script

The example script above can be run like any other script:

    $ my-script --name superwoman; # prints "superwoman"
    $ echo $? # 42

## Testing

    use Test::More;
    use Cwd qw(abs_path);

    # Sourcing the script returns a callback
    my $app = do(abs_path('./bin/myapp'));

    # The callback can be called with any @ARGV
    is $app->([qw(--name superwoman)]), 42, 'script ran as expected';

    done_testing;

# DESCRIPTION

[Getopt::App](https://metacpan.org/pod/Getopt%3A%3AApp) is a module that helps you structure your scripts and integrates
[Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) with a very simple API. In addition it makes it very easy to
test your script, since the script file can be sourced without actually being
run.

# APPLICATION METHODS

These methods are optional, but can be defined in your script to override the
default behavior.

## getopt\_configure

    @configure = $app->getopt_configure;

This method can be defined if you want ["Configure" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#Configure) to be set up
differently. The default return value is:

    qw(bundling no_auto_abbrev no_ignore_case pass_through require_order)

The default return value is currently EXPERIMENTAL.

## getopt\_post\_process\_argv

    $bool = $app->getopt_post_process_argv([@ARGV], {%state});

This method can be used to post process the options. `%state` contains a key
"valid" which is true or false, depending on the return value from
["GetOptionsFromArray" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#GetOptionsFromArray).

This method can `die` and optionally set `$!` to avoid calling the function
passed to ["run"](#run).

The default behavior is to check if the first item in `$argv` starts with a
hyphen, and `die` with an error message if so:

    Invalid argument or argument order: @$argv\n

# EXPORTED FUNCTIONS

## new

    my $obj = new($class, %args);
    my $obj = new($class, \%args);

This function is exported into the caller package so we can construct a new
object:

    my $app = Application::Class->new(\%args);

It will _not_ be exported if it is already defined in the script.

## run

    # Run a code block on valid @ARGV
    run(@rules, sub ($app, @extra) { ... });

    # For testing
    my $cb = run(@rules, sub ($app, @extra) { ... });
    my $exit_value = $cb->([@ARGV]);

["run"](#run) can be used to call a callback when valid command line options is
provided. On invalid arguments, warnings will be issued and the program exit
with `$?` set to 1.

`$app` inside the callback is a hash blessed to the caller package. The keys
in the hash are the parsed command line options, while `@extra` is the extra
unparsed command line options.

`@rules` are the same options as [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) can take. Example:

    # app.pl -vv --name superwoman -o OptX cool beans
    run(qw(h|help v+ name=s o=s@), sub ($app, @extra) {
      die "No help here" if $app->{h};
      warn $app->{v};    # 2
      warn $app->{name}; # "superwoman"
      warn @{$app->{o}}; # "OptX"
      warn @extra;       # "cool beans"
      return 0;          # Used as exit code
    });

In the example above, `@extra` gets populated, since there is a non-flag value
"cool" after a list of valid command line options.

# METHODS

## import

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

# COPYRIGHT AND LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

# AUTHOR

Jan Henning Thorsen - `jhthorsen@cpan.org`
