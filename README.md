# Table Of Contents

1. [What is this?](#what-is-this)
2. [How do I run this?](#how-do-i-run-this)
3. [Data Models](#data-models)
4. [API (or how do I build a chat client)](#api)
5. [Why?](#why)
6. [What's missing?](#whats-missing)

## What is this?

It is an Elixir Phoenix-powered backend for a chat server. It has an API for performing
various account-related functionality, but all management of chat messages are handled through
Phoenix channels (a layer of abstraction above web sockets). For this reason, clients must use
the [Phoenix JavaScript Client Library](https://www.npmjs.com/package/phoenix) (or build their own version,
see [these instructions](https://hexdocs.pm/phoenix/writing_a_channels_client.html)). There are a few
ones already out there for other languages, including Swift, Elixir, Kotlin. C# and Java.

## How do I run this?

To start your Phoenix server:

- Clone the repository
- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

I am planning on deploying it, but that will come when the frontend is ready too and I have worked out all of the kinks.

## Data Models

NOTE: This section is incomplete.

The data models revolve around three types:

1. Users - M:N with conversations, 1:M with messages, 1:M with user tokens, 1:1 with a user profile
2. Conversations - M:N with users, 1:M with messages
3. Messages - M:1 with conversations, M:1 with users

Users have the publically available data, such as their display name, which will be available to anyone. When
a specific user signs in, personal data is retrieved, such as color theme, etc. However, this information
will not be available when other users are retrieving information about you, just your display name.

Users must sign up with their email address, which can also be confirmed via a token sent to the address.
Changing their email address or resetting their password is also done using tokens (though both the token
and pertinent details will be needed).

Conversations and messages are governed by the sockets.

## API

NOTE: This section is incomplete.

The REST-ish API for client interaction are as follows:
POST `/auth/register`
POST `/auth/login`
POST `/auth/refresh`
POST `/auth/confirm`
POST `/auth/password/request`
POST `/auth/password/confirm`
POST `/auth/password/reset`

POST `/api/signout_all`
POST `/api/token/email_confirm`
POST `/api/token/email_change`
PATCH `/api/password`
PATCH `/api/email`
PATCH `/api/profile`

The socket interfaces are divided into three channels (a Phoenix abstraction over sockets):
`system:general`
`user:{uuid}`
`conversation:{uuid}`

The exact parameters of these endpoints and how to use them will be explained later.

## Why

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## What's Missing

1. E2E Encryption
2. Better docs
3. Testing (including CI)
4. Email integration
5. Cleaning up various code
