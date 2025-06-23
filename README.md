# PgInsights ✨

[![Gem Version](https://badge.fury.io/rb/pg_insights.svg)](https://badge.fury.io/rb/pg_insights)
[![CI](https://github.com/mezbahalam/pg_insights/actions/workflows/ci.yml/badge.svg)](https://github.com/mezbahalam/pg_insights/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**PgInsights** is a Rails engine that provides a beautiful and plug-and-play dashboard for analyzing PostgreSQL performance and health directly within your Rails application. Get instant insights into your database's behavior, optimize slow queries, and monitor key metrics with ease.

It's designed for developers who want a quick way to get critical database-level insights without leaving their application or setting up external monitoring tools.

## Features

- **📊 Beautiful Dashboard:** A clean and modern UI to visualize your database insights.
- **📈 Chart-Powered Visualizations:** Uses [Chartkick](https://chartkick.com/) to render beautiful, interactive charts.
- **🚀 Pre-defined Queries:** Comes with a set of built-in queries for common checks like active connections, long-running queries, cache hit rates, and more.
- **✍️ Custom SQL Runner:** Write and run your own `SELECT` queries against your database.
- **💾 Save & Manage Queries:** Save your frequently used queries for quick access.
- **🔒 Safe & Secure:** Enforces read-only queries and uses statement timeouts to prevent long-running queries from impacting your application.
- **🔌 Plug-and-Play:** Easy to install and requires minimal configuration.

## Screenshots

*(Add a screenshot of the dashboard here)*

## Installation

1. Add this line to your application's Gemfile:

```ruby
gem "pg_insights", "~> 0.1.0"
```

2. And then execute:
```bash
$ bundle install
```

3. Run the installer to copy migrations and mount the engine:
```bash
$ rails g pg_insights:install
```

This will add the engine's route to your `config/routes.rb` and copy the necessary migration file.

4. Run the database migration:
```bash
$ rails db:migrate
```

This will create the `pg_insights_queries` table needed to store your saved queries.

## Usage

Navigate to `/pg_insights` in your browser to access the dashboard.

From there, you can:
- Select a pre-defined query from the sidebar to see its results.
- Write your own SQL in the editor and click "Run Query".
- Save a query you've written by giving it a name and clicking "Save".

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [RubyGems.org](https://rubygems.org).

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

1. Fork the repository.
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create a new Pull Request.

Please make sure to update tests as appropriate.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgements

- Built with ❤️ for the Rails community.
- Inspired by tools like pg_hero.
