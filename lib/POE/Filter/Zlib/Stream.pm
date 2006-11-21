package POE::Filter::Zlib::Stream;

use strict;
use Carp;
use Compress::Zlib;
use vars qw($VERSION);
use base qw(POE::Filter);

$VERSION = '1.8';

sub new {
  my $type = shift;
  croak "$type requires an even number of parameters" if @_ % 2;
  my $buffer = { @_ };
  $buffer->{ lc $_ } = delete $buffer->{ $_ } for keys %{ $buffer };
  $buffer->{BUFFER} = '';
  delete $buffer->{deflateopts} unless ref ( $buffer->{deflateopts} ) eq 'HASH';
  $buffer->{d} = deflateInit( %{ $buffer->{deflateopts} } );
  unless ( $buffer->{d} ) {
	warn "Failed to create deflate stream\n";
	return;
  }
  delete $buffer->{inflateopts} unless ref ( $buffer->{inflateopts} ) eq 'HASH';
  $buffer->{i} = inflateInit( %{ $buffer->{inflateopts} } );
  unless ( $buffer->{i} ) {
	warn "Failed to create inflate stream\n";
	return;
  }
  return bless $buffer, $type;
}

sub get_one_start {
  my ($self, $raw_lines) = @_;
  $self->{BUFFER} .= join '', @{ $raw_lines };
}

sub get_one {
  my $self = shift;

  return [ ] unless length $self->{BUFFER};
  my ($out, $status) = $self->{i}->inflate( \$self->{BUFFER} );
  unless ( $status == Z_OK or $status == Z_STREAM_END ) {
	warn "Couldn\'t inflate buffer\n";
	return [ ];
  }
  return [ $out ];
}

sub put {
  my ($self, $events) = @_;
  my $raw_lines = [];

  foreach my $event (@$events) {
	my ($dout,$dstat) = $self->{d}->deflate( $event );
	unless ( $dstat == Z_OK ) {
	  warn "Couldn\'t deflate: $event\n";
	  next;
	}
	my ($fout,$fstat) = $self->{d}->flush( Z_SYNC_FLUSH );
	unless ( $fstat == Z_OK ) {
	  warn "Couldn\'t flush/deflate: $event\n";
	  next;
	}
	push @$raw_lines, $dout . $fout;
  }
  return $raw_lines;
}

1;

__END__

=head1 NAME

POE::Filter::Zlib::Stream -- A POE filter wrapped around Compress::Zlib deflate and inflate.

=head1 SYNOPSIS

    use POE::Filter::Zlib::Stream;

    my $filter = POE::Filter::Zlib::Stream->new( deflateopts => { -Level => 9 } );
    my $scalar = 'Blah Blah Blah';
    my $compressed_array   = $filter->put( [ $scalar ] );
    my $uncompressed_array = $filter->get( $compressed_array );

    use POE qw(Filter::Stackable Filter::Line Filter::Zlib::Stream);

    my ($filter) = POE::Filter::Stackable->new();
    $filter->push( POE::Filter::Zlib::Stream->new(),
		   POE::Filter::Line->new( InputRegexp => '\015?\012', OutputLiteral => "\015\012" ),

=head1 DESCRIPTION

POE::Filter::Zlib::Stream provides a POE filter for performing compression/uncompression using L<Compress::Zlib>. It is
suitable for use with L<POE::Filter::Stackable>.

Unlike L<POE::Filter::Zlib> this filter uses deflate and inflate, not the higher level compress and uncompress.

Ideal for streaming compressed data over sockets.

=head1 CONSTRUCTOR

=over

=item new

Creates a new POE::Filter::Zlib::Stream object. Takes some optional arguments:

  "deflateopts", a hashref of options to be passed to deflateInit();
  "inflateopts", a hashref of options to be passed to inflateInit();

Consult L<Compress::Zlib> for more detail regarding these options.

=back

=head1 METHODS

=over

=item get

=item get_one_start

=item get_one

Takes an arrayref which is contains streams of compressed input. Returns an arrayref of uncompressed streams.

=item put

Takes an arrayref containing streams of uncompressed output, returns an arrayref of compressed streams.

=back

=head1 AUTHOR

Chris Williams <chris@bingosnet.co.uk>

=head1 SEE ALSO

L<POE::Filter>

L<Compress::Zlib>

L<POE::Filter::Stackable>

=cut

