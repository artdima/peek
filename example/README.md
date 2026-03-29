# peek_example

A minimal app that shows Peek's user interface filled with demo data, so
the screens can be looked at on a real device while they are being built.

```sh
flutter run
```

There is no networking here: the entries come from `lib/demo_data.dart`,
which reports them through Peek's public API the way an adapter would. The
example gains a real Dio and Talker client once those adapters exist.
