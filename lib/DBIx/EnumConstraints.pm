use strict;
use warnings FATAL => 'all';

=head1 NAME

DBIx::EnumConstraints - generates enum-like SQL constraints.

=head1 SYNOPSIS

  use DBIx::EnumConstraints;

  my $ec = DBIx::EnumConstraints->new({
	  	name => 'kind', fields => [ [ 'k1', 'a', 'b' ]
					, [ 'k2', 'b' ] ]
  });

  # get enum field definition
  my $edef = $ec->enum_definition;

  # $edef is now 'kind smallint not null check (kind > 0 and kind < 2)'

  # get constraints array
  my @cons = $ec->constraints;

  # @cons is now (
  # 	'constraint k1_has_a check (kind <> 1 or a is not null)'
  #	, 'constraint k1_has_b check (kind <> 1 or a is not null)'
  #	, 'constraint k2_has_b check (kind <> 2 or b is not null)'
  #	, 'constraint k2_has_no_a check (kind <> 2 or a is null)')

=head1 DESCRIPTION

This module generates SQL statements for enforcing enum semantics on the
database columns.

Enum columns is the column which can get one of 1 .. k values. For each of
those values there are other columns which should or should not be null.

For example in the SYNOPSIS above, when C<kind> column is 1 the row should have
both of C<a> and C<b> columns not null. When C<kind> column is 2 the row should
have C<a> but no C<b> columns.

=cut

package DBIx::EnumConstraints;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(name fields optionals));

our $VERSION = '0.01';

=head1 CONSTRUCTORS

=head2 $class->new($args)

C<$args> should be HASH reference containing the following parameters:

=over

=item name

The name of the enum.

=item fields

Array of arrays describing fields dependent on the enum. Each row is index
is the possible value of enum minus 1 (e.g. row number 1 is for enum value 2).

First item in the array is the state name. The rest of the items are field
names. There is a possibility to mark optional fields by using trailing C<?>
(e.g. C<b?> denotes an optional C<b> field.

=back

=cut
sub new {
	my ($class, $args) = @_;
	my $self = $class->SUPER::new($args);
	$self->optionals({});
	for my $f (@{ $self->fields }) {
		my $fn = $f->[0];
		for my $in (@$f) {
			$self->optionals->{$fn}->{$in} = 1 if ($in =~ s/\?$//);
		}
	}
	return $self;
}

=head1 METHODS

=head2 $self->enum_definition

Returns the definition of enum column. See SYNOPSIS for example.

=cut
sub enum_definition {
	my $self = shift;
	my $n = $self->name;
	return sprintf("$n smallint not null check ($n > 0 and $n < %d)"
			, @{ $self->fields } + 1);
}

=head2 $self->for_each_kind($callback)

Runs C<$callback> over registered enum states. For each state passes state
name, fields which are in the state and fields which are out of the state.

The fields are passed as ARRAY references.

=cut
sub for_each_kind {
	my ($self, $cb) = @_;
	my $fs = $self->fields;
	my %all;
	for my $f (@$fs) {
		my ($fn, @deps) = @$f;
		$all{$_} = 1 for @deps;
	}
	for my $f (@$fs) {
		my ($fn, @deps) = @$f;
		my %not = %all;
		delete $not{$_} for @deps;
		$cb->($fn, \@deps, [ sort keys %not ]);
	}
}

=head2 $self->constraints

Returns the list of generated constraints. See SYNOPSIS above for an example.

=cut
sub constraints {
	my $self = shift;
	my $i = 1;
	my $n = $self->name;
	my @res;
	$self->for_each_kind(sub {
		my ($fn, $ins, $outs) = @_;
		push @res, "constraint $fn\_has_$_ check "
				. "($n <> $i or $_ is not null)"
			for grep { !$self->optionals->{$fn}->{$_} } @$ins;
		push @res, "constraint $fn\_has_no_$_ check "
				. "($n <> $i or $_ is null)" for @$outs;
		$i++;
	});
	return @res;
}

1;

=head1 AUTHOR

	Boris Sukholitko
	CPAN ID: BOSU
	
	boriss@gmail.com
	
=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

