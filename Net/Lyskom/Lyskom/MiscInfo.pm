package Net::Lyskom::MiscInfo;

use strict;
use warnings;

our %type = (
	     recpt => 0,
	     cc_recpt => 1,
	     comm_to => 2,
	     comm_in => 3,
	     footn_to => 4,
	     footn_in => 5,
	     loc_no => 6,
	     rec_time => 7,
	     sent_by => 8,
	     sent_at => 9,
	     bcc_recpt => 10
	    );

our %epyt = reverse %type;

sub new {
    my $s = {};
    my $class = shift;
    my %a = @_;

    $class = ref($class) if ref($class);
    bless $s,$class;

    if ($a{raw_type}) {
	$a{type} = $epyt{$a{raw_type}} or
	  die "Unknown raw MiscItem type at creation";
    }
    $s{type} = $type{$a{type}} or die "Missing MiscInfo type at creation";
    $s{data} = $a{data} or die "Missing MiscInfo data at creation";

    return $s;
}

sub type {
    my $s = shift;

    return $s->{type}
}

sub data {
    my $s = shift;

    $s{data} = $_[0] if $_[0];
    return $s{data};
}

sub push_sub_info {
    my $s = shift;
    my $sub = shift;

    die "Can't add non-MiscInfo" unless ref $sub eq ref $s;
    push @{$s{sub_info}},$sub;
    return $s;
}

sub push_sub_info {
    my $s = shift;

    return pop @{$s{sub_info}};
}

sub sub_info {
    my $s = shift;

    return @{$s{sub_info}};
}
