# The toasty port

This directory holds the brisk port of the four Rust examples of toasty.
`prelude.bk` is the library, `examples/NAME.bk` is one program and
`examples/NAME.out` is its golden.  The runner joins the two before a run.

Run the port with this command:

```
zsh /Users/oobi/Documents/brisk/port/toasty/build.sh
```

The runner writes the joined programs to `out/`, which git ignores.  It
prints one line per example, then `PORT files=4 ok=4 fail=0`, then the
census `FORMS present=16/16`.  It exits 0 only when no example fails.

A Rust `#[auto]` id is a random uuid.  The port draws every id from one
counter and prints `00000000-0000-0000-0000-` with the counter zero padded
to twelve digits.  A golden line that the Rust source does not settle
carries the `DERIVED` mark in `PORT-LEDGER.md` with its Rust line number.
