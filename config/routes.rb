Rails.application.routes.draw do
  post '/callback' => 'linebots#callback'
end
