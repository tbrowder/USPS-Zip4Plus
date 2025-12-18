unit module USPS::ZipPlus4;

use HTTP::UserAgent;
use DBIish;
use DB::SQLite;

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

class Cache::SQLite
{
    has Str $.path;
    has $.dbh;

    method new(:$path!, *%opts)
    {
        my $dbh = DBIish.connect('SQLite', :database($path));
        my $self = self.bless(:$path, :$dbh, |%opts);
        $self!init;
        $self;
    }

    method !init returns Nil
    {
        $!dbh.do(q:to/SQL/);
CREATE TABLE IF NOT EXISTS zip4_cache (
    cache_key   TEXT PRIMARY KEY,
    street1     TEXT NOT NULL,
    street2     TEXT,
    city        TEXT NOT NULL,
    state       TEXT NOT NULL,
    zip5        TEXT NOT NULL,
    zip4        TEXT NOT NULL,
    updated_utc TEXT
);
SQL
    }

    method fetch(Str $key) returns Result
    {
        my $sth = $!dbh.prepare(q:to/SQL/);
SELECT street1, street2, city, state, zip5, zip4
FROM zip4_cache
WHERE cache_key = ?
SQL
        $sth.execute($key);
        my @row = $sth.row;

        unless @row.elems
        {
            return Nil;
        }

        Result.new(
            street1 => @row[0].Str,
            street2 => @row[1].Str,
            city    => @row[2].Str,
            state   => @row[3].Str,
            zip5    => @row[4].Str,
            zip4    => @row[5].Str,
        );
    }

    method store(Str $key, Result $r) returns Nil
    {
        my $sth = $!dbh.prepare(q:to/SQL/);
INSERT INTO zip4_cache (
    cache_key, street1, street2, city, state, zip5, zip4, updated_utc
) VALUES (
    ?, ?, ?, ?, ?, ?, ?, datetime('now')
)
ON CONFLICT(cache_key) DO UPDATE SET
    street1     = excluded.street1,
    street2     = excluded.street2,
    city        = excluded.city,
    state       = excluded.state,
    zip5        = excluded.zip5,
    zip4        = excluded.zip4,
    updated_utc = excluded.updated_utc
SQL

        $sth.execute(
            $key,
            $r.street1,
            $r.street2,
            $r.city,
            $r.state,
            $r.zip5,
            $r.zip4,
        );
    }

    method close returns Nil
    {
        $!dbh.dispose if $!dbh.defined;
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
sub norm-part(Str $s) returns Str
{
    my $t = $s.trim.uc;
    $t ~~ s:g/\s+/ /;
    $t;
}

sub cache-key(
    Str :$street!,
    Str :$street2 = '',
    Str :$city!,
    Str :$state!
) returns Str
{
    # Stable key for identical addresses typed slightly differently
    norm-part($street) ~ "\t"
        ~ norm-part($street2) ~ "\t"
        ~ norm-part($city) ~ "\t"
        ~ norm-part($state);
}
