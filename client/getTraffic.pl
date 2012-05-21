#!/usr/bin/perl
# bandwidth - Get Traffic
# ----------------------------------------------------------------------------
# This perl script gets the RX bytes and TX bytes values from ifconfig and 
# saves them using the rrd tool. rrd then generates PNG graphs which can be
# displayed on websites.
#
# Since this is part of an overall application, the server's job is to fetch
# the images and graphs. See: server/ for more information. With that in mind
# we are not worrying about how to place the images on the website but rather
# only storing it. This makes it for a much more modular design.
#
# @author	Adam Brenner <aebrenne@uci.edu>
# @version	1.0
# @notes	configure script for cPanel servers when compling from source
# yum install cairo-devel libxml2-devel pango-devel pango libpng-devel freetype freetype-devel libart_lgpl-devel
# ./configure --enable-perl-site-install --prefix=/usr --disable-tcl --disable-rrdcgi



# yum install rrd-perl rrd-devel (or cpan)
use RRDs;

# define folder to save the rrdtool databases
my $rrd = '/root/graphs';
# define location of images folder
my $img = '/root/graphs/images';

# environmental variables (change as needed)
my $ifconfig = '/sbin/ifconfig';
my $grep = '/bin/grep';
my $cut = '/bin/cut';

# process data for each interface (add/delete as required)
&ProcessInterface("eth0", "Public VLAN");
#&ProcessInterface("eth1", "Private Network");
#&ProcessInterface("lo", "Local Loopback");

sub ProcessInterface
{
# process interface
# inputs: 
#		$_[0]: interface name (ie, eth0/eth1/eth2/ppp0)
#		$_[1]: interface description 

	# get network interface info
	# see /var/spool/mail/root for issues
	my $in  = `$ifconfig $_[0] |$grep bytes |$cut -d":" -f2 | $cut -d" " -f1`;
	my $out = `$ifconfig $_[0] |$grep bytes |$cut -d":" -f3 | $cut -d" " -f1`;

	# remove eol chars
	chomp($in);
	chomp($out);

	print "$_[0] traffic in, out: $in, $out\n";

	# if rrdtool database doesn't exist, create it
	if (! -e "$rrd/$_[0].rrd") 
	{
		print "creating rrd database for $_[0] interface...\n";
		RRDs::create "$rrd/$_[0].rrd",
			"-s 300",
			"DS:in:DERIVE:600:0:12500000",
			"DS:out:DERIVE:600:0:12500000",
			"RRA:AVERAGE:0.5:1:576",
			"RRA:AVERAGE:0.5:6:672",
			"RRA:AVERAGE:0.5:24:732",
			"RRA:AVERAGE:0.5:144:1460";
	}

	# insert values into rrd
	RRDs::update "$rrd/$_[0].rrd",
		"-t", "in:out",
		"N:$in:$out";

	# create traffic graphs (add/delete as required)
	&CreateGraph($_[0], "day", $_[1]);
	&CreateGraph($_[0], "week", $_[1]);
	&CreateGraph($_[0], "month", $_[1]); 
	&CreateGraph($_[0], "year", $_[1]);
}

sub CreateGraph
{
# creates graph
# inputs: 
#		$_[0]: interface name (ie, eth0/eth1/eth2/ppp0)
#		$_[1]: interval (ie, day, week, month, year)
#		$_[2]: interface description 

	RRDs::graph "$img/$_[0]-$_[1].png",
		"-s -1$_[1]",
		"-t traffic on $_[0] :: $_[2] :: $_[1]",
		"--lazy",
		"-h", "135", "-w", "610",
		"-l 0",
		"-a", "PNG",
		"-v bytes/sec",
		"DEF:in=$rrd/$_[0].rrd:in:AVERAGE",
		"DEF:out=$rrd/$_[0].rrd:out:AVERAGE",
		"CDEF:out_neg=out,1,*",
		
		"AREA:in#32CD32:Incoming",
		"LINE1:in#336600",
		"GPRINT:in:MAX:  Max\\: %5.1lf %s",
		"GPRINT:in:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:in:LAST: Current\\: %5.1lf %Sbytes/sec\\n",
		
		"AREA:out_neg#4169E199:Outgoing",
		"LINE1:out_neg#0033CC",
		"GPRINT:out:MAX:  Max\\: %5.1lf %S",
		"GPRINT:out:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:out:LAST: Current\\: %5.1lf %Sbytes/sec",

		"HRULE:0#000000";

	if ($ERROR = RRDs::error) { 
		print "$0: unable to generate $_[0] $_[1] traffic graph: $ERROR\n"; 
	}
}