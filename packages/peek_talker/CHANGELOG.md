# Changelog

## 1.0.0

The first release: `PeekTalkerAdapter`, which lets Peek read the network
calls Talker already logs.

- Subscribes to Talker's stream and, by default, replays its history
  oldest first, so a call that failed before Peek was attached is still
  there to read.
- Understands `talker_dio_logger` out of the box, correlating a request
  log with its response or error; a response whose request Talker never
  logged is recorded whole rather than dropped.
- Open to other loggers: a `PeekTalkerLogMapper` claims the log types it
  knows and leaves the rest alone.
