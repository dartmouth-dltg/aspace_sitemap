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
      "sitemap_types_resource" => {
        "type" => "boolean",
      },
      "sitemap_types_accession" => {
        "type" => "boolean",
      },
      "sitemap_types_archival_object" => {
        "type" => "boolean",
      },
      "sitemap_types_agent_person" => {
        "type" => "boolean",
      },
      "sitemap_types_agent_family" => {
        "type" => "boolean",
      },
      "sitemap_types_agent_corporate_entity" => {
        "type" => "boolean",
      },
      "sitemap_types_digital_object" => {
        "type" => "boolean",
      }
    }
  }
}
