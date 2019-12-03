require 'zip'
require 'date'
require 'nokogiri'
require 'fileutils'

class AspaceSitemapRunner < JobRunner

  register_for_job_type('aspace_sitemap_job')

  def run

    # make sure the sitemap_types actually are allowed
    @sitemap_types = @json.job['sitemap_types'].reject{|st| !AppConfig[:allowed_sitemap_types_hash].keys.include?(st)}

    # setup some of our other variables
    @use_slugs = AppConfig.has_key?(:use_human_readable_urls) && AppConfig[:use_human_readable_urls] ? @json.job['sitemap_use_slugs'] : false
    default_limit = AppConfig[:aspace_sitemap_default_limit]
    sitemap_limit = @json.job['sitemap_limit'].to_i
    sitemap_index_base_url = @json.job['sitemap_baseurl']
    # make sure the sitemap url ends in a "/"
    unless sitemap_index_base_url[-1] == "/"
      sitemap_index_base_url += "/"
    end
    # make sure the sitemap url starts with https://
    unless sitemap_index_base_url =~ /^https:\/\//
      sitemap_index_base_url.prepend('https://')
    end
    refresh_freq = @json.job['sitemap_refresh_freq']
    @pui_base_url = AppConfig[:public_proxy_url]
    # make sure the public url ends in a "/"
    unless @pui_base_url[-1] == "/"
      @pui_base_url += "/"
    end

    # muck about with paths and filenames depending on if we are writing to the filesystem
    index_filename = "aspace_sitemap_index"
    sitemap_index_loc = @json.job['sitemap_use_filesys'] ? "#{@pui_base_url}static/html/" : sitemap_index_base_url
    static_page_loc = "#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}/public/pages/"
    sitemap_filename_prefix = "aspace_sitemap_part_"

    # this should never happen
    if @sitemap_types.count == 0
      @job.write_output('No types selected for sitemap. No sitemap generated.')
      return
    end

    # make sure the sitemap limit is less than the google limit
    unless sitemap_limit <= default_limit
      sitemap_limit = default_limit
    end

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

      if array.count == 0
        @job.write_output('No published objects found. No sitemap generated.')
        return
      end
      
      # explicitly add some 'static' pages - like the homepage!
      static_pages = ["","search?reset=true"]
      static_pages.each do |sp|
        array.push({:loc => "#{@pui_base_url}"+sp, :lastmod => Time.now.strftime("%Y-%m-%d")})
      end

      # split the results set into chunks of less than the sitemap entry limit
      sitemap_parts = array.each_slice(sitemap_limit).to_a

      # initialize a zip file
      zip_file = ASUtils.tempfile("aspace_sitemap_zip")
      # open with the OutputStream class to initialize the zip structure correctly
      Zip::OutputStream.open(zip_file) { |zos| }

      # iterate through the sitemap pieces and build our xml files
      sitemap_parts.each_with_index do |sitemap,k|
        files[k] = Tempfile.new(["#{sitemap_filename_prefix}#{k}", ".xml"])
        files[k].write(create_sitemap_file(sitemap, refresh_freq).to_xml)
        files[k].rewind
      end

      # create a sitemap index file
      index_file = Tempfile.new([index_filename,".xml"])
      index_file.write(create_sitemap_index(files, sitemap_index_loc, sitemap_filename_prefix).to_xml)
      index_file.rewind

      # wrap them all into a zip file
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        files.each_with_index do |file,k|
          zip.add("#{sitemap_filename_prefix}#{k}.xml", file.path)
        end
        zip.add("#{index_filename}.xml", index_file.path)
      end

      # writing to local filesystem
      if @json.job['sitemap_use_filesys']
        files.each_with_index do |file,k|
          FileUtils.cp(file, "#{static_page_loc}#{sitemap_filename_prefix}#{k}.xml")
        end
        FileUtils.cp(index_file, "#{static_page_loc}#{index_filename}.xml")
      end

      # close it out
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
      index_file.close
      index_file.unlink
      zip_file.close
      zip_file.unlink
      @job.write_output('Done.')
    end
  end

  def create_sitemap_file(sitemap, refresh_freq)

    sitemap_build = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
            sitemap.each do |entry|
              xml.url {
                xml.loc entry[:loc]
                xml.lastmod entry[:lastmod]
                xml.changefreq refresh_freq
              }
            end
          }
        end
    sitemap_build
  end

  def create_sitemap_index(files, sitemap_index_loc, sitemap_filename_prefix)

    index_build = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
            files.each_with_index do |file,k|
              xml.sitemap {
                xml.loc "#{sitemap_index_loc}#{sitemap_filename_prefix}#{k}.xml"
                xml.lastmod Time.now.strftime("%Y-%m-%d")
              }
            end
          }
        end
    index_build
  end

  def fix_row(row)

    # use slugs if set, otherwise use the standard url form based on ids
    if @use_slugs && !row[:slug].nil?
      # agents have a different location string pattern
      if ['people','families','corporate_entities','software'].include?(row[:source])
        row[:source] = "agents"
      end
      row[:loc] = ["#{@pui_base_url.chop}",row[:source],row[:slug]].join("/")
    else
      # agents have a different location string pattern
      if ['people','families','corporate_entities','software'].include?(row[:source])
        row[:loc] = ["#{@pui_base_url.chop}","agents",row[:source],row[:id]].join("/")
      else
        row[:loc] = ["#{@pui_base_url.chop}","repositories",row[:repo_id],row[:source],row[:id]].join("/")
      end
    end

    row[:lastmod] = row[:lastmod].strftime("%Y-%m-%d")

    # remove columns we don't need
    row.delete(:id)
    row.delete(:repo_id)
    row.delete(:publish)
    row.delete(:source)
    row.delete(:slug) if @use_slugs
  end

  def query_string

    queries = []
    slug_query = @use_slugs ? "slug," : ""

    @sitemap_types.each do |type|

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
          #{slug_query}
          user_mtime AS lastmod,
          '#{AppConfig[:allowed_sitemap_types_hash][type]}' AS source
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
    #  slug,
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
    #  slug,
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
    #  slug,
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
    #  slug,
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
    #  slug,
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
    #  slug,
    #  user_mtime AS lastmod,
    #  'corporate_entities' AS source
    #FROM
    #  agent_corporate_entity
    #WHERE
    #  publish = 1)"
  end

end
