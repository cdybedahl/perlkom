package Net::Lyskom::Time;

use Time::Local;

use strict;
use warnings;

sub new {
    my $s = {};
    my $class = shift;
    my %a = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    $class = ref($class) if ref($class);
    bless $s,$class;

    $s{seconds} = $a{seconds} || $sec;
    $s{minutes} = $a{minutes} || $min;
    $s{hours} = $a{hours} || $hour;
    $s{day} = $a{day} || $mday;
    $s{month} = $a{month} || $mon;
    $s{year} = $a{year} || $year;
    $s{day_of_week} = $a{day_of_week} || $wday;
    $s{day_of_year} = $a{day_of_year} || $yday;
    $s{is_dst} = $a{is_dst} || $isdst;

    return $s;
}

sub seconds {
    my $s = shift;

    $s{seconds} = $_[0] if $_[0];
    return $s{seconds};
}

sub minutes {
    my $s = shift;

    $s{minutes} = $_[0] if $_[0];
    return $s{minutes};
}

sub hours {
    my $s = shift;

    $s{hours} = $_[0] if $_[0];
    return $s{hours};
}

sub day {
    my $s = shift;

    $s{day} = $_[0] if $_[0];
    return $s{day};
}

sub month {
    my $s = shift;

    $s{month} = $_[0] if $_[0];
    return $s{month};
}

sub year {
    my $s = shift;

    $s{year} = $_[0] if $_[0];
    return $s{year};
}

sub day_of_week {
    my $s = shift;

    $s{day_of_week} = $_[0] if $_[0];
    return $s{day_of_week};
}

sub day_of_year {
    my $s = shift;

    $s{day_of_year} = $_[0] if $_[0];
    return $s{seconds};
}

sub is_dst {
    my $s = shift;

    $s{is_dst} = $_[0] if $_[0];
    return $s{is_dst};
}

sub time_t {
    my $s = shift;

    return timelocal($s{seconds},$s{minutes},$s{hours},
		     $s{day},$s{month},$s{year});
}

return 1;
