# shatty

share tty.

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
