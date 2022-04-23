use Test::More;

my $post_process_argv_app = post_process_argv_app();
my $synopsis_app          = synopsis_app();

subtest import => sub {
  is strict_app(), undef, 'strict_app';
  like $@, qr{Global symbol}, 'error message';

  is no_package_app(), undef, 'no_package_app';
  like $@, qr{must have a package}, 'error message';

  ok My::Script->can('new'), 'new()';
  ok My::Script->can('run'), 'run()';
};

subtest constructor => sub {
  ok +My::Script->new->isa('My::Script'), 'isa';
  is_deeply +My::Script->new,             {}, 'empty';
  is_deeply +My::Script->new(foo => 1),   {foo => 1}, 'list';
  is_deeply +My::Script->new({foo => 1}), {foo => 1}, 'ref';
};

subtest run => sub {
  is $synopsis_app->([]),               42, 'empty';
  is $synopsis_app->([qw(--name foo)]), 0,  'name';
  is $synopsis_app->([qw(-vv)]),        2,  'verbose';

  local $! = 0;
  eval { $synopsis_app->([qw(-v --invalid)]) };
  is int($!), 1, 'invalid args';
  like $@, qr{Invalid argument or argument order: --invalid}, 'error message';
};

subtest post_process_argv => sub {
  is $post_process_argv_app->([]), 3, 'empty exit';
  is_deeply [@main::POST_PROGRESS], [[], {valid => 1}], 'empty args';

  is $post_process_argv_app->([qw(-x)]), 1, 'invalid exit';
  is_deeply [@main::POST_PROGRESS], [[], {valid => 0}], 'invalid args';
};

done_testing;

sub no_package_app {
  eval 'package main; use Getopt::App; 1';
}

sub post_process_argv_app {
  eval <<'HERE' or die $@;
    package My::PostProcess;
    use Getopt::App;
    sub getopt_configure { qw(no_ignore_case) }
    sub getopt_post_process_argv { shift; @main::POST_PROGRESS = @_ }
    run('x=i', sub { 3 });
HERE
}

sub strict_app {
  eval 'package Test::Strict; use Getopt::App; $x = 1';
}

sub synopsis_app {
  eval <<'HERE' or die $@;
    package My::Script;
    use Getopt::App;

    run('h|help', 'v+', 'name=s', sub {
      my ($app, @extra) = @_;
      return defined $app->{v} ? $app->{v} : $app->{name} ? 0 : 42;
    });
HERE
}
