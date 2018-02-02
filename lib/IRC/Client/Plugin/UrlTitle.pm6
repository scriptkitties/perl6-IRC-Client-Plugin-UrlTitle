#! /usr/bin/env false

use v6.c;

use HTML::Parser::XML;
use HTTP::UserAgent;
use IRC::Client;
use URL::Find;

#| An IRC::Client plugin to post the title of webpages which are referenced in
#| IRC channel messages
class IRC::Client::Plugin::UrlTitle does IRC::Client::Plugin
{
	#| Check every message for possible URLs. The original event will be passed
	#| along for other plugins to handle as well.
	method irc-privmsg-channel(
		$e, #= The IRC event which triggered this method.
	) {
		# Configure HTTP::UserAgent
		my HTTP::UserAgent $ua .= new;
		$ua.timeout = 10;

		# Get all URLs in the message
		my @urls = find-urls($e.text);

		for @urls -> $url {
			try {
				CATCH {
					$e.irc.send(
						where => $e.channel,
						text => "$url: {~$_}",
					);
				}

				my $response = $ua.get($url);

				if ($response.is-success) {
					my HTML::Parser::XML $parser .= new;
					$parser.parse($response.content);

					my $head =  $parser.xmldoc.root.elements(:TAG<head>, :SINGLE);
					return $.NEXT if $head ~~ Bool;

					my $title-tag = $head.elements(:TAG<title>, :SINGLE);
					return $.NEXT if $title-tag ~~ Bool;

					my $title = $title-tag.contents[0].text;

					$e.irc.send(
						where => $e.channel,
						text => "$url: $title",
					);

					return $.NEXT;
				}

				$e.irc.send(
					where => $e.channel,
					text => "$url: " ~ $response.status-line,
				);
			}
		}

		$.NEXT;
	}
}

# vim: ft=perl6 noet
