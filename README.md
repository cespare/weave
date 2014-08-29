# Weave

Simple parallel ssh.

## Install

Put `weave` in your Gemfile or install directly:

    $ gem install weave

## Documentation

[Method docs here](http://rubydoc.info/github/cespare/weave/master/frames). See the examples (in `examples/`)
to get started.

## Implemented features

* Connection caching
* Parallel execution (with thread/connection limit)
* Serial execution
* Commands:

  - `run`

## Tests

You need vagrant installed. `vagrant up` to get the machines running. Then:

    $ bundle exec rake test
