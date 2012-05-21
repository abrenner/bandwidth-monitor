#!/usr/bin/php-cli
<?php
# bandwidth - Get Graphs
# ----------------------------------------------------------------------------
# This php script will connect to all the servers in the queue and get the 
# rrd graphs and display them to the web.
#
# For connection to each server, script will be using scp with authentication
# keys that already exist on the server. Script is going to assume that this
# is already setup. See: http://linuxproblem.org/art_9.html
#
# Side note, I normally do not write PHP as a 'scripting language' that
# something like bash, perl or python is better suited and widely known for
# but I am trying something new!
#
# @todo: Possible feature would be to convert this script to perl and use
#        something like Net::SSH2 or Net::OpenSSH to make it easier to connect
#        to servers without having to generate authentication keys. Downside:
#        passwords are stored in plain text.
#
# @author	Adam Brenner <aebrenne@uci.edu>
# @version	1.0

# Directory of where the images be stored
$imgDir = "/home/bandwidt/www/";
# Static file to update timestamp
$staticFile = "/home/bandwidt/www/index.html";
$srvArr = array();

# Create an array of all servers paths (add/delete as needed)
$srvArr["dns"]["hostname"] = "dns.netops.me";
$srvArr["dns"]["pathToImgs"] = "/root/graphs/images";


foreach ($srvArr as $key => $i)
{
	checkDirs($srvArr[$key]["hostname"]);
	getGraphs($srvArr[$key]["hostname"], $srvArr[$key]["pathToImgs"], $key);
}
updateTime();

function checkDirs($hostname)
{
	global $imgDir;
	if(is_dir("$imgDir/$hostname") == FALSE)
	{
		printCLI("$hostname directory in $imgDir does not exist...Creating");
		$command = "mkdir -p $imgDir/$hostname";
		exec($command, $output, $errorCode);
		printCLI("mkdir error: $errorCode");
	}
}


function getGraphs($hostname, $path, $name)
{
	global $imgDir;
	printCLI("Grabbing $name graphs on $hostname in $path");
	$command = "scp root@$hostname:$path/* ".$imgDir."/".$hostname."";
	printCLI($command);
	exec($command, $output, $errorCode);
	foreach ($output as $i)
		printCLI($i);
}

function updateTime() 
{
	global $staticFile;

	$timestamp = date("F jS, Y H:i");
	$find = '/on <strong>[^"]*<\/strong>/';
	$replace = "on <strong>".$timestamp."</strong>";
    $q = file_get_contents($staticFile);
    $q = preg_replace($find, $replace, $q);
	file_put_contents($staticFile,$q);
}

function printCLI($string = null)
{
	echo "$string\r\n";
}

?>