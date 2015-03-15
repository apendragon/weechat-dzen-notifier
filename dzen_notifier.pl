#!/usr/bin/perl
use strict;
use IO::Handle;
use constant {
  _SCRIPT_NAME => 'dzen_notifier',
  _VERSION     => '1.0',
  _AUTHOR      => 'apendragon',
  _LICENSE     => 'artistic_2',
  _DESC        => 'weechat dzen notifier script',
  _SHUTDOWN_F  => 'shutdown',
  _CHARSET     => 'UTF-8',
  _DEBUG       => 1,
};

weechat::register(_SCRIPT_NAME(), _AUTHOR(), _VERSION(), _LICENSE(), _DESC(), _SHUTDOWN_F(), _CHARSET());

my $dzen_bar = "dzen2 -ta l -h 18 -fn 'snap' -bg '#111111' -fg '#b3b3b3' -w 200 -x 1000";
open my ($io_fh), "|$dzen_bar";
$io_fh->autoflush(1);
my %msg_stack= ();

weechat::hook_print('', '', '', 1, 'print_author_and_count_priv_msg', '');

sub get_msg_sender {
  my ($tags) = @_;
  weechat::log_print("get_msg_sender") if _DEBUG();
  my $nick = '';
  $nick = $1 if (defined($tags) && $tags =~ m/(?:^|,)nick_([^,]*)(?:,|$)/);
  $nick;
}

sub is_my_message {
  my ($tags, $buffer) = @_;
  weechat::log_print("is_my_message") if _DEBUG();
  my $my_nick = weechat::buffer_get_string($buffer, 'localvar_nick');
  my $nick = get_msg_sender();
  $nick eq $my_nick;
}

sub is_private_message {
  my ($buffer, $tags) = @_;
  weechat::log_print("is_private_message") if _DEBUG();
  return 0 if (!defined($tags) || !defined($buffer));
  weechat::buffer_get_string($buffer, 'localvar_type') eq 'private' && $tags =~ m/(?:^|,)notify_private(?:,|$)/;
}

sub notify {
  my ($buffer, $tags) = @_;
  weechat::log_print("notify") if _DEBUG();
  my $sender = get_msg_sender($tags);
  $msg_stack{$sender}++;
  my $count = scalar keys %msg_stack;
  print $io_fh "[$count] $sender ($msg_stack{$sender})\n";
  weechat::WEECHAT_RC_OK;
  #TODO think about stack order
}

sub notify_on_private {
  my ($buffer, $tags) = @_;
  weechat::log_print("notify_on_private") if _DEBUG();
  is_private_message($buffer, $tags) ? notify($buffer, $tags) : weechat::WEECHAT_RC_OK;
}

sub print_author_and_count_priv_msg {
  my ($data, $buffer, $date, $tags, $displayed, $highlight, $prefix, $message) = @_;
  weechat::log_print("print_author_and_count_priv_msg") if _DEBUG();
  weechat::log_print("tags:$tags");
  weechat::log_print("buffer:$buffer");
  return weechat::WEECHAT_RC_OK if (!defined($tags) || !defined($buffer));
  my $dispatch = {
    0 => sub { weechat::WEECHAT_RC_OK }, # return if message is filtered
    1 => sub {
      is_my_message($tags, $buffer) ? weechat::WEECHAT_RC_OK : notify_on_private($buffer, $tags);
    },
  };
  $dispatch->{$displayed}->();
}

sub shutdown {
  weechat::log_print("shutdown") if _DEBUG();
  close $io_fh;
}
