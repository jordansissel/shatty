# shatty

share tty.

## Play a demo recording

```
% ruby shatty.rb play examples/output.shatty
```

## Recording

```
% shatty.rb record <command>
```

By default will record to 'output.shatty'

## Playback

```
% shatty.rb play output.shatty
```

## Sharing

TBD.

* read-only
* read/write

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
* Online sharing
  * Live sharing
  * Multiuser
  * Sharing recorded sessions
* Terminal size options
  * Currently stuck at default 80x24, fix that.
* Improve & document recording format
  * Currently a sequence of [play_time, length, data].pack("GNA*")
* Implement a terminal emulator so we can calculate key frames to better support playback/rewind
