require 'sinatra'
require 'json'
require './lib/slack'
require './lib/db'
require './lib/slack_logger'
require './lib/slack_import'

slack_logger = SlackLogger.new
slack_import = SlackImport.new

def users
  hashed_users = {}
  Users.find.each do |u|
    hashed_users[u[:id]] = u
  end
  hashed_users
end

def channels
  hashed_channels = {}
  Channels.find.sort(name: 1).each do |c|
    hashed_channels[c[:id]] = c
  end
  hashed_channels
end

def messages(params)
  Messages
    .find(
      channel: params[:channel],
      ts: { '$lt' =>  params[:min_ts] || Time.now.to_i.to_s }
    )
    .sort(ts: -1)
    .limit(params[:limit] || 100)
end

get '/users.json' do
  content_type :json
  users.to_json
end

get '/channels.json' do
  content_type :json
  channels.to_json
end

post '/messages/:channel.json' do
  content_type :json
  messages(params)
    .to_a
    .reverse
    .to_json
end

get '/team.json' do
  content_type :json
  Slack.team_info['team'].to_json
end

post '/stop_logger' do
  slack_logger.stop
end

post '/start_logger' do
  slack_logger.start
end

get '/logger_status.json' do
  content_type :json
  slack_logger.status.to_json
end

post '/import_data' do
  exported_file = '/tmp/slack_export.zip'
  FileUtils.move(params[:file][:tempfile], exported_file)
  slack_import.import_from_file(exported_file)
end

get '/' do
  if request.path_info === '' then
    return redirect to('./')
  end
  erb :index
end

get '/:channel' do
  erb :index
end
