require "jekyll-import";
    JekyllImport::Importers::WordPress.run({
      "dbname"         => "db",
      "user"           => "user",
      "password"       => "pw",
      "host"           => "127.0.0.1",
      "port"           => "3306",
      "socket"         => "",
      "table_prefix"   => "",
      "site_prefix"    => "",
      "clean_entities" => true,
      "comments"       => true,
      "categories"     => true,
      "tags"           => true,
      "more_excerpt"   => true,
      "more_anchor"    => true,
      "extension"      => "html",
      "status"         => ["publish"]
    })