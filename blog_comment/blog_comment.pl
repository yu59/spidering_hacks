#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use LWP::Simple;
use utf8;
binmode(STDOUT, ':raw :encoding(utf8)');  # 同上
use Encode;
use Encode::Guess;

my %opts; GetOptions(\%opts, 'v|verbose');

# あらかじめファイルにURLを格納しておく。
# このファイルにはコメント数も格納しておく。
my $urls_file = "chkcomments.dat";

# 以下は、サイト毎に使用する正規表現と代入コードの一覧である。
my @signatures = (
   { regex  => qr/On (.*?), <a href="(.*?)">(.*?)<\/a> said/,
     assign => '($date,$contact,$name) = ($1,$2,$3)'
   },
   { regex  => qr/&middot; (.*?) &middot; .*?<a href="(.*?)">(.*?)<\/a>/,
     assign => '($date,$contact,$name) = ($1,$2,$3)'
   },
   { regex  => qr/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})&nbsp;(.*)/,
     assign => '($date,$name,$contact) = ($1,$2,"無し")'
   },
   { regex  => qr/Posted by <a href="(.*?)">(.*?)<\/a> at (.*?)<\/span>/,
     assign => '($name,$date,$contact) = ($2,$3,$1)'
   },  # ↑MovableType 2.661デフォルト設定例
   { regex  => qr/<p class="posted">投稿者: (.*?)\((.*?)\)/,
     assign => '($name,$date,$contact) = ($1,$2,"無し")'
   },  # ↑ココログ の一例
   { regex  => qr/<div>\[(.*?)\]\r\n\s+\[(\d{4}\/\d{2}\/\d{2} \d{2}:\d{2})\]/,
     assign => '($name,$date,$contact) = ($1,$2,"無し")'
   },  # ↑Doblog の一例
   { regex  => qr/<span class="commentator">(.*?)<\/span>.*?\n.*?\((.*?)\)/,
     assign => '($name,$date,$contact) = ($1,$2,"無し")'
   },  # ↑はてなダイアリーの一例
   { regex  => qr/<span class="cmName">(.*?)<\/span>.*?\n.*?<span class="cmDate">(.*?)<\/span>/,
     assign => '($name,$date,$contact) = ($1,$2,"無し")'
   },  # ↑goo BLOGの一例
);

# データファイルをオープンし、読み込む。
# （URLとコメント数を'|%%|'で区切った形式で格納している。）
open(URLS_FILE, '<:encoding(utf8)', $urls_file) or die $!;
my %urls; while (<URLS_FILE>) { chomp;
   my ($url, $count) = split(/\|%%\|/);
   $urls{$url} = $count || undef;
} close (URLS_FILE);

# データファイルに格納された全URLに対して、以下の処理を行う。
foreach my $url (keys %urls) {

   next unless $url; # URLが記述されていない場合は、スキップ。
   my $old_count = $urls{$url} || undef;

   # ちょっとしたメッセージの出力。
   print "\n$url を調査中です。\n";

   # データの取得。
   my $data = get($url) or next;
   my $enc  = guess_encoding($data,  qw/euc-jp shiftjis 7bit-jis utf8/);
   $data = $enc->name, $data;  # 漢字コードの変換。 decode()

   # 定義されている正規表現と代入コードを順に適用し、
   # 取得したデータがどのパターンに該当するのかを調べる。
   my $new_count; foreach my $code (@signatures) {

      # 正規表現がマッチするかどうかを調べる。
      while ($data =~ /$code->{regex}/migs) {

         # $codeは、2つのPerlステートメント（上記の正規表現と
         # 代入コード）に分かれているため、代入処理を行わせる
         # ためには代入コードを評価（eval）する必要がある。
         my ($date, $contact, $name); eval $code->{assign};
         next unless ($date && $contact && $name);
         print "  - $date: $name ($contact)\n" if $opts{v};
         $new_count++; # コメント数をカウントアップする。
      }

      # コメント数を取得できたのであれば、正規表現が正しかったと
      # 仮定し、メッセージを表示してコメント数を保存する。
      if ($new_count) {
         print "　＊ $new_count 個のコメントを検出しました。".
               "　（以前： ". ($old_count || "−") . " 個）\n";
         if ($new_count > ($old_count || 0)) { # 新規コメントあり！
             print "　＊ 新規コメントがあります！！！\n"
         } $urls{$url} = $new_count; last; # ループの終了
      }
   }
} print "\n";

# コメント数をデータファイルに保存する。
open(URLS_FILE, '>:encoding(utf8)', $urls_file) or die $!;
foreach my $url (keys %urls) {
   print URLS_FILE "$url|%%|$urls{$url}\n";
} close (URLS_FILE);
