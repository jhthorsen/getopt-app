# NAME

Getopt::App - Write and test your script with ease

# SYNOPSIS

## The script file

    #!/usr/bin/env perl
    package My::Script;
    use Getopt::App -complete, -signatures;

    # See "APPLICATION METHODS"
    sub getopt_post_process_argv ($app, $argv, $state) { ... }
    sub getopt_configure ($app) { ... }

    # run() must be the last statement in the script
    run(

      # Specify your Getopt::Long options and optionally a help text
      'h|help            # Output help',
      'v+                # Verbose output',
      'name=s            # Specify a name',
      'completion-script # Print autocomplete script',

      # Here is the main sub that will run the script
      sub ($app, @extra) {
        return print generate_completion_script() if $app->{'completion-script'};
        return print extract_usage()              if $app->{h};
        say $app->{name} // 'no name';            # Access command line options
        return 42;                                # Reture value is used as exit code
      }
    );

## Running the script

The example script above can be run like any other script:

    $ my-script --name superwoman; # prints "superwoman"
    $ echo $? # 42

## Testing

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

## Subcommands

    #!/usr/bin/env perl
    # Define a package to avoid mixing methods after loading the subcommand script
    package My::App::main;
    use Getopt::App -complete;

    # getopt_subcommands() is called by Getopt::App
    sub getopt_subcommands {
      my $app = shift;

      return [
        ['find',   '/path/to/subcommand/find.pl',   'Find things'],
        ['update', '/path/to/subcommand/update.pl', 'Update things'],
      ];
    }

    # run() is only called if there are no matching sub commands
    run(
      'h                 # Print help',
      'completion-script # Print autocomplete script',
      sub {
        my ($app, @args) = @_;
        return print generate_completion_script() if $app->{'completion-script'};
        return print extract_usage();
      }
    );

See ["getopt\_subcommands"](#getopt_subcommands) and [https://github.com/jhthorsen/getopt-app/tree/main/example](https://github.com/jhthorsen/getopt-app/tree/main/example)
for more details.

# DESCRIPTION

[Getopt::App](https://metacpan.org/pod/Getopt%3A%3AApp) is a module that helps you structure your scripts and integrates
[Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) with a very simple API. In addition it makes it very easy to
test your script, since the script file can be sourced without actually being
run.

[Getopt::App](https://metacpan.org/pod/Getopt%3A%3AApp) also supports infinite nested [subcommands](#getopt_subcommands)
and a method for [bundling](#bundle) this module with your script to prevent
depending on a module from CPAN.

# APPLICATION METHODS

These methods are optional, but can be defined in your script to override the
default behavior.

## getopt\_complete\_reply

    $app->getopt_complete_reply;

This method will be called instead of the ["run"](#run) callback when the
`COMP_LINE` and `COMP_POINT` environment variables are set. The default
implementation will call ["complete\_reply" in Getopt::App::Complete](https://metacpan.org/pod/Getopt%3A%3AApp%3A%3AComplete#complete_reply).

See also "Completion" under ["import"](#import).

## getopt\_configure

    @configure = $app->getopt_configure;

This method can be defined if you want ["Configure" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#Configure) to be set up
differently. The default return value is:

    qw(bundling no_auto_abbrev no_ignore_case pass_through require_order)

The default return value is currently EXPERIMENTAL.

## getopt\_load\_subcommand

    $code = $app->getopt_load_subcommand($subcommand, [@ARGV]);

Takes the subcommand found in the ["getopt\_subcommands"](#getopt_subcommands) list and the command
line arguments and must return a CODE block. The default implementation is
simply:

    $code = do($subcommand->[1]);

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

## getopt\_post\_process\_exit\_value

    $exit_value = $app->getopt_post_process_exit_value($exit_value);

A method to be called after the ["run"](#run) function has been called.
`$exit_value` holds the return value from ["run"](#run) which could be any value,
not just 0-255. This value can then be changed to change the exit value from
the program.

    sub getopt_post_process_exit_value ($app, $exit_value) {
      return int(1 + rand 10);
    }

## getopt\_pre\_process\_argv

    $app->getopt_pre_process_argv($argv);

This method can be defined to pre-process `$argv` before it is passed on to
["GetOptionsFromArray" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#GetOptionsFromArray). Example:

    sub getopt_pre_process_argv ($app, $argv) {
      $app->{first_non_option} = shift @$argv if @$argv and $argv->[0] =~ m!^[a-z]!;
    }

This method can `die` and optionally set `$!` to avoid calling the actual
["run"](#run) function.

## getopt\_subcommands

    $subcommands = $app->getopt_subcommands;

This method must be defined in the script to enable sub commands. The return
value must be either `undef` to disable subcommands or an array-ref of
array-refs like this:

    [["subname", "/abs/path/to/sub-command-script", "help text"], ...]

The first element in each array-ref "subname" will be matched against the first
argument passed to the script, and when matched the "sub-command-script" will
be sourced and run inside the same perl process. The sub command script must
also use [Getopt::App](https://metacpan.org/pod/Getopt%3A%3AApp) for this to work properly.

The sub-command will have `$Getopt::App::SUBCOMMAND` set to the item found in
the list.

See [https://github.com/jhthorsen/getopt-app/tree/main/example](https://github.com/jhthorsen/getopt-app/tree/main/example) for a working
example.

## getopt\_unknown\_subcommand

    $exit_value = $app->getopt_unknown_subcommand($argv);

Will be called when ["getopt\_subcommands"](#getopt_subcommands) is defined but `$argv` does not
match an item in the list. Default behavior is to `die` with an error message:

    Unknown subcommand: $argv->[0]\n

Returning `undef` instead of dying or a number (0-255) will cause the ["run"](#run)
callback to be called.

# EXPORTED FUNCTIONS

## capture

    use Getopt::App -capture;
    my $app = do '/path/to/bin/myapp';
    my $array_ref = capture($app, [@ARGV]); # [$stdout, $stderr, $exit_value]

Used to run an `$app` and capture STDOUT, STDERR and the exit value in that
order in `$array_ref`. This function will also capture `die`. `$@` will be
set and captured in the second `$array_ref` element, and `$exit_value` will
be set to `$!`.

This function is a very slimmed down alternative to ["capture" in Capture::Tiny](https://metacpan.org/pod/Capture%3A%3ATiny#capture).
The main reason why ["capture"](#capture) exists in this package is that if something
inside the `$app` throws an exception, then it will be part of the captured
`$stderr` instead of making `capture()` throw an exception.

["capture" in Capture::Tiny](https://metacpan.org/pod/Capture%3A%3ATiny#capture) is however more robust than this function, so please
try [Capture::Tiny](https://metacpan.org/pod/Capture%3A%3ATiny) out in case you find an edge case.

## extract\_usage

    # Default to "SYNOPSIS" from current file
    my $str = extract_usage($section, $file);
    my $str = extract_usage($section);
    my $str = extract_usage();

Will extract a `$section` from POD `$file` and append command line option
descriptions when called from inside of ["run"](#run). Command line options can
optionally have a description with "spaces-hash-spaces-description", like this:

    run(
      'o|option  # Some description',
      'v|verbose # Enable verbose output',
      sub {
        ...
      },
    );

This function will _not_ be exported if a function with the same name already
exists in the script.

## new

    my $obj = new($class, %args);
    my $obj = new($class, \%args);

This function is exported into the caller package so we can construct a new
object:

    my $app = Application::Class->new(\%args);

This function will _not_ be exported if a function with the same name already
exists in the script.

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

## bundle

    Getopt::App->bundle($path_to_script);
    Getopt::App->bundle($path_to_script, $fh);

This method can be used to combine [Getopt::App](https://metacpan.org/pod/Getopt%3A%3AApp) and `$path_to_script` into a
a single script that does not need to have [Getopt::App](https://metacpan.org/pod/Getopt%3A%3AApp) installed from CPAN.
This is for example useful for sysadmin scripts that otherwise only depends on
core Perl modules.

The script will be printed to `$fh`, which defaults to `STDOUT`.

Example usage:

    perl -MGetopt::App -e'Getopt::App->bundle(shift)' ./src/my-script.pl > ./bin/my-script;

## import

    use Getopt::App;
    use Getopt::App 'My::Script::Base', -signatures;
    use Getopt::App -capture;

- Default

        use Getopt::App;

    Passing in no flags will export the default functions ["extract\_usage"](#extract_usage),
    ["new"](#new) and ["run"](#run). In addition it will save you from a lot of typing, since
    it will also import the following:

        use strict;
        use warnings;
        use utf8;
        use feature ':5.16';

- Completion

        use Getopt::App -complete;

    Same as ["Default"](#default), but will also load [Getopt::App::Complete](https://metacpan.org/pod/Getopt%3A%3AApp%3A%3AComplete) and import
    [generate\_completion\_script()](https://metacpan.org/pod/Getopt%3A%3AApp%3A%3AComplete#generate_completion_script).

- Signatures

        use Getopt::App -signatures;

    Same as ["Default"](#default), but will also import ["signatures" in experimental](https://metacpan.org/pod/experimental#signatures). This
    requires Perl 5.20+.

- Class name

        package My::Script::Foo;
        use Getopt::App 'My::Script';

    Same as ["Default"](#default) but will also make `My::Script::Foo` inherit from
    [My::Script](https://metacpan.org/pod/My%3A%3AScript). Note that a package definition is required.

- Capture

        use Getopt::App -capture;

    This will only export ["capture"](#capture).

# COPYRIGHT AND LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

# AUTHOR

Jan Henning Thorsen - `jhthorsen@cpan.org`
