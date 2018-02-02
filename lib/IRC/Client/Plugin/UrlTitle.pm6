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
		# Get all URLs in the message
		my @urls = find-urls($e.text);

		race for @urls -> $url {
			$e.irc.send(
				where => $e.channel,
				text => "$url: " ~ self!resolve($url),
			);
		}

		$.NEXT;
	}

	#| Resolve a given $url to the title tag, if possible.
	method !resolve(
		Str $url, #= The URL to try and resolve
		--> Str
	) {
		# Configure HTTP::UserAgent
		my HTTP::UserAgent $ua .= new;
		$ua.timeout = 10;

		try {
			CATCH {
				return ~$_;
			}

			my $response = $ua.get($url);

			if ($response.is-success) {
				my HTML::Parser::XML $parser .= new;
				$parser.parse($response.content);

				my $head = $parser.xmldoc.root.elements(:TAG<head>, :SINGLE);
				return "No title tag" if $head ~~ Bool;

				my $title-tag = $head.elements(:TAG<title>, :SINGLE);
				return "No title tag" if $title-tag ~~ Bool;

				return $title-tag.contents[0].text;
			}

			return $response.status-line,
		}
	}
}

# vim: ft=perl6 noet
