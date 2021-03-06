require 'sinatra'
require 'rest-client'
require 'json'
require 'slack-notifier'
require 'logger'
$stdout.sync = true

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

get '/' do
  "This is a thing"
end

post '/' do

  # Verify all environment variables are set
  return [403, "Config Error: No slack token setup"] unless slack_token = ENV['SLACK_TOKEN']
  return [403, "Config Error: No jenkins url setup"] unless jenkins_url= ENV['JENKINS_URL']
  return [403, "Config Error: No jenkins build token setup"] unless jenkins_token= ENV['JENKINS_TOKEN']

  # Verify slack token matches environment variable
  return [401, "Not authorized for this command, must use slack to initiate builds."] unless slack_token == params['token']

  # Split command text
  logger.debug(params)
  args = params['text']
  text_parts = args.split(' ')

  # Slice out the job name
  job = text_parts[0]
  if text_parts.size > 1 
  #format parameters (all our parameters need to be capitalize like MONIKER=abc)
    formatted_params = []
    #Skip the job name and the capitalize the variable names
    text_parts[1..-1].each{ |p|  var = /(.*=)/.match(p)[0].upcase 
                   par = /=(.*)/.match(p)[0]
                   formatted_params << var + par.tr('=','') }

    # Split command text - parameters
    parameters = formatted_params.map(&:inspect).join('&').tr('"','')
  end
  # Jenkins url
  jenkins_job_url = "#{jenkins_url}/job/#{job}"
  logger.debug( jenkins_job_url) #debug

  # Get next jenkins job build number
  resp = RestClient.get "#{jenkins_job_url}/api/json"
  resp_json = JSON.parse( resp.body )

  next_build_number = resp_json['nextBuildNumber']
  
  # Make jenkins request
  json = JSON.generate( { "" => "" } )

  logger.debug( "#{jenkins_job_url}/buildWithParameters?token=#{jenkins_token}&#{parameters}")#debug
  if parameters
    resp = RestClient.post "#{jenkins_job_url}/buildWithParameters?token=#{jenkins_token}&#{parameters}", :json => json
  else
    resp = RestClient.post "#{jenkins_job_url}/build?token=#{jenkins_token}", :json => json
  end
  # Build url
  build_url = "https://ci.rescmshost.com/job/#{job}/#{next_build_number}"

  user_name = params['user_name']
  slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
  if slack_webhook_url
    notifier = Slack::Notifier.new slack_webhook_url
    if parameters
      notifier.ping "Started job '#{job}' - #{build_url} with parameters: #{parameters} for #{user_name}"
    else
      notifier.ping "Started job '#{job}' - #{build_url} for #{user_name}"
    end
  end

  build_url

end
