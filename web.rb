require 'sinatra'
require 'rest-client'
require 'json'
require 'slack-notifier'
require 'logger'
$stdout.sync = true

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

get '/' do
  "This is a thing"
end

post '/' do

  # Verify all environment variables are set
  return [403, "No slack token setup"] unless slack_token = ENV['SLACK_TOKEN']
  return [403, "No jenkins url setup"] unless jenkins_url= ENV['JENKINS_URL']
  return [403, "No jenkins token setup"] unless jenkins_token= ENV['JENKINS_TOKEN']

  # Verify slack token matches environment variable
  #return [401, "No authorized for this command,token:" + slack_token] unless slack_token == params['token']

  # Split command text
  logger.info(params['text'])
  puts params['text']
  puts params
  args = params['text']
  text_parts = args.split(' ')
  puts "args", args
  puts "text_parts", text_parts
  # Split command text - job
  job = text_parts[0]

  # Split command text - parameters
  parameters = text_parts[1:].map(&:inspect).join('&')
  # Jenkins url
  jenkins_job_url = "#{jenkins_url}/job/#{job}"
  logger.info( jenkins_job_url) #debug

  # Get next jenkins job build number
  resp = RestClient.get "#{jenkins_job_url}/api/json"
  logger.info( resp) #debug
  resp_json = JSON.parse( resp.body )
  logger.info( resp_json) #debug
  next_build_number = resp_json['nextBuildNumber']
  logger.info( next_build_number ) #debug
  # Make jenkins request
  # json = JSON.generate( {:parameter => parameters} )
  # logger.info( json) #debug
  logger.info( "#{jenkins_job_url}/buildWithParameters?token=#{jenkins_token}&#{parameters}")#debug
  resp = RestClient.post "#{jenkins_job_url}/buildWithParameters?token=#{jenkins_token}&#{parameters}"
  puts resp
  # Build url
  build_url = "https://ci.rescmshost.com/job/#{job}/#{next_build_number}"

  slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
  if slack_webhook_url
    notifier = Slack::Notifier.new slack_webhook_url
    notifier.ping "Started job '#{job}' - #{build_url}"
  end

  build_url

end
