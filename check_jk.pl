#!/usr/bin/env perl 

# Released under the GNU General Public License v2
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

my %CROSS_TABLE = (
    0 => 0,
    1 => 0,
    2 => 0
    );

foreach ( keys(%checks) ) {
    my ( $ex, $data ) = run_nagios( $checks{$_}, $_ );
    if ( $ex > 0 ) {
        $collector_return = $ex if $ex > $collector_return;
        chomp $data;
        $collector .= " [$_: $data]";
    }
    $CROSS_TABLE{$ex}++;
    $count++;
}

my $summary = "summary of $count [$CROSS_TABLE{0} Good, $CROSS_TABLE{1} Failing, $CROSS_TABLE{2} Damaged]";

print 'CRITICAL: No checks found' if $count == 0;
print "Everything OK: $summary"             if $collector_return == 0 && $count > 0;
print "WARNING: $summary, last warning: $collector"                if $collector_return == 1;
print "CRITICAL: $summary, last critical: $collector"                if $collector_return == 2;

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
    $_[0] =~ /([\w\/\.-]+)\s?/g;
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

