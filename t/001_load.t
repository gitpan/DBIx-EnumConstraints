use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;

BEGIN { use_ok('DBIx::EnumConstraints'); }

my $ec = DBIx::EnumConstraints->new({
	name => 'kind', fields => [
		[ qw(k1 a b c) ]
		, [ qw(k2 b d) ]
		, [ qw(k3 c) ]
	],
});
isa_ok($ec, 'DBIx::EnumConstraints');

is($ec->enum_definition
	, 'kind smallint not null check (kind > 0 and kind < 4)');
is_deeply([ $ec->constraints ], [
'constraint k1_has_a check (kind <> 1 or a is not null)'
, 'constraint k1_has_b check (kind <> 1 or b is not null)'
, 'constraint k1_has_c check (kind <> 1 or c is not null)'
, 'constraint k1_has_no_d check (kind <> 1 or d is null)'
, 'constraint k2_has_b check (kind <> 2 or b is not null)'
, 'constraint k2_has_d check (kind <> 2 or d is not null)'
, 'constraint k2_has_no_a check (kind <> 2 or a is null)'
, 'constraint k2_has_no_c check (kind <> 2 or c is null)'
, 'constraint k3_has_c check (kind <> 3 or c is not null)'
, 'constraint k3_has_no_a check (kind <> 3 or a is null)'
, 'constraint k3_has_no_b check (kind <> 3 or b is null)'
, 'constraint k3_has_no_d check (kind <> 3 or d is null)'
]);

my (@names, @in, @out);
$ec->for_each_kind(sub {
	my ($n, $ins, $outs) = @_;
	push @names, $n;
	push @in, $ins;
	push @out, $outs;
});
is_deeply(\@names, [ qw(k1 k2 k3) ]);
is_deeply(\@in, [ [ qw(a b c) ], [ qw(b d) ], [ 'c' ] ]);
is_deeply(\@out, [ [ qw(d) ], [ qw(a c) ], [ qw(a b d) ] ]);

# test optional
my $ec2 = DBIx::EnumConstraints->new({
	name => 'kind', fields => [
		[ qw(k1 a) ]
		, [ qw(k2 b?) ]
	],
});

is_deeply([ $ec2->constraints ], [
'constraint k1_has_a check (kind <> 1 or a is not null)'
, 'constraint k1_has_no_b check (kind <> 1 or b is null)'
# k2_has_b is empty because it is optional
, 'constraint k2_has_no_a check (kind <> 2 or a is null)'
]);
