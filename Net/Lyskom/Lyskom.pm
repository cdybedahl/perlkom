package Net::Lyskom;

use strict;
use IO::Socket;
use Time::Local;

use vars qw{
	    @miscinfo_names
	    @error
	   };


my $debug = 0;

$Net::Lyskom::VERSION = '0.02';

=head1 NAME

Net::Lyskom - Perl module used to talk to LysKOM servers.

=head1 SYNOPSIS

  use Net::Lyskom;

  $a = Net::Lyskom->new();
  $conf = 6;

  $a->login(437,"God",1)
    or die "Failed to log in: $a->{err_string}\n";

  $b = $a->create_text(
	  	       "Testsubject\nA nice and tidy message body.",
		       [to => 437],
		      );

  $b = $a->send_message(7680, "Oook!");

  if ($b) {
      print "Text number $b created.\n";
  } else {
      print "Text creation failed: $a->{err_string}.\n";
  }

=head1 DESCRIPTION

Net::Lyskom is a module used to talk to LysKOM servers. This far
it lacks a lot of functions, but there is enough functions implemented
to program statistic robots and such.

=head2 Metoder

=over

=cut

## Variables

@miscinfo_names = (
		   "Mottagare",
		   "Extra kopie-mottagare",
		   "Kommentar till",
		   "Kommenterad i",
		   "Fotnot till",
		   "Fotnot i",
		   "Lokalt nummer",
		   "Mottagen",
		   "Adderad av",
		   "Adderad vid",
		   "",
		   "",
		   "",
		   "",
		   "",
		   "Blind extra kopie-mottagare"
		  );


@error = qw(no-error
	    unused
	    not-implemented
	    obsolete-call
	    invalid-password
	    string-too-long
	    login-first
	    login-disallowed
	    conference-zero
	    undefined-conference
	    undefined-person
	    access-denied
	    permission-denied
	    not-member
	    no-such-text
	    text-zero
	    no-such-local-text
	    local-text-zero
	    bad-name
	    index-out-of-range
	    conference-exists
	    person-exists
	    secret-public
	    letterbox
	    ldb-error
	    illegal-misc
	    illegal-info-type
	    already-recipient
	    already-comment
	    already-footnote
	    not-recipient
	    not-comment
	    not-footnote
	    recipient-limit
	    comment-limit
	    footnote-limit
	    mark-limit
	    not-author
	    no-connect
	    out-of-memory
	    server-is-crazy
	    client-is-crazy
	    undefined-session
	    regexp-error
	    not-marked
	    temporary-failure
	    long-array
	    anonymous-rejected
	    illegal-aux-item
	    aux-item-permission
	    unknown-async
	    internal-error
	    feature-disabled
	    message-not-sent
	    invalid-membership-type);


## Helper functions


sub debug {
    unless (@_) {
	print STDERR "debug() called without arguments.\n";
	return;
    }
    print STDERR @_ if $debug;
    print STDERR "\n" if $debug;
}

sub holl {
    return length($_[0])."H".$_[0];
}

sub parse_time {
    my @arg = @_;
    my %res;

    ($res{seconds},
     $res{minutes},
     $res{hours},
     $res{day},
     $res{month},
     $res{year},
     $res{day_of_week},
     $res{day_of_year},
     $res{is_dst},
     @arg) = @arg;

    $res{time} = timelocal(
			   $res{seconds},
			   $res{minutes},
			   $res{hours},
			   $res{day},
			   $res{month},
			   $res{year});

    return (\%res,@arg);
}

sub parse_aux_item_array {
    my @arg = @_;
    my @res;
    my ($tmp, $aboundary);

    $tmp = shift @arg;
    $aboundary = shift @arg;
    foreach (0..($tmp-1)) {
	($res[$_],@arg) = parse_aux_item(@arg);
    }
    if ($aboundary eq '{') {
	shift @arg;		# Throw away closing brace, if any
    }
    return (\@res,@arg);
}

sub parse_misc_info_array {
    my @arg = @_;
    my @res;
    my ($tmp, $aboundary);

    $tmp = shift @arg;
    $aboundary = shift @arg;
    foreach (0..($tmp-1)) {
	($res[$_],@arg) = parse_misc_info(@arg);
    }
    if ($aboundary eq '{') {
	shift @arg;		# Throw away closing brace, if any
    }
    return (\@res,@arg);
}

sub parse_misc_info {
    my @arg = @_;
    my %res;

    $res{type} = shift @arg;
    if ($res{type} == 0) {	# recipient
	$res{data} = shift @arg;
    } elsif ($res{type} == 1) {	# cc-recipient
	$res{data} = shift @arg;
    } elsif ($res{type} == 2) {	# comment-to
	$res{data} = shift @arg;
    } elsif ($res{type} == 3) {	# commented-in
	$res{data} = shift @arg;
    } elsif ($res{type} == 4) {	# footnote-to
	$res{data} = shift @arg;
    } elsif ($res{type} == 5) {	# footnoted-in
	$res{data} = shift @arg;
    } elsif ($res{type} == 6) {	# local-no
	$res{data} = shift @arg;
    } elsif ($res{type} == 7) {	# recieved-at
	($res{data},@arg) = parse_time @arg;
    } elsif ($res{type} == 8) {	# sender
	$res{data} = shift @arg;
    } elsif ($res{type} == 9) {	# sent-at
	($res{data},@arg) = parse_time @arg;
    } elsif ($res{type} == 15) { # bcc-recipient
	$res{data} = shift @arg;
    } else {
	debug "Unkown misc-info type: $res{type}\n";
	$res{data} = "BOGUS";
    };

    return (\%res,@arg);
}

sub parse_aux_item {
    my @arg = @_;
    my %res;

    $res{aux_no} = shift @arg;
    $res{tag} = shift @arg;
    $res{creator} = shift @arg;
    ($res{created_at},@arg) = parse_time(@arg);
    $res{flags} = shift @arg;
    $res{inherit_limit} = shift @arg;
    $res{data} = shift @arg;

    return (\%res,@arg);
}

sub parse_conf_stat {
    my @arg = @_;
    my %res;

    $res{name} = shift @arg;
    $res{type} = shift @arg;
    ($res{creation_time},@arg) = parse_time(@arg);
    ($res{last_written},@arg) = parse_time(@arg);
    $res{creator} = shift @arg;
    $res{presentation} = shift @arg;
    $res{supervisor} = shift @arg;
    $res{permitted_submitters} = shift @arg;
    $res{super_conf} = shift @arg;
    $res{msg_of_day} = shift @arg;
    $res{nice} = shift @arg;
    $res{keep_commented} = shift @arg;
    $res{no_of_members} = shift @arg;
    $res{first_local_no} = shift @arg;
    $res{no_of_texts} = shift @arg;
    $res{expire} = shift @arg;
    ($res{aux_items},@arg) = parse_aux_item_array(@arg);

    return \%res;
}

sub parse_text_stat {
    my @arg = @_;
    my %res;

    ($res{creation_time},@arg) = parse_time(@arg);
    $res{author} = shift @arg;
    $res{no_of_lines} = shift @arg;
    $res{no_of_chars} = shift @arg;
    $res{no_of_marks} = shift @arg;
    ($res{misc_info},@arg) = parse_misc_info_array(@arg);
    ($res{aux_items},@arg) = parse_aux_item_array(@arg);
    
    return \%res;
}

sub parse_person_stat {
    my @arg = @_;
    my %res;

    $res{username} = shift @arg;
    $res{privileges} = shift @arg;
    $res{flags} = shift @arg;
    ($res{last_login},@arg) = parse_time(@arg);
    $res{user_area} = shift @arg;
    $res{total_time_present} = shift @arg;
    $res{sessions} = shift @arg;
    $res{created_lines} = shift @arg;
    $res{created_bytes} = shift @arg;
    $res{read_texts} = shift @arg;
    $res{no_of_texts_fetched} = shift @arg;
    $res{created_persons} = shift @arg;
    $res{created_confs} = shift @arg;
    $res{first_created_local_no} = shift @arg;
    $res{created_texts} = shift @arg;
    $res{no_of_marks} = shift @arg;
    $res{no_of_confs} = shift @arg;

    return (\%res,@arg);
}

sub parse_array {
    my @arg = @_;
    my @res;
    my ($tmp, $aboundary);

    $tmp = shift @arg;
    $aboundary = shift @arg;
    foreach (0..($tmp-1)) {
	($res[$_],@arg) = shift @arg;
    }
    if ($aboundary eq '{') {
	shift @arg;		# Throw away closing brace, if any
    }
    return (\@res,@arg);
}

sub parse_membership {
    my @arg = @_;
    my %res;

    $res{position} = shift @arg;
    ($res{last_time_read},@arg) = parse_time(@arg);
    $res{conference} = shift @arg;
    $res{priority} = shift @arg;
    $res{last_text_read} = shift @arg;
    ($res{read_texts},@arg) = parse_array(@arg);
    $res{added_by} = shift @arg;
    ($res{added_at},@arg) = parse_time(@arg);
    $res{type} = shift @arg;

    return (\%res,@arg);
}

sub parse_membership_array {
    my @arg = @_;
    my @res;
    my ($tmp, $aboundary);

    $tmp = shift @arg;
    $aboundary = shift @arg;
    foreach (0..($tmp-1)) {
	($res[$_],@arg) = parse_membership(@arg);
    }
    if ($aboundary eq '{') {
	shift @arg;		# Throw away closing brace, if any
    }

    return @res;
}

sub parse_version_info {
    my @arg = @_;
    my %res;

    $res{protocol_version} = shift @arg;
    $res{server_software} = shift @arg;
    $res{software_version} = shift @arg;

    return \%res;
}

sub parse_conf_z_info {
    my @arg = @_;
    my %res;

    $res{name} = shift @arg;
    $res{type} = shift @arg;
    $res{conf_no} = shift @arg;

    return (\%res,@arg);
}

sub parse_conf_z_info_array {
    my @arg = @_;
    my @res;
    my ($tmp, $aboundary);

    $tmp = shift @arg;
    $aboundary = shift @arg;
    foreach (0..($tmp-1)) {
	($res[$_],@arg) = parse_conf_z_info(@arg);
    }
    if ($aboundary eq '{') {
	shift @arg;		# Throw away closing brace, if any
    }
    return @res;
}

sub parse_text_mapping {
    my @arg = @_;
    my %res;
    my $densep;

    $res{range_begin} = shift @arg;
    $res{range_end} = shift @arg;
    $res{later_exists} = shift @arg;
    $densep = shift @arg;

    if ($densep) {
	my $local = shift @arg;
	my $c = shift @arg;
	my $delim = shift @arg;

	if ($delim eq '*') {
	    die "Strange text-list: $c $delim\n";
	}
	foreach (0..($c-1)) {
	    my $global = shift @arg;

	    $res{local}[$local] = $global;
	    ++$local;
	}
	shift @arg if $delim eq '{';
    } else {
	my $c = shift @arg;
	my $delim = shift @arg;

	if ($delim eq '*') {
	    die "Strange text-number-pair array count: $c $delim\n";
	}
	foreach (0..($c-1)) {
	    my $k = shift @arg;

	    my $v = shift @arg;
	    $res{local}[$k] = $v;
	}
	shift @arg if $delim eq '{';
    }
    return \%res;
}

## Methods

=item is_error($code, $err_no, $err_status)

Look at a response from the server and decides if it is a
error message and if thats the case sets some variables in the object
and returns true.

Calls C<die()> if the response dont look as a server response at all.

This sub is intended for internal use.

=cut

sub is_error {
    my $self = shift;
    my ($code, $err_no, $err_status) = @_;

    if ($code =~ /^=/) {
	$self->{err_no} = 0;
	$self->{err_status} = 0;
	$self->{err_string} = "";
	return 0;		# Not an error
    } elsif ($code =~ /^%% /) {
	$self->{err_no} = 4711;
	$self->{err_status} = $err_status;
	$self->{err_string} = "Protocol error!";
	return 1;		# Is an error
    } elsif ($code =~ /^%/) {
	$self->{err_no} = $err_no;
	$self->{err_status} = $err_status;
	$self->{err_string} = $error[$err_no];
	return 1;		# Is an error
    } else {
	die "An unknown error? ($code)\n";
    }
}

=item new([options])

Creates a new Net::Lyskom object and connect to a LysKOM server. By default
it connects to Lysator's server (I<kom.lysator.liu.se>, port 4894). To connect
to another server, use named arguments.

    $a = Net::Lyskom->new(Host => "kom.csd.uu.se", Port => 4894);

If the connections succeded, a object is returned, if not C<undef> is
returned.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %arg = @_;

    my $host = $arg{Host} || "kom.lysator.liu.se";
    my $port = $arg{Port} || 4894;

    my $name =
      $arg{Name} ||
	$ENV{USER} ||
	  $ENV{LOGNAME} ||
	    ((getpwuid($<))[0]);

    $self->{refno} = 1;

    $self->{socket} = IO::Socket::INET->new(
					    PeerAddr => $host,
					    PeerPort => $port,
					   )
      or die "Can't connect to remote server: $!\n";

    $self->{socket}->print("A".holl($name)."\n");

    my $tmp = $self->{socket}->getline;
    while (!$tmp || $tmp !~ /LysKOM/) {
	$tmp = $self->{socket}->getline;
	debug "From server: $tmp";
    }

    bless $self, $class;
    return $self;
}

=item getres()

Get responses and asynchronous messages from the server. The asynchronous
messages is passed to C<handle_async()>. This method is intended for
internal use, and shall normally not be used anywhere else then in
this module.

=cut

sub getres {
    my $self = shift;
    my @res;

    @res = $self->getres_sub;
    while ($res[0] =~ m/^:/) {
	$self->handle_asynch(@res);
	@res = $self->getres_sub;
    }
    return @res;
}

=item getres_sub()

Helper function to C<getres()>. Be careful and I<understand> what you are
up to before using it.

=cut

sub getres_sub {
    my $self = shift;
    my ($f, $r);
    my @res;

    $r = $self->{socket}->getline;
    debug($r);
    while ($r) {
	if ($r =~ m|^(\d+)H(.*)$|) { # Start of a hollerith string
	    my $tot_len = $1;
	    my $res;
	    $r = $2."\n";
	
	    $res = substr $r, 0, $tot_len,"";
	    while (length($res) < $tot_len) {
		$r = $self->{socket}->getline;
		debug($r);
		$res .= substr $r, 0, ($tot_len-length($res)),"";
	    }
	    push @res, $res;
	    if ($r eq "") {
		$r = $self->{socket}->getline;
	    }
	} else {
	    ($f, $r) = split " ", $r, 2;
	    push @res,$f;
	}
    }
    return @res;
}

=item handle_asynch()

Is automaticly called when a asynchronous message is returned from
the server. Currently this routine does nothing.

=cut

sub handle_asynch {
    my $self = shift;
    my @call = @_;

    #debug "Asynch: @call";
}

=item logout

Log out from LysKOM, this call doesn't disconnect the session, which means you can login again
without the need of calling another new().

=cut

sub logout {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->{socket}->print($this . ' 1 ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item change_conference ($conference)

Changes current conference of the session.

    $a->change_conference(4711);

=cut

sub change_conference {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conference = shift;
    my @res;

    $self->{socket}->print($this . ' 2 ' . $conference . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item change_name ($conference, $new_name)

Change name of the person or conference numbered $conference to $new_name.

=cut

sub change_name {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conference = shift;
    my $new_name = shift;
    my @res;

    $self->{socket}->print($this . ' 3 ' . $conference . ' ' . holl($new_name) . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item change_what_i_am_doing ($what_am_i_doing)

Tells the server what the logged-in user is doing. You are encouraged to use
this call creatively.

    $a->change_what_i_am_doing('Eating smorgasbord');

=cut

sub change_what_i_am_doing {
    my $self = shift;
    my $this = $self->{refno}++;
    my $what_am_i_doing = shift;
    my @res;

    $self->{socket}->print($this . ' 4 ' . holl($what_am_i_doing) . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

# Call 7 - set-priv-bits - is to be inserted here

=item set_passwd($person, $old_pwd, $new_pwd) 

Changes the password of $person to $new_pwd.

$old_pwd is the password of the currently logged in person.

=cut

sub set_passwd {
    my $self = shift;
    my $this = $self->{refno}++;
    my $person = shift;
    my $old_pwd = shift;
    my $new_pwd = shift;
    my @res;

    $self->{socket}->print($this . ' 8 ' . $person . ' ' . holl($old_pwd) . ' ' . holl($new_pwd) . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item delete_conf($conf)

Deletes the conference with number $conf. If $conf is a mailbox,
the corresponding user is also deleted.

    $a->delete_conf(42);

=cut

sub delete_conf {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf = shift;
    my @res;

    $self->{socket}->print($this . ' 11 ' . $conf . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item sub_member($conf_no, $pers_no)

Removes the person $pers_no from the membership list of
conference $conf_no.

    $a->sub_member(42,4711);

=cut

sub sub_member {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf_no = shift;
    my $pers_no = shift;
    my @res;

    $self->{socket}->print($this . ' 15 ' . $conf_no . ' ' . $pers_no . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item set_presentation($conf_no, $text_no)

Set the text $text_no as presentation for $conf_no.
To remove a presentation, use $text_no = 0

    $a->set_presentation(42,4711);

=cut

sub set_presentation {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf_no = shift;
    my $text_no = shift;
    my @res;

    $self->{socket}->print($this . ' 16 ' . $conf_no . ' ' . $text_no . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item set_supervisor($conf_no, $admin)

Set person/conference $admin as supervisor for the
conference $conf_no

=cut

sub set_supervisor {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf_no = shift;
    my $admin = shift;
    my @res;

    $self->{socket}->print($this . ' 18 ' . $conf_no . ' ' . $admin . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item set_permitted_submitters($conf_no, $perm_sub)

Set $perm_sub as permitted subscribers for $conf_no. If $perl_sum = 0, all users are
welcome to write in the conference.

=cut

sub set_permitted_submitters {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf_no = shift;
    my $perm_sub = shift;
    my @res;

    $self->{socket}->print($this . ' 19 ' . $conf_no . ' ' . $perm_sub . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item set_super_conf($conf_no, $super_conf)

Sets the conference $super_conf as super conference for $conf_no

=cut

sub set_super_conf {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf_no = shift;
    my $super_conf = shift;
    my @res;

    $self->{socket}->print($this . ' 20 ' . $conf_no . ' ' . $super_conf . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item set_garb_nice($conf_no, $nice)

Sets the garb time for the conference $conf_no to $nice days.

    $a->set_garb_nice(42,7);

=cut

sub set_garb_nice {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf_no = shift;
    my $nice = shift;
    my @res;

    $self->{socket}->print($this . ' 22 ' . $conf_no . ' ' . $nice, ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item get_text($text, $start_char, $end_char)

Get a text from the server, the first argument, $text, is the global text number
for the text to get. The retrival stars at position $start_char (the first character
in the text is numbererd 0) and ends at position $end_char.

Default is 0 for $start_char and 2147483647 for $end_char. This means that a complete
message is fetched, unless otherwise stated.

To get the first 100 chars from text 4711:

    my $text = $a->get_text(4711, 0, 100);

=cut

sub get_text {
    my $self = shift;
    my ($text, $start_char, $end_char) = @_;
    my $this = $self->{refno}++;
    my @res;

    $text = 4711 unless $text;
    $start_char = 0 unless $start_char;
    $end_char = 2147483647 unless $end_char;

    $self->{socket}->print("$this 25 $text $start_char $end_char\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return $res[1]
    }
}

=item delete_text($text)

Deletes the text with the global text number $text from the database.

=cut

sub delete_text {
    my $self = shift;
    my $this = $self->{refno}++;
    my $text = shift;
    my @res;

    $self->{socket}->print($this . ' 29 ' . $text . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item get_time

Ask the server for the current time.

=cut

sub get_time {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->{socket}->print($this . ' 35 ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;    # Remove return code
	(my $time, undef) = parse_time(@res);
	return $time;
    }
}

=item set_unread($conf_no, $no_of_unread)

Only read the $no_of_unread texts in the conference $conf_no.

=cut

sub set_unread {
    my $self = shift;
    my $this = $self->{refno}++;
    my $conf_no = shift;
    my $no_of_unread = shift;
    my @res;

    $self->{socket}->print($this . ' 40 ' . $conf_no . ' ' . $no_of_unread, ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item set_motd_of_lyskom($text_no)

Sets the login message of LysKOM, can only be executed by a privileged person,
with the proper privileges enabled.

=cut

sub set_motd_of_lyskom {
    my $self = shift;
    my $this = $self->{refno}++;
    my $text_no = shift;
    my @res;

    $self->{socket}->print($this . ' 41 ' . $text_no . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item enable($level)

Sets the security level for the current session to $level.

=cut

sub enable {
    my $self = shift;
    my $this = $self->{refno}++;
    my $level = shift;
    my @res;

    $self->{socket}->print($this . ' 42 ' . $level . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item sync_kom

This call instructs the LysKOM server to make sure the permanent copy of its
databas is current. This call is privileged in most implementations.

    $a->sync_kom();

=cut

sub sync_kom {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->{socket}->print($this . ' 43 ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item shutdown_kom($exit_val)

Instructs the server to save all data and shut down. The variable $exit_val is
currently not used.

=cut

sub shutdown_kom {
    my $self = shift;
    my $this = $self->{refno}++;
    my $exit_val = shift;
    my @res;

    $self->{socket}->print($this . ' 44 ' . $exit_val . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item get_person_stat($persno)

Get status for a person from the server.

=cut

sub get_person_stat {
    my $self = shift;
    my $this = $self->{refno}++;
    my $persno = shift;
    my @res;

    $self->{socket}->print("$this 49 $persno\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	shift @res;		# Remove return code
	return parse_person_stat(@res);
    }
}

=item get_unread_confs($pers_no)

Get a list of conference numbers in which the person $pers_no
may have unread texts.

    my @unread_confs = $a->get_unread_confs(7);

=cut

sub get_unread_confs {
    my $self = shift;
    my $this = $self->{refno}++;
    my $pers_no = shift;
    my @res;

    $self->{socket}->print($this . ' 52 ' . $pers_no . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;    # Remove return code
	(@res, undef) = parse_array(@res);
	return @res;
    }

}

=item send_message($recipient, $message)

Sends the message $message to all members of $recipient that is
currently logged in. If $recipient is 0, the message is sent to all
sessions that are logged in.

=cut

sub send_message {
    my $self = shift;
    my $this = $self->{refno}++;
    my $recipient = shift;
    my $message = shift;
    my $tmp;
    my @res;

    $tmp = "$this 53 $recipient ".holl($message)." ";

    $self->{socket}->print($tmp);
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	return $res[0];
    }
}

=item who_am_i

Get the session number of the current session.

    my $session_number = $a->who_am_i();

=cut

sub who_am_i {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->{socket}->print($this . ' 56 ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;    # Remove return code
	return $res[0];
    }

}

=item get_last_text

=cut

sub get_last_text {
    my $self = shift;
    my $this = $self->{refno}++;
    my $time = shift;
    my @res;
    my $tmp;
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime($time);
    $tmp = sprintf("%d 58 %d %d %d %d %d %d %d %d %d\n",
		   $this,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,
		   ($isdst?1:0));
    $self->{socket}->print($tmp);
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	shift @res;		# Remove return code
	return $res[0];
    }
}

=item find_text_no

=cut

sub find_next_text_no {
    my $self = shift;
    my $this = $self->{refno}++;
    my $start = shift;
    my @res;

    $self->{socket}->print("$this 60 $start\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	shift @res;		# Remove return code
	return $res[0];
    }
}

=item find_previous_text_no

=cut

sub find_previous_text_no {
    my $self = shift;
    my $this = $self->{refno}++;
    my $start = shift;
    my @res;

    $self->{socket}->print("$this 61 $start\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	shift @res;		# Remove return code
	return $res[0];
    }
}

=item login($persno, $pwd, $invis)

Log in to LysKOM. $persno is the number of the person which is to be
logged in. $pwd is the password of that person. If $invis is true, a
secret login is done (the session is not visible in who-is-on-lists et al.)

=cut

sub login {
    my $self = shift;
    my ($persno, $pwd, $invis) = @_;
    my $this = $self->{refno}++;
    my $tmp;
    my @res;

    $tmp = join (" ", $this, 62, $persno, holl($pwd), ($invis)?1:0 );
    $self->{socket}->print("$tmp\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item set_client_version($client_name, $client_version)

Tells the server that this is the software $client_name and the
version $client_version.

    $a->set_client_version('My-cool-software','0.001 beta');

=cut

sub set_client_version {
    my $self = shift;
    my $this = $self->{refno}++;
    my $client_name = shift;
    my $client_version = shift;
    my @res;

    $self->{socket}->print($this . ' 69 ' . holl($client_name) . ' ' . holl($client_version) . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	return $res[0];
    }

}

=item get_client_name($session)

Ask the server for the name of the client software logged in with
session number $session.

=cut

sub get_client_name {
    my $self = shift;
    my $this = $self->{refno}++;
    my $session = shift;
    my @res;

    $self->{socket}->print($this . ' 70 ' . $session . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;    # Remove return code
	return $res[0];
    }

}

=item get_client_version($session)

Ask the server for the version of the client software logged in with
session number $session.

=cut

sub get_client_version {
    my $self = shift;
    my $this = $self->{refno}++;
    my $session = shift;
    my @res;

    $self->{socket}->print($this . ' 71 ' . $session . ' ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;    # Remove return code
	return $res[0];
    }

}

=item get_version_info

Ask the server for the version info of the server software itself.

=cut

sub get_version_info {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->{socket}->print($this . ' 75 ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;    # Remove return code
	return parse_version_info(@res);
    }
}

=item lookup_z_name($name, $want_pers, $want_conf)

Lookup the name $name in the server, returns a list of all matching conferences
and/or persons. The server database is searched with standard kom name expansion.

If $want_pers is true, the server includes persons in the answer, if $want_conf
is true, conferences is included.

=cut 

sub lookup_z_name {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;
    my ($name, $want_pers, $want_conf) = @_;
    my $tmp;

    $tmp = sprintf "%d 76 %s %d %d\n",$this,holl($name),($want_pers?1:0),($want_conf?1:0);
    $self->{socket}->print($tmp);
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	shift @res;		# Remove return code
	return parse_conf_z_info_array(@res);
    }
}

=item user_active

Tells the server that the user is active.

=cut

sub user_active {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->{socket}->print($this . ' 82 ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return 1;
    }
}

=item create_text

Create a text.

=cut

sub create_text {
    my $self = shift;
    my $this = $self->{refno}++;
    my $text = shift;
    my @misc = @{$_[0]} if $_[0];
    my @aux = @{$_[1]} if $_[1];
    my (@tmp,$tmp);
    my @res;

    $tmp = "$this 86 ".holl($text)." ";

    while (@misc) {
	my ($v,$k) = splice(@misc,0,2);
	if ($v eq "to") {
	    push @tmp, "0 $k";
	} elsif ($v eq "cc") {
	    push @tmp, "1 $k";
	} elsif ($v eq "bcc") {
	    push @tmp, "15 $k";
	} elsif ($v eq "comment_to") {
	    push @tmp, "2 $k";
	} elsif ($v eq "footnote_to") {
	    push @tmp, "4 $k";
	}
    }
    if (@tmp>0) {
	$tmp .= @tmp;
	$tmp .= " { @tmp } ";
    } else {
	$tmp .= " 0 { } ";
    }
    @tmp = ();

    while (@aux) {
	my ($tag,$flags,$limit,$data) = splice(@aux,0,4);
	push @tmp, "$tag $flags $limit ".holl($data);
	
    }
    if (@tmp>0) {
	$tmp .= @tmp;
	$tmp .= " { @tmp } ";
    } else {
	$tmp .= "0 { } ";
    }

    $tmp .= "\n";

    $self->{socket}->print($tmp);
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;		# Remove return code
	return $res[0];
    }
}

=item get_text_stat($textno)

Hämta status för en text från servern.

=cut

sub get_text_stat {
    my $self = shift;
    my $this = $self->{refno}++;
    my $textno = shift;
    my @res;

    $self->{socket}->print("$this 90 $textno\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	shift @res;		# Remove return code
	return (parse_text_stat(@res))[0];
    }
}

=item get_conf_stat($conf_no)

Get status for a conference from the server.

=cut

sub get_conf_stat {
    my $self = shift;
    my $this = $self->{refno}++;
    my $confno = shift;
    my @res;

    $self->{socket}->print("$this 91 $confno\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	shift @res;		# Remove return code
	return (parse_conf_stat(@res))[0];
    }
}

=item query_predefined_aux_items 

Ask the server which predefined aux items that exists in the server.

=cut

sub query_predefined_aux_items {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;

    $self->{socket}->print($self . ' 96 ');
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;
	(@res, undef) = parse_array(@res);
	return @res;
    }
}

=item get_membership($person, $first, $no_of_confs, $want_read_texts)

Get a membership list for the person $person. Start at position $first in
the membership list and get $no_of_confs conferences. If $want_read_texts is
true the server will also send information about read texts in the
conference.

=cut

sub get_membership {
    my $self = shift;
    my $this = $self->{refno}++;
    my $person = shift;
    my $first = shift;
    my $no_of_confs = shift;
    my $want_read_texts = shift;
    my $tmp;
    my @res;

    $tmp = join (" ", $this, 99, $person, $first, $no_of_confs, ($want_read_texts)?1:0 );
    debug($tmp);

    $self->{socket}->print("$tmp\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;    # Remove return code
	return parse_membership_array(@res);
    }
}

=item local_to_global($conf, $first, $no)

=cut

sub local_to_global {
    my $self = shift;
    my $this = $self->{refno}++;
    my ($conf, $first, $no) = @_;
    my @res;

    $self->{socket}->print("$this 103 $conf $first $no\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	shift @res;		# Remove return code
	return parse_text_mapping(@res);
    }
}

=back

=cut

# Return something true
1;

__END__

=head1 AUTHORS

=item Calle Dybedahl <calle@lysator.liu.se>
=item Erik S-O Johansson <fl@erp.nu>

=head1 SEE ALSO

perl(1).

