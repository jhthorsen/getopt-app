use strict;
use warnings;
use Test::More;
use File::Spec::Functions qw(catfile rel2abs);
use Getopt::App -capture;
use Getopt::App::Complete qw(generate_completion_script complete_reply);

my $script = rel2abs(catfile qw(example bin cool));
plan skip_all => "$script" unless -x $script;

subtest 'generate_completion_script - bash' => sub {
  local $ENV{SHELL} = '/usr/bin/bash';
  like generate_completion_script(), qr{^complete -o default -C .* complete.t;}s, 'complete';
};

subtest 'generate_completion_script - zsh' => sub {
  local $ENV{SHELL} = '/bin/zsh';
  like generate_completion_script(), qr{^_complete_t\(\)}s,                     'complete function';
  like generate_completion_script(), qr{COMP_LINE=.*COMP_POINT=.*COMP_SHELL=}s, 'environment';
  like generate_completion_script(), qr{compctl -f -K _complete_t complete\.t;}s, 'complete';
};

subtest 'complete_reply - disabled' => sub {
  local $ENV{COMP_POINT};
  is complete_reply(), undef, 'undef';
};

subtest 'complete_reply' => sub {
  local $Getopt::App::OPTIONS = [qw(file=s h v|version)];
  do($script) or die $@;
  test_complete_reply('', 0, [qw(beans coffee help invalid unknown --file -h --version)], 'all');
  test_complete_reply('coff',             4,  [qw(coffee)],               'coffee');
  test_complete_reply('--',               2,  [qw(--file --version)],     'double dash');
  test_complete_reply('--',               1,  [qw(--file -h --version)],  'single dash');
  test_complete_reply('coffee ',          7,  [qw(-h --version --dummy)], 'subcommand');
  test_complete_reply('coffee --',        9,  [qw(--version --dummy)],    'subcommand double dash');
  test_complete_reply('coffee   -- --ve', 15, [qw(--version)],            'subcommand spaces');
};

done_testing;

sub test_complete_reply {
  local $ENV{COMP_LINE}  = join ' ', $0, shift;
  local $ENV{COMP_POINT} = length($0) + 1 + shift;
  note "COMP_LINE='$ENV{COMP_LINE}' ($ENV{COMP_POINT})";
  my ($exp, $desc) = @_;
  my $res = capture(sub { complete_reply('Test::Cool') });
  is_deeply [split /\n/, $res->[0]], $exp, $desc || 'complete_reply' or diag "ERR: $res->[1]";
}
