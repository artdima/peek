# Security policy

## Supported versions

Peek is pre-1.0: fixes land on `main` and go out in the next release. Once
1.0 is out, the latest minor version is the supported one.

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Report it through [GitHub's private vulnerability reporting](https://github.com/artdima/peek/security/advisories/new)
— the **Report a vulnerability** button on the repository's Security tab —
or by email to <mail@artdima.ru>. Include what you did, what happened, and the versions of
Peek and Flutter you used. You will get an acknowledgement within a few
days, and an honest estimate of when a fix will land.

## What is in scope

Peek reads network calls an app has already made, so the interesting risk is
what it keeps and shows rather than what it sends — it sends nothing.
Reports worth sending include:

- Redaction failing to redact: a header, query parameter or body field that
  `PeekRedactionPolicy` should have masked and did not.
- A secret reaching somewhere Peek was not asked to put it — an exported
  file, the clipboard, a `toString`, an error handed to `PeekOptions.onError`.
- An adapter changing the request or response it observes, rather than only
  watching it.
- A way for a crash inside Peek to reach the app that embeds it.

## What is not

- Peek showing the data an app itself sent or received: that is what a
  network log is. What an app does with Peek's screens — shipping them to
  end users, say — is the app's own decision, and `PeekOptions.enabled` is
  the switch for it.
- Vulnerabilities in Dio, Talker or another logger. Please report those to
  the project concerned.
