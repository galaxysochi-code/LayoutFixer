# Security Policy

## Supported versions

The latest release is the supported one.

## Reporting a vulnerability

Please report security issues privately through
[GitHub Security Advisories](https://github.com/galaxysochi-code/LayoutFixer/security/advisories/new)
instead of opening a public issue.

Include the macOS version, the app version and the steps to reproduce. You will get a reply as soon
as possible; this is a personal project, so please allow a few days.

## Scope worth attention

This app receives every keystroke, so the areas that matter most are:

- anything that could write typed text to disk, a log or the network;
- the handling of password fields and secure input;
- the clipboard handling in the selection actions;
- code injection through the exceptions or snippets files.
