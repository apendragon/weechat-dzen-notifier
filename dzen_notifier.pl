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

my %options = (
  icon     => '^i(/home/tcazali/.dzen/icons/xbm8x8/cat.xbm)',
  dzen_cmd => "dzen2 -ta l -h 18 -fn 'snap' -bg '#111111' -fg '#b3b3b3' -w 200 -x 1000",
);

weechat::register(_SCRIPT_NAME(), _AUTHOR(), _VERSION(), _LICENSE(), _DESC(), _SHUTDOWN_F(), _CHARSET());

open my ($io_fh), "|$options{dzen_cmd}";
$io_fh->autoflush(1);
my %buffered_pv_msg = ();
my @stacked_notif = ();

weechat::hook_print('', '', '', 1, 'print_author_and_count_priv_msg', '');
weechat::hook_signal('buffer_switch', 'unnotify', '');

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
  weechat::buffer_get_string($buffer, 'localvar_type') eq 'private' && $tags =~ m/(?:^|,)notify_private(?:,|$)/;
}

sub notify {
  my ($sender) = @_;
  weechat::log_print("notify") if _DEBUG();
  my $count = scalar keys %buffered_pv_msg;
  $count ? print $io_fh "$options{icon} [$count] $sender ($buffered_pv_msg{$sender})\n" : print $io_fh "\n";
  weechat::WEECHAT_RC_OK;
}

sub notify_on_private {
  my ($buffer, $tags) = @_;
  weechat::log_print("notify_on_private") if _DEBUG();
  if (is_private_message($buffer, $tags)) {
    my $sender = get_msg_sender($tags);
    rm_from_stack($sender);
    push(@stacked_notif, $sender);
    $buffered_pv_msg{$sender}++;
    notify $sender;
  } else {
    weechat::WEECHAT_RC_OK;
  }
}

sub print_author_and_count_priv_msg {
  my ($data, $buffer, $date, $tags, $displayed, $highlight, $prefix, $message) = @_;
  weechat::log_print("print_author_and_count_priv_msg") if _DEBUG();
  my $dispatch = {
    0 => sub { weechat::WEECHAT_RC_OK }, # return if message is filtered
    1 => sub {
      is_my_message($tags, $buffer) ? weechat::WEECHAT_RC_OK : notify_on_private($buffer, $tags);
    },
  };
  $dispatch->{$displayed}->();
}

sub unnotify {
  my ($signal, $type_data, $signal_data) = @_;
  weechat::log_print("unnotify") if _DEBUG();
  my $type=weechat::buffer_get_string($signal_data, 'localvar_type');
  my $channel=weechat::buffer_get_string($signal_data, 'localvar_channel');
  my $dispatch = {
    'private' => sub {
       rm_sender_notif($channel);
       scalar(@stacked_notif) ? notify($stacked_notif[-1]) : notify();
     },
  };
  ($dispatch->{$type} || sub { weechat::WEECHAT_RC_OK })->();
}

sub rm_from_stack {
  my ($sender) = @_;
  my @stack = ();
  foreach (@stacked_notif) { push(@stack, $_) if ($_ ne $sender) }
  @stacked_notif = @stack;
}

sub rm_sender_notif {
  my ($sender) = @_;
  delete($buffered_pv_msg{$sender});
  rm_from_stack($sender);
}

sub shutdown {
  weechat::log_print("shutdown") if _DEBUG();
  close $io_fh;
}
