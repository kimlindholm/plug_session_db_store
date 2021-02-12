# Plug.Session DB Store

[![CI](https://github.com/kimlindholm/plug_session_db_store/workflows/CI/badge.svg)](https://github.com/kimlindholm/plug_session_db_store/actions)
[![Coverage Status](https://coveralls.io/repos/github/kimlindholm/plug_session_db_store/badge.svg?branch=master)](https://coveralls.io/github/kimlindholm/plug_session_db_store?branch=master)

How-To: Database Session Store with Elixir and Plug

## Description

See article [Database Session Store with Elixir and Plug](https://medium.com/@kimlindholm/database-session-store-with-elixir-and-plug-4354740e2f58).

## Requirements

* Phoenix 1.5.4 or later
* Elixir: see section [`matrix.elixir`](.github/workflows/elixir.yml)
* Erlang: see section [`matrix.otp`](.github/workflows/elixir.yml)

## Installation

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Testing

    $ mix test
    $ mix cov

## Code Analysis

    $ mix check [--fix]

## Documentation

    $ mix docs

## License

See [LICENSE](LICENSE).
