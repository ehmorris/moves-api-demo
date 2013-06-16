require 'sinatra'
require 'oauth2'
require 'json'
require 'date'

# access tokens will be stored in the session
enable :sessions
set    :session_secret, 'super secret'

helpers do
  def format_date(date_str)
    Date.parse(date_str).strftime("%B %d, %Y")
  end
end

def client
  OAuth2::Client.new(
    ENV['MOVES_CLIENT_ID'],
    ENV['MOVES_CLIENT_SECRET'],
    :site => 'https://api.moves-app.com',
    :authorize_url => "https://api.moves-app.com/oauth/v1/authorize",
    :token_url => 'https://api.moves-app.com/oauth/v1/access_token')
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/auth/moves/callback'
  uri.query = nil
  uri.to_s
end

def access_token
  OAuth2::AccessToken.new(
    client,
    session[:access_token],
    :refresh_token => session[:refresh_token])
end

get "/.?:date?" do
  if session[:access_token].nil?
    @moves_authorize_uri = client.auth_code.authorize_url(
      :redirect_uri => redirect_uri,
      :scope => 'activity location')
    erb :signin
  else
    storyline_day = params['date'] || Date.today
    storyline_json = access_token.get("/api/v1/user/storyline/daily/#{storyline_day}?trackPoints=true").parsed

    @geojson = []

    storyline_json.each do |date|
      date['segments'].each do |segment|
        if segment['type'] == 'place'
          lat = segment['place']['location']['lat']
          lon = segment['place']['location']['lon']
          @geojson.push("{'type': 'point', 'coordinates': [#{lat}, #{lon}]}")
        elsif segment['type'] == 'move'
          segment['activities'].each do |activity|
            activity['trackPoints'].each do |trackpoint|
              lat = trackpoint['lat']
              lon = trackpoint['lon']
              @geojson.push("{'type': 'point', 'coordinates': [#{lat}, #{lon}]}")
            end
          end
        end
      end
    end

    erb :index
  end
end

get '/moves/logout' do
  session[:access_token] = nil
  redirect '/'
end

get '/auth/moves/callback' do
  new_token = client.auth_code.get_token(
    params[:code],
    :redirect_uri => redirect_uri)
  session[:access_token] = new_token.token
  redirect '/'
end
