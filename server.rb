require 'rubygems'
require 'sinatra'
require 'omniauth-auth0'
require 'dotenv/load'

#### Sinatra App ####
class App < Sinatra::Base
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']


  #### Auth0 ####
  use OmniAuth::Builder do
    provider :auth0, ENV['CLIENT_ID'], ENV['CLIENT_SECRET'], ENV['CLIENT_DOMAIN']
  end

  # Don't raise exceptions even when developing locally
  # Comment this line out for local debugging of OmniAuth
  OmniAuth.config.failure_raise_out_environments = []

  # Ensure we use TLS in all non-local environments
  before do
    if !request.path.start_with?('/assets/')
      if request.host != 'localhost'
        if !request.secure?
          halt 400, File.read("_site/400.html")
        end
      end
    end
  end

  def user_from_omniauth(auth)
    {
      uid: auth.uid,
      provider: auth.provider,
      username: auth.info.nickname,
      name: auth.info.name,
      email: auth.info.email,
      avatar_url: auth.info.image
    }
  end

  get '/auth/failure' do
    status 401
    File.read("_site/401.html")
  end

  get '/auth/logout' do
    session[:authenticated] = false
    redirect to("/?logged-out=#{rand(100000000)}")
  end

  get '/auth/auth0/callback' do
    user = user_from_omniauth(env['omniauth.auth'])
    session[:authenticated] = true
    redirect to(session['redirect_to'] || '/')
  rescue StandardError
    status 401
    File.read("_site/401.html")
  end

  #### Display wiki pages generated by Jekyll ####
  get '/*' do
    fname = params[:splat][0]

    if !fname.start_with?('assets/')
      # If not authenticated and auth not disallowed, send to login page
      if !session[:authenticated] && !(ENV['AUTH_DISABLED'].to_s.downcase == 'true')
        session['redirect_to'] = "/#{fname}"
        return redirect to('/auth/auth0')
      end
    end
    
    fname = 'index' if fname.empty?
    path = File.join("_site", fname.to_s)
    if File.exist?(path)
      return send_file(path)
    else
      if File.exist?("#{path}.html")
        return send_file("#{path}.html")
      end
    end

    status 404
    File.read("_site/404.html")
  end
end
