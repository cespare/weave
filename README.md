# Gossamer

Simple parallel ssh.

## Implemented features

* Connection caching
* Parallel execution (need thread/connection limit?)
* Serial execution
* Commands:

  - `run`

## Unimplemented features

* Commands:

  - `sudo`
  - `rsync`
  - `put`?
  - `get`?

* Need to handle password prompts (maybe just sudo prompt)
* Handle ctrl-c correctly
