#!/usr/bin/env perl
package Test::Cool::coffee;
use Getopt::App;
run(sub { shift; print join('/', __FILE__, @_), "\n"; return 12 });
