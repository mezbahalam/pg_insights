require_relative "lib/pg_insights/version"

Gem::Specification.new do |spec|
  spec.name        = "pg_insights"
  spec.version     = PgInsights::VERSION
  spec.authors     = [ "Mezbah Alam" ]
  spec.email       = [ "mezbah@infolily.com" ]
  spec.homepage    = "https://github.com/mezbahalam/pg_insights"
  spec.summary     = "PostgreSQL insights dashboard engine for Rails applications."
  spec.description = "PgInsights provides a plug-and-play insights dashboard for analyzing PostgreSQL performance and query data inside any Rails application."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mezbahalam/pg_insights"
  spec.metadata["changelog_uri"] = "https://github.com/mezbahalam/pg_insights/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 6.1"
end
