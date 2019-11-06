require 'zip'
require 'date'

class AspaceSitemapRunner < JobRunner
  
  register_for_job_type('aspace_sitemap_job')
  
  def run
    
    # these could become user set in the frontend, but not right now
    sitemap_limit = AppConfig.has_key?(:aspace_sitemap_limit) ? AppConfig[:aspace_sitemap_limit] : 50000
    sitemap_index_base_url = AppConfig.has_key?(:aspace_sitemap_baseurl) ? AppConfig[:aspace_sitemap_baseurl] : "https://change.to.my.site.baseurl/"
    timestamp = Time.now.strftime("%Y-%m-%d") # add '-%H-%M-%S-%L' if need additional granualrity
    @job.write_output('Generating sitemap')
    array = []
    files = []
    
    begin
      DB.open do |db|
        db.fetch(query_string) do |result|
          row = result.to_hash
          fix_row(row)
          array.push(row)
        end
      end
      
      return if array.count == 0
      
      # split the results set into chunks of less than the sitemap entry limit
      sitemap_parts = array.each_slice(sitemap_limit).to_a

      # initialize a zip file
      zip_file = ASUtils.tempfile("aspace_sitemap_zip_#{timestamp}")
      # open with the OutputStream class to initialize the zip struture correctly
      Zip::OutputStream.open(zip_file) { |zos| }

      # iterate through the sitemap piecesand build our xml files
      sitemap_parts.each_with_index do |sitemap,k|
        files[k] = Tempfile.new(["aspace_sitemap_#{timestamp}_part_#{k}", ".xml"])
      
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
            sitemap.each do |entry|
              xml.url {
                xml.loc entry[:loc]
                xml.lastmod entry[:lastmod]
                xml.changefreq entry[:changefreq]
                xml.priority entry[:priority]
              }
            end
          }
        end
        files[k].write(builder.to_xml)
        files[k].rewind
      end
      
      # create a sitemap index file if necessary
      if sitemap_parts.count > 1
        index_file = Tempfile.new(["aspace_sitemap_index_#{timestamp}",".xml"])

        index_builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
            xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
              files.each_with_index do |file,k|
                xml.sitemap {
                  xml.loc "#{sitemap_index_base_url}aspace_sitemap_#{timestamp}_part_#{k}.xml"
                  xml.lastmod timestamp
                }
              end
            }
          end
        index_file.write(index_builder.to_xml)
        index_file.rewind
      end
      
      # wrap them all into a zip file
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        files.each_with_index do |file,k|
          zip.add("aspace_sitemap_#{timestamp}_part_#{k}.xml", file.path)
        end
        zip.add("aspace_sitemap_index_#{timestamp}.xml", index_file.path) if sitemap_parts.count > 1
      end
      
      @job.write_output('Adding Sitemap')
      @job.add_file(zip_file)
      self.success!
    rescue Exception => e
      @job.write_output(e.message)
      @job.write_output(e.backtrace)
      raise e
    ensure
      files.each do |file|
        file.close
        file.unlink
      end
      index_file.close if sitemap_parts.count > 1
      index_file.unlink if sitemap_parts.count > 1
      zip_file.close
      zip_file.unlink
      @job.write_output('Done.')
    end
  end
  
  def fix_row(row)
    # agents have a different location string pattern
    if ['people','families','corporate_entities'].include?(row[:source])
      row[:loc] = ["#{AppConfig[:public_proxy_url]}","agents",row[:source],row[:id]].join("/")
    else
      row[:loc] = ["#{AppConfig[:public_proxy_url]}","repositories",row[:repo_id],row[:source],row[:id]].join("/")
    end
    row[:lastmod] = row[:lastmod].strftime("%Y-%m-%d")
    row[:changefreq] = AppConfig.has_key?(:aspace_sitemap_changefreq)? AppConfig[:aspace_sitemap_changefreq] : "yearly"
    row[:priority] = "0.5"
    
    #remove columns we don't need
    row.delete(:id)
    row.delete(:repo_id)
    row.delete(:publish)
    row.delete(:source)
  end
  
  def query_string

    sitemap_types = AppConfig.has_key?(:aspace_sitemap_types) ? AppConfig[:aspace_sitemap_types] : ['resource','archival_object','digital_object','agent_person','agent_family','agent_corporate_entity']
    
    sitemap_types_map = {'resource' => 'resources',
                         'archival_object' => 'archival_objects',
                         'digital_object' => 'digital_objects',
                         'agent_person' => 'people', 
                         'agent_family' => 'families',
                         'agent_corporate_entity' => 'corporate_entities'
                         }
    
    queries = []
    
    sitemap_types.each do |type|
      
      # agents don't have a repo_id so we have to supply one to make the columns match up
      if type.include?('agent')
        repo_line = "'0' AS repo_id"
      else repo_line = "repo_id"
      end
      
      queries <<
      "(SELECT
          publish,
          #{repo_line},
          id,
          user_mtime AS lastmod,
          '#{sitemap_types_map[type]}' AS source
        FROM
          #{type}
        WHERE
          publish = 1)"
    end
    
   return queries.compact.join("UNION")
    
    # query_string will become something like the below
    #"(SELECT
    #  publish,
    #  repo_id,
    #  id,
    #  user_mtime AS lastmod,
    #  'archival_objects' AS source
    #FROM
    #  archival_object
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  repo_id,
    #  id,
    #  user_mtime AS lastmod,
    #  'resources' AS source
    #FROM
    #  resource
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  repo_id,
    #  id,
    #  user_mtime AS lastmod,
    #  'digital_objects' AS source
    #FROM
    #  digital_object
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  '0' AS repo_id,
    #  id,
    #  user_mtime AS lastmod,
    #  'people' AS source
    #FROM
    #  agent_person
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  '0' AS repo_id,
    #  id,
    #  user_mtime AS lastmod,
    #  'families' AS source
    #FROM
    #  agent_family
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  '0' AS repo_id,
    #  id,
    #  user_mtime AS lastmod,
    #  'corporate_entities' AS source
    #FROM
    #  agent_corporate_entity
    #WHERE
    #  publish = 1)"
  end
  
end