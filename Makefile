.PHONY: setup server deps test lint

setup: deps

deps:
	mix deps.get

server:
	mix phx.server

test:
	mix test

lint:
	mix format --check-formatted && mix credo
