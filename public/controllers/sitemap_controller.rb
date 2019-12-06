class SitemapController < ApplicationController
  
  def sitemap_root
    respond_to do |format|
      format.json { render :text => "#{AppConfig[:sitemap_pui_rails_route]}"}
    end
  end

end
