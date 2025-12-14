unit module USPS::ZipPlus4;

use HTTP::UserAgent;
use XML::Fast;

class X::USPS::ZipPlus4 is Exception
{
    has Str $.message;
    method gist { $.message }
}

class Result
{
    has Str $.street1;
    has Str $.street2;
    has Str $.city;
    has Str $.state;
    has Str $.zip5;
    has Str $.zip4;
}

class Client
{
    has Str $.userid;
    has Num $.throttle-seconds = 0.2;
    has Str $.endpoint = 'https://secure.shippingapis.com/ShippingAPI.dll';

    method new(:$userid?, *%opts)
    {
        my $id = $userid // %*ENV<USPS_WEBTOOLS_USERID>;
        unless $id.defined and $id.chars
        {
            die X::USPS::ZipPlus4.new(
                message => 'USPS Web Tools USERID not provided'
            );
        }

        self.bless(:userid($id), |%opts);
    }

    method zip4-lookup(
        :$street!,
        :$city!,
        :$state!,
        :$street2 = ''
    ) returns Result
    {
        sleep $.throttle-seconds if $.throttle-seconds > 0;

        my $xml = qq:to/XML/;
<ZipCodeLookupRequest USERID="{$!userid}">
  <Address ID="0">
    <Address1>{$street2}</Address1>
    <Address2>{$street}</Address2>
    <City>{$city}</City>
    <State>{$state}</State>
  </Address>
</ZipCodeLookupRequest>
XML

        my $ua = HTTP::UserAgent.new;
        my $resp = $ua.get(
            $.endpoint,
            query => {
                API => 'ZipCodeLookup',
                XML => $xml,
            }
        );

        unless $resp.is-success
        {
            die X::USPS::ZipPlus4.new(
                message => "HTTP error {$resp.code}"
            );
        }

        self!parse-response($resp.content);
    }

    method !parse-response(Str $xml) returns Result
    {
        my $doc = xml-parse($xml);

        if $doc<Error>:exists
        {
            my $num  = $doc<Error><Number>.Str;
            my $desc = $doc<Error><Description>.Str;
            die X::USPS::ZipPlus4.new(
                message => "USPS error {$num}: {$desc}"
            );
        }

        my $addr = $doc<ZipCodeLookupResponse><Address>
            // die X::USPS::ZipPlus4.new(
                message => 'Malformed USPS response'
            );

        my $zip5 = $addr<Zip5>.Str;
        my $zip4 = $addr<Zip4>.Str;

        unless $zip5.chars and $zip4.chars
        {
            die X::USPS::ZipPlus4.new(
                message => 'ZIP+4 not returned (address incomplete or invalid)'
            );
        }

        Result.new(
            street1 => $addr<Address2>.Str,
            street2 => $addr<Address1>.Str,
            city    => $addr<City>.Str,
            state   => $addr<State>.Str,
            zip5    => $zip5,
            zip4    => $zip4,
        );
    }
}
