package POE::Filter::Zlib;

use strict;
use Carp;
use Compress::Zlib qw(compress uncompress Z_DEFAULT_COMPRESSION);
use vars qw($VERSION);
use base qw(POE::Filter);

$VERSION = '1.90';

sub new {
  my $type = shift;
  croak "$type requires an even number of parameters" if @_ % 2;
  my $buffer = { @_ };
  $buffer->{ lc $_ } = delete $buffer->{ $_ } for keys %{ $buffer };
  $buffer->{BUFFER} = [];
  return bless $buffer, $type;
}

sub level {
  my $self = shift;
  my $level = shift;
  $self->{level} = $level if defined $level;
}

sub get {
  my ($self, $raw_lines) = @_;
  my $events = [];

  foreach my $raw_line (@$raw_lines) {
	if ( my $line = uncompress( $raw_line ) ) {
		push @$events, $line;
	} 
	else {
		warn "Couldn\'t uncompress input: $raw_line\n";
		#push @$events, $raw_line;
	}
  }
  return $events;
}

sub get_one_start {
  my ($self, $raw_lines) = @_;
  push @{ $self->{BUFFER} }, $_ for @{ $raw_lines };
}

sub get_one {
  my $self = shift;
  my $events = [];

  if ( my $raw_line = shift @{ $self->{BUFFER} } ) {
	if ( my $line = uncompress( $raw_line ) ) {
		push @$events, $line;
	} 
	else {
		warn "Couldn\'t uncompress input: $raw_line\n";
		#push @$events, $raw_line;
	}
  }
  return $events;
}

sub put {
  my ($self, $events) = @_;
  my $raw_lines = [];

  foreach my $event (@$events) {
	if ( my $line = compress( $event, ( $self->{level} || Z_DEFAULT_COMPRESSION ) ) ) {
		push @$raw_lines, $line;
	} 
	else {
		warn "Couldn\'t compress output: $event\n";
	}
  }
  return $raw_lines;
}

1;

__END__

=head1 NAME

POE::Filter::Zlib -- A POE filter wrapped around Compress::Zlib

=head1 SYNOPSIS

    use POE::Filter::Zlib;

    my $filter = POE::Filter::Zlib->new();
    my $scalar = 'Blah Blah Blah';
    my $compressed_array   = $filter->put( [ $scalar ] );
    my $uncompressed_array = $filter->get( $compressed_array );

    use POE qw(Filter::Stackable Filter::Line Filter::Zlib);

    my ($filter) = POE::Filter::Stackable->new();
    $filter->push( POE::Filter::Zlib->new(),
		   POE::Filter::Line->new( InputRegexp => '\015?\012', OutputLiteral => "\015\012" ),

=head1 DESCRIPTION

POE::Filter::Zlib provides a POE filter for performing compression/uncompression using L<Compress::Zlib>. It is
suitable for use with L<POE::Filter::Stackable>.

This filter is not ideal for streaming compressed data over sockets etc. as it employs compress and uncompress zlib functions.

L<POE::Filter::Zlib::Stream> is recommended for that type of activity.

=head1 CONSTRUCTOR

=over

=item new

Creates a new POE::Filter::Zlib object. Takes one optional argument, 

  'level': the level of compression to employ.

Consult L<Compress::Zlib> for details.

=back

=head1 METHODS

=over

=item get

=item get_one_start

=item get_one

Takes an arrayref which is contains lines of compressed input. Returns an arrayref of uncompressed lines.

=item put

Takes an arrayref containing lines of uncompressed output, returns an arrayref of compressed lines.

=item level

Sets the level of compression employed to the given value. If no value is supplied, returns the current level setting.

=back

=head1 AUTHOR

Chris Williams <chris@bingosnet.co.uk>

=head1 SEE ALSO

L<POE>

L<POE::Filter>

L<POE::Filter::Zlib::Stream>

L<Compress::Zlib>

L<POE::Filter::Stackable>

=cut

