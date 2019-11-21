ArchivesSpacePublic::Application.routes.draw do
  match 'static/html/:page' => 'static_pages#page', :via => [:get]
end
