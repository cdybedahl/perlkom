#!/usr/bin/perl -w

# Very ugly example of use of the module. This program generates
# statistics of the subject lines used in a certain conference over
# the last week, and posts the result to that conference. Lots of
# hardcoded things and bugger-all documentation. Good luck!

use Net::Lyskom;

$a = Net::Lyskom->new() or die "Failed to connect to server.\n";
$conf = 6;			# Hardcoded conference number...
$starttime = time-(3600*24*7);	# Hardcoded time...

$text = $a->get_last_text($starttime);

$found = 0;

@raw = ();
%subj = ();

$a->login(8563,"goblin",1)
  or die "Failed to log in: $a->{err_string}\n";

sub count_comments {
    my $s = shift;
    my $res = 0;

    foreach (@{$s->{misc_info}}) {
	$res++ if $_->{type} == 3;
    }
    return $res;
}

sub process_text {
    my $t = shift;
    my $s = $a->get_text_stat($t);
    my $c = $a->get_text($t,0,100);

    $raw[$t]{author} = $s->{author};
    $raw[$t]{ncomments} = count_comments($s);
    $raw[$t]{no} = $t;
    $c =~ s/^([^\n]+).*$/$1/ms;
    $subj{$c}{count}++;
    $subj{$c}{ncomments} += $raw[$t]{ncomments};
}

sub time2str {
    my $time = shift;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
      localtime($time);
    return sprintf "%d/%d %d:%02d:%02d",$mday,$mon+1,$hour,$min,$sec;
}

until ($found) {
    $stat = $a->get_text_stat($text);
    foreach (@{$stat->{misc_info}}) {
	if ($_->{type} == 0 and $_->{data} == $conf) {
	    $found = $text;
	}
    }
    $text = $a->find_next_text_no($text);
}

@tmp = @{$stat->{misc_info}};
until (
       $tmp[0]{type} == 0 or
       $tmp[0]{type} == 1 or
       $tmp[0]{type} == 15 and
       $tmp[0]{data} == $conf
      ) {
    shift @tmp;
}
until ($tmp[0]{type} == 6) {
    shift @tmp;
}
$local_no = $tmp[0]{data};

$res = $a->local_to_global($conf,$local_no,255);

if (!$res) {
    print "$a->{err_string}\n";
    exit 0;
}

while($res->{later_exists}) {
    $t = $res->{range_begin};
    process_text($res->{local}[$t++]) while $res->{local}[$t];
    $res = $a->local_to_global($conf,$res->{range_end},255);
} 
$t = $res->{range_begin};
process_text($res->{local}[$t++]) while $res->{local}[$t];

$starttime = time2str($starttime);
$endtime = time2str(time);

my $out =<<EOF;
Veckans statistik

Antal:   Antal inlägg med en viss ärenderad.
Avg k/i: Genomsnittligt antal kommentarer per inlägg
Ärende:  De första 55 tecknen i ärendet i fråga

Inlägg skrivna mellan $starttime och $endtime har räknats. 
Endast de 25 oftast förekommande ärenderaderna visas!

Antal Avg k/i  Ärende
===== =======  ======
EOF


foreach ((sort {$b->[1] <=> $a->[1]} map {[$_,$subj{$_}{count},$subj{$_}{ncomments}]} keys %subj)[0..24]) {
    next unless $_;
    $out .= sprintf "%5d   %5.3f  %-55s  \n",$_->[1],($_->[2]/$_->[1]),substr($_->[0],0,55);
}

$a->create_text($out,[to => $conf]);

