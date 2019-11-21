{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",

    "properties" => {
      "format" => {
        "type" => "string",
        "ifmissing" => "error"
      },
      "sitemap_baseurl" => {
        "type" => "string",
        "ifmissing" => "error"
      },
      "sitemap_limit" => {
        "type" => "string",
        "ifmissing" => "error"
      },
       "sitemap_refresh_freq" => {
        "type" => "string",
        "ifmissing" => "error"
      },
       "sitemap_use_slugs" => {
        "type" => "boolean",
      },
      "sitemap_types" => {
        "type" => "array",
        "ifmissing" => "error",
        "minItems" => 1,
        "items" => {
          "type" => "string"
        }
      }
    }
  }
}
