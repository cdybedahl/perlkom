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

Net::Lyskom - Perl-modul för att prata med LysKom-servrar.

=head1 SYNOPSIS

  use Net::Lyskom;

  $a = Net::Lyskom->new();
  $conf = 6;

  $a->login(437,"Gud",1)
    or die "Failed to log in: $a->{err_string}\n";

  $b = $a->create_text(
	  	       "Testärende\nTesttextkropp.",
		       [to => 437],
		      );

  $b = $a->send_message(7680, "Oook!");

  if ($b) {
      print "Text number $b created.\n";
  } else {
      print "Text creation failed: $a->{err_string}.\n";
  }

=head1 DESCRIPTION

Net::Lyskom.pm är en modul för att prata med LysKom-servrar. Än så länge
saknar den en himla massa funktionalitet, men är tillräckligt komplett
för att kunna användas till statistikbottar och liknande.

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

Tittar på en respons från servern och avgör om det är ett
felmeddelande, och sätter i så fall lämpliga variabler i objektet.
Returnerar sant om responsen är ett felsvar, falskt om det är ett
vanligt svar och anropar C<die()> om det inte ser ut som en
server-respons alls.

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
	die "Vafan error? ($code)\n";
    }
}

=item new([options])

Skapar ett nytt Net::Lyskom-objekt och kopplar upp sig mot en LysKom-server.
Per default kopplar den upp sig mot Lysators server
(I<kom.lysator.liu.se>, port 4894). För att koppla upp mot en annan
server, använd namngivna argument:

    $a = Net::Lyskom->new(Host => "kom.csd.uu.se", Port => 4894);

Returnerar ett objekt om allt går bra, C<undef> annars.

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

Hämtar in ett meddelande från servern. Asynkrona meddelanden lämnas
över till C<handle_asynch()>. Se till att du vet vad du gör innan du
anropar den här metoden, den är avsedd för internt bruk.

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

Hjälpfunktion till C<getres()>. Se till att du I<verkligen> vet du vad
du gör innan du anropar den.

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

Anropas automatiskt när vi tar emot ett asynkront meddelande från
servern. Gör för närvarande inte ett skvatt.

=cut

sub handle_asynch {
    my $self = shift;
    my @call = @_;

    debug "Asynch: @call";
}

=item logout

Kopplar ifrån användaren från servern, men bryter inte kopplet.

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

Ändrar aktivt möte på nuvarande session

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

Byter namn på personen eller mötet med nummer $conference till $new_name.

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

Talar om för servern vad den inloggade personen gör, används gärna kreativt.

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

# Anrop 7 - set-priv-bits

=item set_passwd($person, $old_pwd, $new_pwd) 

Ändrar lösenordet för personen med personnummer $person,
$old_pwd skall sättas till den inloggade personens lösenord och 
$new_pwd är det nya lösenordet.

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

Deletes the conference with number $conf. If $conf is a mailbox, the corresponding user is also deleted.

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

Plockar bort personen $pers_no som medlem från $conf_no

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

Set the text $text_no as presentation for $conf_no. To remove a presentation, use $text_no = 0

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

Set person/conference $admin as supervisor for the conference $conf_no

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
welcome to write in the conference

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

Sätter garbtiden för mötet $conf_no till $nice dagar

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

=item get_text($textno, $start, $end)

Hämta en text från servern. Första argumentet anger det globala numret
på den text som skall hämtas, det andra anger hur många tecken in i
inlägget vi vill börja hämta text och det tredje med vilket tecken vi
inte vill hämta mer. Default-värden för argumenten är (i ordning)
4711, 0 och 2147483647. De sista två ser till att hela inlägg alltid
hämtas, om inte annat anges. 

=cut

sub get_text {
    my $self = shift;
    my ($textno, $start, $end) = @_;
    my $this = $self->{refno}++;
    my @res;

    $textno = 4711 unless $textno;
    $start = 0 unless $start;
    $end = 2147483647 unless $end;

    $self->{socket}->print("$this 25 $textno $start $end\n");
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return 0;
    } else {
	return $res[1]
    }
}

=item delete_text($text)

Raderar texten med textnumret $text från databasen.

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

Fråga servern efter tiden

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

Sätter antalet olästa för mötet $conf_no till $no_of_unread.

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

Sätter $text_no som message of the day för LysKOM-servern

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

Ställ säkerhetsnivån för nuvarande session till $level

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

Sparar den permanenta serverdatabasen till disk från minnet. Kräver att administratörsbiten är satt.

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

Stänger ned lyskomservern. $exit_val används ej idag.

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

Hämta status för en person från servern.

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

Hämtar en lista på olästa konferenser för personen $pers_no.

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

=item send_message($recipient, $text)

=cut

sub send_message {
    my $self = shift;
    my $this = $self->{refno}++;
    my $recipient = shift;
    my $text = shift;
    my $tmp;
    my @res;

    $tmp = "$this 53 $recipient ".holl($text)." ";

    $self->{socket}->print($tmp);
    @res = $self->getres;
    if ($self->is_error(@res)) {
	return ();
    } else {
	return $res[0];
    }
}

=item who_am_i

Hämta sessionsnumret från servern för den aktiva sessionen.

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

Logga in. Det första argumentet är numret på den person som skall
loggas in, det andra argumentet är den personens lösenord och om det
tredje argumentet är sant görs en osynlig inloggning.

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

Tala om för servern vilket klientens namn är och vilken version klienten har.

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

Fråga servern efter klientens namn för ett visst sessionsnummer

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

Fråga servern efter klientens namn för ett visst sessionsnummer

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

Fråga servern efter versionsnummer

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

=item lookup_z_name($name, $wantpers, $wantconf)

Slå upp namn. Första argumentet är namnet (eller delen av namnet) som
söks, de andra två argumenten indikerar om man söker efter namn på
personer, möten eller bägge.

=cut 

sub lookup_z_name {
    my $self = shift;
    my $this = $self->{refno}++;
    my @res;
    my ($name, $wantpers, $wantconf) = @_;
    my $tmp;

    $tmp = sprintf "%d 76 %s %d %d\n",$this,holl($name),($wantpers?1:0),($wantconf?1:0);
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

=item get_conf_stat

Hämta status för ett möte från servern.

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

Fråga servern vilka fördefinierade aux-items som finns.

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

Be servern skicka en lista på medlemskap för personen $person.

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

