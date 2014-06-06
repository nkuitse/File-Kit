package File::Kit;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.02';

use constant APPEND => '>>';
use constant WRITE  => '>';

sub new {
    my $cls = shift;
    unshift @_, 'path' if @_ % 2;
    my %self = @_;
    my $path = $self{'_path'} = delete $self{'path'};
    my $self = bless \%self, $cls;
    -d $path ? $self->load($path) : $self->create($path) if defined $path;
    return $self;
}

sub load {
    my ($self, $path) = @_;
    %$self = ( %$self, %{ rdkvfile("$path/kit.kv") } );
    return $self;
}

sub create {
    my ($self, $path) = @_;
    mkdir $path or die "Can't make new kit $path: $!";
    wrkvfile("$path/kit.kv", %$self);
}

sub edit {
    my ($self) = @_;
    $self->{'_edits'} = [];
    return $self;
}

sub add {
    my $self = shift;
    push @{ $self->{'_edits'} ||= [] }, [ APPEND, 'files.kv', @_ ];
    return $self;
}

sub save {
    my ($self) = @_;
    my %fh;
    foreach (@{ $self->{'_edits'} || [] }) {
        my ($action, @params) = @$_;
        if ($action eq APPEND) {
            my $f = shift @params;
            my $fh = $fh{$f};
            if (!$fh) {
                open $fh, '>>', $self->path($f) or die;
                $fh{$f} = $fh;
            }
            wrkvfile($fh, @params, { 'append' => 1 });
        }
    }
}

sub files {
    my ($self) = @_;
    my $files = $self->{'files'} ||= [];
    return @$files if @$files;
    return @$files = rdkvfile($self->file('files.kv'));
}

sub wrkvfile {
    my $f = shift;
    my $fh;
    my %opt;
    %opt = %{ pop(@_) } if ref($_[-1]) eq 'HASH';
    return if !@_;
    if (ref $f) {
        $fh = $f;
        seek $fh, 0, 2;  # Seek to end of file
    }
    else {
        my $mode = $opt{'append'} ? '>>' : '>';
        open $fh, $mode, $f or die "Can't open kit $f: $!";
    }
    my %kv = @_;
    my $printed;
    foreach my $k (sort grep { !/^_/ } keys %kv) {
        my $v = $kv{$k};
        $printed = 1, print $fh "$k $v\n" if defined $v && !ref $v;
    }
    print $fh "\n" if $printed;
}

sub rdkvfile {
    my ($f) = @_;
    open my $fh, '<', $f or die "Can't open $f: $!";
    my @kv;
    my %kv;
    while (<$fh>) {
        next if /^\s*#.*$/;  # Skip comments
        chomp;
        if (/^\s*$/) {
            push @kv, { %kv };
            %kv = ();
            next;
        }
        my ($key, $val) = split /\s+/, $_, 2;
        $kv{$key} = $val;
    }
    close $fh;
    die "Empty file: $f" if !@kv;
    return @kv if wantarray;
    die "Multiple values in file: $f" if @kv > 1;
    return $kv[0];
}

1;

=pod

=head1 NAME

File::Kit - Gather files and their metadata together in one place

=head1 SYNOPSIS

    $kit = File::Kit->new($dir);
    $kit = File::Kit->new(%meta);
    $kit = File::Kit->create($dir, %meta);
    ...
    $kit->save;

=cut
