# frozen_string_literal: true

def init_oneagent_sdk(logging_callback)
  require_relative 'oneagentsdk'

  stub_version = OneAgentSDK::Onesdk_stub_version_t.new
  OneAgentSDK.onesdk_stub_get_version(stub_version)
  puts "stub_version: #{stub_version[:major]}.#{stub_version[:minor]}.#{stub_version[:patch]}"

  puts 'initializing OneAgentSDK'

  ret_init = OneAgentSDK.onesdk_initialize
  print "> onesdk_initialize returned #{ret_init}"
  puts " --> ONESDK_SUCCESS" if ret_init == OneAgentSDK::ONESDK_SUCCESS
  puts " != ONESDK_SUCCESS!" if ret_init != OneAgentSDK::ONESDK_SUCCESS

  OneAgentSDK.onesdk_agent_set_logging_callback(logging_callback)

  state = OneAgentSDK.onesdk_agent_get_current_state
  puts "> onesdk_agent_get_current_state  = #{state} (#{OneAgentSDK.description_for_state(state)})"
  puts "> onesdk_agent_get_version_string = '#{OneAgentSDK.onesdk_agent_get_version_string}'"

  return ret_init
end

def shutdown_oneagent_sdk(ret_init)
  if ret_init == OneAgentSDK::ONESDK_SUCCESS
    puts 'shutting down OneAgentSDK'
    OneAgentSDK.onesdk_shutdown 
  end
end

def test_webrequests_outgoing
  puts '=== test_webrequests_outgoing ==='

  require 'net/http'

  10.times do |i|
    url = "http://www.example.com?param=#{i}"
    uri = URI(url)
    
    puts "starting web request to #{url}"

    tracer = OneAgentSDK.onesdk_outgoingwebrequesttracer_create(
      OneAgentSDK.onesdk_asciistr(url), 
      OneAgentSDK.onesdk_asciistr('GET')
    )

    puts "> tracer = #{tracer}"
    
    OneAgentSDK.onesdk_outgoingwebrequesttracer_add_request_header(
      tracer,
      OneAgentSDK.onesdk_asciistr("Accept-Charset"), 
      OneAgentSDK.onesdk_asciistr("utf-8")
    )

    OneAgentSDK.onesdk_tracer_start(tracer)

    tag = OneAgentSDK.onesdk_tracer_get_outgoing_dynatrace_string_tag(tracer)
    puts "> tag = #{tag}"

    request = Net::HTTP::Get.new(uri)
    request[OneAgentSDK::ONESDK_DYNATRACE_HTTP_HEADER_NAME] = tag

    response = Net::HTTP.start(uri.hostname, uri.port) { |http|
      http.request(request)
    }

    response.header.each do |name, value|
      OneAgentSDK.onesdk_outgoingwebrequesttracer_add_response_header(
        tracer,
        OneAgentSDK.onesdk_asciistr(name),
        OneAgentSDK.onesdk_asciistr(value)
      )
    end

    OneAgentSDK.onesdk_outgoingwebrequesttracer_set_status_code(tracer, response.code.to_i)

    OneAgentSDK.onesdk_tracer_end(tracer)
  end
end

def test_database_call
  puts '=== test_database_call ==='

  dbinfo_handle = OneAgentSDK.onesdk_databaseinfo_create(
    "My Postgres DB", 
    OneAgentSDK::ONESDK_DATABASE_VENDOR_POSTGRESQL, 
    OneAgentSDK::ONESDK_CHANNEL_TYPE_TCP_IP, 
    "localhost:12345"
  )

  10.times do |i|
    stmt = "SELECT foo FROM bar WHERE category = #{i};"
    tracer = OneAgentSDK.onesdk_databaserequesttracer_create_sql(dbinfo_handle, stmt)
    puts "> tracer = #{tracer}"

    OneAgentSDK.onesdk_tracer_start(tracer)
    
    # perform the database request, consume results ...
    sleep 0.01

    OneAgentSDK.onesdk_databaserequesttracer_set_returned_row_count(tracer, 42*i)
    OneAgentSDK.onesdk_databaserequesttracer_set_round_trip_count(tracer, 3)

    OneAgentSDK.onesdk_tracer_end(tracer)
  end

  OneAgentSDK.onesdk_databaseinfo_delete(dbinfo_handle)
end

logging_callback = Proc.new do |msg|
  puts "### OneAgent SDK Logging Callback: <#{msg}>"
end

ret_init = init_oneagent_sdk(logging_callback)

test_webrequests_outgoing
test_database_call
sleep 10
shutdown_oneagent_sdk(ret_init)
