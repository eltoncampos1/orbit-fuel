.PHONY: setup up down server dev deps \
        db.create db.migrate db.reset db.rollback \
        test lint

setup: up deps db.create db.migrate

up:
	docker compose up -d

down:
	docker compose down

deps:
	mix deps.get

server:
	mix phx.server

dev: up server

db.create:
	mix ecto.create

db.migrate:
	mix ecto.migrate

db.rollback:
	mix ecto.rollback

db.reset:
	mix ecto.reset

test:
	mix test

lint:
	mix format --check-formatted && mix credo
