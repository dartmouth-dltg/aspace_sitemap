class AspaceSitemapRunner < JobRunner
  
  register_for_job_type('aspace_sitemap_job')
  
  def run
    @job.write_output('Generating sitemap')
    file = ASUtils.tempfile('aspace_sitemap_job_')
    array = []
    begin
      DB.open do |db|
        db.fetch(query_string) do |result|
          row = result.to_hash
          fix_row(row)
          array.push(row)
        end
      end
      
      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
          array.each do |entry|
            xml.url {
              xml.loc entry[:loc]
              xml.lastmod entry[:lastmod]
              xml.changefreq entry[:changefreq]
              xml.priority entry[:priority]
            }
          end
        }
      end
      file.write(builder.to_xml)
      file.rewind
      @job.write_output('Adding Sitemap')
      @job.add_file(file)
      self.success!
    rescue Exception => e
      @job.write_output(e.message)
      @job.write_output(e.backtrace)
      raise e
    ensure
      file.close
      file.unlink
      @job.write_output('Done.')
    end
  end
  
  def fix_row(row)
    if ['people','families','corporate_entities'].include?(row[:source])
      row[:loc] = ["#{AppConfig[:public_proxy_url]}","agents",row[:source],row[:id]].join("/")
    else
      row[:loc] = ["#{AppConfig[:public_proxy_url]}","repositories",row[:repo_id],row[:source],row[:id]].join("/")
    end
    row[:lastmod] = row[:lastmod].strftime("%Y-%m-%d")
    row[:changefreq] = "yearly"
    row[:priority] = "0.5"
    row.delete(:id)
    row.delete(:repo_id)
    row.delete(:publish)
    row.delete(:source)
  end
  
  def query_string
    "
    (SELECT
      publish,
      repo_id,
      id,
      user_mtime AS lastmod,
      'archival_objects' AS source
    FROM
      archival_object
    WHERE
      publish = 1)
    UNION
    (SELECT
      publish,
      repo_id,
      id,
      user_mtime AS lastmod,
      'resources' AS source
    FROM
      resource
    WHERE
      publish = 1)
    UNION
    (SELECT
      publish,
      repo_id,
      id,
      user_mtime AS lastmod,
      'digital_objects' AS source
    FROM
      digital_object
    WHERE
      publish = 1)
    UNION
    (SELECT
      publish,
      '0' AS repo_id,
      id,
      user_mtime AS lastmod,
      'people' AS source
    FROM
      agent_person
    WHERE
      publish = 1)
    UNION
    (SELECT
      publish,
      '0' AS repo_id,
      id,
      user_mtime AS lastmod,
      'families' AS source
    FROM
      agent_family
    WHERE
      publish = 1)
    UNION
    (SELECT
      publish,
      '0' AS repo_id,
      id,
      user_mtime AS lastmod,
      'corporate_entities' AS source
    FROM
      agent_corporate_entity
    WHERE
      publish = 1)
    "
  end
  
end