# Gossamer

Simple parallel ssh.

## Implemented features

* Connection caching
* Parallel execution (need thread/connection limit?)
* Commands:

  - `run`

## Unimplemented features

* Commands:

  - `sudo`
  - `rsync`
  - `put`?
  - `get`?

* Handle ssh config settings (or a subset of them) (needed for vagrant)
* Need to handle password prompts (maybe just sudo prompt)
* Opening a pty at the remote end likely the best way to manage things
* How to give stderr/stdout back to the user?
* Print line-by-line, prefixed with hostname. (Also print input? Indicate stdout/stderr at the beginning of
  each line?
* Handle ctrl-c correctly

