# shatty

share tty.

Install with 'gem install shatty'

## start sharing

```
shatty share
```

The defaults will:

* Run $SHELL
* Generate a random endpoint on the shatty service

Here's an example:

    % shatty share 
    Sending output to: http://shatty.semicomplete.com:8200/s/88326b7f-f43e-4192-8987-c496b985abc1
    View commands
      wget -qO- http://shatty.semicomplete.com:8200/s/88326b7f-f43e-4192-8987-c496b985abc1
      curl -Lso- http://shatty.semicomplete.com:8200/s/88326b7f-f43e-4192-8987-c496b985abc1
      shatty play http://shatty.semicomplete.com:8200/s/88326b7f-f43e-4192-8987-c496b985abc1

This lets you share a terminal over http. It's built such that wget and curl
can act as viewers so whoever is viewing will not require the shatty player.

## Tricks

### Record an active tmux session

```bash
# From any shell in your tmux session:
% TMUX= ruby shatty.rb record --headless tmux -2 attach
```

The '--headless' is required otherwise you end up tmux printing to tmux and you get a loop.

## TODO

* Improved player
  * Skip forward/back
  * Tunable playing speed (1x, 2x, etc)
  * Search.
  * Pause/rewind/etc live while viewing or recording.
* Sharing recorded sessions
  * pastebin, gist, etc?
* Terminal size options
  * Currently stuck at default 80x24, fix that.
* Improve & document recording format
  * Currently a sequence of [play_time, length, data].pack("GNA*")
* Implement a terminal emulator so we can calculate key frames to better support playback/rewind

## web server

You can run the webserver (basically a thin proxy) with 'ruby web.rb'
