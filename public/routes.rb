ArchivesSpacePublic::Application.routes.draw do
  match 'static/html/:page' => 'static_pages#page', :via => [:get]
  match 'static/sitemap/sitemap_root' => 'sitemap#sitemap_root', :defaults => { :format => 'json' }, :via => [:get]
end
