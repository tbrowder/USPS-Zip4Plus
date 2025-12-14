unit module USPS::ZipPlus4;

use HTTP::UserAgent;

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
    has Num $.throttle-seconds = 0.2e0.Num;
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

        self.parse-response($resp.content);
    }

    method parse-response(Str $xml) returns Result
    {
        if has-tag($xml, 'Error')
        {
            my $num  = tag-text($xml, 'Number');
            my $desc = tag-text($xml, 'Description');
            die X::USPS::ZipPlus4.new(message => "USPS error {$num}: {$desc}");
        }

        my $zip5 = tag-text($xml, 'Zip5');
        my $zip4 = tag-text($xml, 'Zip4');

        unless $zip5.chars and $zip4.chars
        {
            die X::USPS::ZipPlus4.new(
                message => 'ZIP+4 not returned (address incomplete or invalid)'
            );
        }

        my Str $street1 = tag-text($xml, 'Address2');  # street
        my Str $street2 = tag-text($xml, 'Address1');  # unit
        my Str $city    = tag-text($xml, 'City');
        my Str $state   = tag-text($xml, 'State');

        Result.new(
            street1 => $street1,
            street2 => $street2,
            city    => $city,
            state   => $state,
            zip5    => $zip5,
            zip4    => $zip4,
        );
    }
}

sub tag-text(Str $xml, Str $tag) returns Str
{
    my $m = $xml.match(/ '<' $tag '>' ( .*? ) '</' $tag '>' /, :s);
    return $m ?? $m[0].Str.trim !! '';
}

sub has-tag(Str $xml, Str $tag) returns Bool
{
    $xml.contains("<{$tag}>") or $xml.contains("<{$tag} ");
}
