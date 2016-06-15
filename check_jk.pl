#!/usr/bin/env perl 

# Released under the GNU General Public License
# Jörg Kost joerg.kost@gmx.com

use strict;
my %checks;
my $collector;
my $collector_return = 0;
my $count            = 0;
my %include;

# Read recursive files
read_configuration(
    first_file_match(
        '/etc/nagios/nrpe.cfg', '/usr/local/nagios/etc/nrpe.cfg',
        '/etc/nrpe.cfg',        'nrpe.cfg'
    )
);

foreach ( keys(%checks) ) {
    my ( $ex, $data ) = run_nagios( $checks{$_}, $_ );
    if ( $ex > 0 ) {
        $collector_return = $ex if $ex > $collector_return;
        $collector .= $data;
    }
    $count++;
}

print 'CRITICAL: No checks found' if $count == 0;
print 'Everything OK'             if $collector_return == 0 && $count > 0;
print "WARNING: $collector"                if $collector_return != 0;
exit $collector_return;

sub read_configuration {
    open( my $fh, "<", $_[0] );
    while (<$fh>) {
        if (/check_jk/) { next }
        if (/^command\[(.+)]\s?=\s?(.+)/) { $checks{$1} = $2; next; }
        if (/^include_dir=(.+)$/) {
            my @files = glob("$1/*.cfg");
            foreach (@files) {
                read_configuration($_) if !exists $include{$_};
                $include{$_} = 1;
            }
            next;
        }
    }
    close($fh);
}

sub run_nagios {
    $_[0] =~ /([\w\/]+)\s?/g;
    if ( $1 !~ /^sudo/ && !-x $1 ) { return ( 2, "$_[1] not executable\n" ); }
    open NG, "$_[0] |" or return (2, "error running command $!");
    my @data = <NG>;
    my $scal = join( ",", @data );
    close NG;
    my $ex = $? >> 8;
    return ( $ex, $scal );
}

sub first_file_match {
    foreach (@_) {
        if ( -r $_ ) { return $_; }
    }
}

