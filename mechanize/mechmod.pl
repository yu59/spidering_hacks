#! /usr/bin/perl -w 
use strict;
use warnings;
use Data::Dumper;
use Encode;
use utf8;
binmode(STDERR, ':raw : encoding(utf8)');
$|++;

use File::Basename;
use WWW::Mechanize 0.48;

my $mech = WWW::Mechanize->new();

# 検索開始ページの取得
$mech->get( "http://search.cpan.org" );
$mech->success or die $mech->response->status_line;

# フォームを選択し，フィールドに入力した後submit
$mech->form_number(1);
$mech->field( query => "Lester" );
$mech->field( mode => "author" );
$mech->submit();

$mech->success or die "fail to post:",
	$mech->response->status_line;

# andy 検索
$mech->follow_link( text_regex => qr/Andy/ );
$mech->success or die "fail to post:", $mech->response->status_line;

# 全てのtarballを取得
my @links = $mech->find_all_links( url_regex => qr/\.tar\.gz$/ );
my @urls = map { $_->[0] } @links;

print "ダウンロード対象となる", scalar @urls, "個の tarball があります\n";

for my $url ( @urls ) {
	my $filename = basename( $url );
	print "filename --> ";
	$mech->get( $url, ':content_file'=>$filename );
	print -s $filename, "バイト\n";
}
