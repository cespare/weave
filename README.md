# Weave

Simple parallel ssh.

## Install

Put `weave` in your Gemfile or install directly:

    $ gem install weave

## Documentation

[Method docs here](http://rubydoc.info/github/cespare/weave/master/frames). Usage docs coming soon. See the
examples (in `examples/`) to get started.


## Implemented features

* Connection caching
* Parallel execution (with thread/connection limit)
* Serial execution
* Commands:

  - `run`

## Other ideas

* Commands:

  - `sudo`
  - `rsync`
  - `put`?
  - `get`?

* Handle password prompts (maybe just sudo prompt)
* Handle ctrl-c correctly?

## To do:

* Full readme with detailed usage
