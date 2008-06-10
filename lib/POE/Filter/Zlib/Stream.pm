package POE::Filter::Zlib::Stream;

use strict;
use warnings;
use Carp;
use Compress::Zlib;
use vars qw($VERSION);
use base qw(POE::Filter);

$VERSION = '2.00';

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
  if (not defined $buffer->{flushtype}) {
  	$buffer->{flushtype} = Z_SYNC_FLUSH;
  }
  return bless $buffer, $type;
}

# use inherited get() from POE::Filter

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
  if ($status == Z_STREAM_END) {
  	$self->{i} = inflateInit( %{ $self->{inflateopts} } );
  }
  return [ $out ];
}

sub get_pending {
  my $self = shift;
  return $self->{BUFFER} ? [ $self->{BUFFER} ] : undef;
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
	my ($fout,$fstat) = $self->{d}->flush( $self->{flushtype} );
	unless ( $fstat == Z_OK ) {
	  warn "Couldn\'t flush/deflate: $event\n";
	  next;
	}
	if ($self->{flushtype} == Z_FINISH) {
  		$self->{d} = deflateInit( %{ $self->{deflateopts} } );
	}
	push @$raw_lines, $dout . $fout;
  }
  return $raw_lines;
}

sub clone {
  my $self = shift;
  my $nself = { };
  $nself->{$_} = $self->{$_} for keys %{ $self };
  $nself->{BUFFER} = '';
  return bless $nself, ref $self;
}

1;

__END__

=head1 NAME

POE::Filter::Zlib::Stream - A POE filter wrapped around Compress::Zlib deflate and inflate.

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

=over 4

=item "deflateopts"

a hashref of options to be passed to deflateInit();

=item "inflateopts"

a hashref of options to be passed to inflateInit();

=item "flushtype"

The type of flush to use when flushing the compressed data. Defaults to
Z_SYNC_FLUSH so you get a single stream, but if there is a
L<POE::Filter::Zlib> on the other end, you want to set this to Z_FINISH.

=back

Consult L<Compress::Zlib> for more detail regarding these options.

=back

=head1 METHODS

=over

=item get

=item get_one_start

=item get_one

Takes an arrayref which is contains streams of compressed input. Returns an arrayref of uncompressed streams.

=item get_pending

Returns any data in a filter's input buffer. The filter's input buffer is not cleared, however.

=item put

Takes an arrayref containing streams of uncompressed output, returns an arrayref of compressed streams.

=item clone

Makes a copy of the filter, and clears the copy's buffer.

=back

=head1 AUTHOR

Chris Williams <chris@bingosnet.co.uk>

Martijn van Beers <martijn@cpan.org>

=head1 LICENSE

Copyright C<(c)> Chris Williams and Martijn van Beers.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<POE::Filter>

L<Compress::Zlib>

L<POE::Filter::Stackable>

=cut

