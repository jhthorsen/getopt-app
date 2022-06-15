package Getopt::App::Complete;
use feature qw(:5.16);
use strict;
use warnings;
use utf8;
use Cwd qw(abs_path);
use File::Basename qw(basename);
use Exporter qw(import);

our @EXPORT_OK = qw(complete_reply generate_completion_script);

require Getopt::App;
our $call_maybe = do { no warnings qw(once); $Getopt::App::call_maybe };

sub complete_reply {
  return undef unless defined $ENV{COMP_POINT};

  my $app_class   = shift;
  my $app         = $app_class->new;
  my $subcommands = $app->$call_maybe('getopt_subcommands') || [];
  my ($script, @argv) = split /\s+/, $ENV{COMP_LINE};

  # Recurse into subcommand
  if (@argv and $argv[0] =~ m!^\w! and @$subcommands) {
    for my $subcommand (@$subcommands) {
      next unless $argv[0] eq $subcommand->[0];
      my $name   = $argv[0];
      my $subapp = $app->$call_maybe(getopt_load_subcommand => $subcommand, \@argv);
      local $ENV{COMP_LINE}  = $ENV{COMP_LINE} =~ s!(\s+$name\s+)! !r;
      local $ENV{COMP_POINT} = $1 ? ($ENV{COMP_POINT} + 1 - length $1) : length $ENV{COMP_LINE};
      $subapp->([]);
      return 0;
    }
  }

  # List matching subcommands
  my $got = substr($ENV{COMP_LINE}, 0, $ENV{COMP_POINT}) =~ m!(\S+)$! ? $1 : '';
  for my $subcommand (@$subcommands) {
    next unless index($subcommand->[0], $got) == 0;
    say $subcommand->[0];
  }

  # List matching command line options
  no warnings q(once);
  for (@{$Getopt::App::OPTIONS || []}) {
    my $opt = $_;
    $opt =~ s!(=[si][@%]?|\!|\+|\s)(.*)!!;
    ($opt) = sort { length $b <=> length $a } split /\|/, $opt;    # use --version instead of -v
    $opt = length($opt) == 1 ? "-$opt" : "--$opt";
    next unless index($opt, $got) == 0;
    say $opt;
  }

  return 0;
}

sub generate_completion_script {
  my $script_path = abs_path($0);
  my $script_name = basename($0);
  my $shell       = ($ENV{SHELL} || 'bash') =~ m!\bzsh\b! ? 'zsh' : 'bash';

  if ($shell eq 'zsh') {
    my $function = '_' . $script_name =~ s!\W!_!gr;
    return <<"HERE";
$function() {
  read -l; local l="\$REPLY";
  read -ln; local p="\$REPLY";
  reply=(\$(COMP_LINE="\$l" COMP_POINT="\$p" COMP_SHELL="zsh" $script_path));
};

compctl -f -K $function $script_name;
HERE
  }
  else {
    return "complete -o default -C $script_path $script_name;\n";
  }
}

1;

=encoding utf8

=head1 NAME

Getopt::App::Complete - Add autocompletion to you Getopt::App script

=head1 SYNOPSIS

  use Getopt::App -complete;
  run(
    'h                      # Print help',
    'bash-completion-script # Print autocomplete script',
    sub {
      my ($app, @args) = @_;
      return print generate_completion_script() if $app->{'bash-completion-script'};
      return print extract_usage()              if $app->{h};
    },
  );

=head1 DESCRIPTION

L<Getopt::App::Complete> contains helper functions for adding autocompletion to
your L<Getopt::App> powered script.

This module is currently EXPERIMENTAL.

=head1 EXPORTED FUNCTIONS

=head2 complete_reply

  $int = complete_reply($app_class);

This function is automatically called by L<Getopt::App/run> when loaded with
the C<-complete> flag. Returns C<0> if the C<COMP_POINT> environment variable
is set and C<undef> if not.

This function will print completion options based on C<COMP_POINT> and
C<COMP_LINE> to STDOUT, and is aware of subcommands.

=head2 generate_completion_script

  $str = generate_completion_script();

This function will detect if the C<bash> or C<zsh> shell is in use and return
the appropriate initialization commands.

=head1 SEE ALSO

L<Getopt::App>

=cut
