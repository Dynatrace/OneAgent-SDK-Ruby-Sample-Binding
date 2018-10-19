# frozen_string_literal: true

# Copyright 2018 Dynatrace LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

def init_oneagent_sdk(logging_callback)
  require_relative 'oneagentsdk'

  stub_version = OneAgentSdk::Onesdk_stub_version_t.new
  OneAgentSdk.onesdk_stub_get_version(stub_version)
  puts "stub_version: #{stub_version[:major]}.#{stub_version[:minor]}.#{stub_version[:patch]}"

  puts 'initializing OneAgentSdk'

  ret_init = OneAgentSdk.onesdk_initialize
  print "> onesdk_initialize returned #{ret_init}"
  puts ' --> ONESDK_SUCCESS' if ret_init == OneAgentSdk::ONESDK_SUCCESS
  puts ' != ONESDK_SUCCESS!' if ret_init != OneAgentSdk::ONESDK_SUCCESS

  OneAgentSdk.onesdk_agent_set_logging_callback(logging_callback)

  state = OneAgentSdk.onesdk_agent_get_current_state
  puts "> onesdk_agent_get_current_state  = #{state} (#{OneAgentSdk.description_for_state(state)})"
  puts "> onesdk_agent_get_version_string = '#{OneAgentSdk.onesdk_agent_get_version_string}'"

  ret_init
end

def shutdown_oneagent_sdk(ret_init)
  return if ret_init == OneAgentSdk::ONESDK_SUCCESS
  puts 'shutting down OneAgentSdk'
  OneAgentSdk.onesdk_shutdown
end

class WebApplicationError < StandardError
  def message
    'Generic WebApplicationError'
  end
end

def test_webrequest_incoming
  puts '=== test_webrequest_incoming ==='

  web_application_info_handle = OneAgentSdk.onesdk_webapplicationinfo_create('example.com', 'MyRailsApplication', '/my-rails-app/')

  10.times do |i|
    path = "/my-rails-app/endpoint?param=#{i}"

    puts "incoming web request at '#{path}'"

    tracer = OneAgentSdk.onesdk_incomingwebrequesttracer_create(web_application_info_handle, path, 'GET')

    remote_address = "1.2.3.#{i % 255}:#{(i + 1) % 2**16}"
    request_headers = [['Connection', 'keep-alive'], ['Pragma', 'no-cache']]

    OneAgentSdk.onesdk_incomingwebrequesttracer_set_remote_address(tracer, remote_address)
    request_headers.each do |header|
      OneAgentSdk.onesdk_incomingwebrequesttracer_add_request_header(tracer, header[0], header[1])
    end

    OneAgentSdk.onesdk_tracer_start(tracer)

    begin
      # process incoming web request ...
      sleep 0.01 * Random.rand(10)
      raise WebApplicationError if Random.rand(10) == 0

      OneAgentSdk.onesdk_incomingwebrequesttracer_add_response_header(tracer, 'Transfer-Encoding', 'chunked')
      OneAgentSdk.onesdk_incomingwebrequesttracer_add_response_header(tracer, 'Content-Length', '1234')
      OneAgentSdk.onesdk_incomingwebrequesttracer_set_status_code(tracer, 200)
    rescue WebApplicationError => err
      OneAgentSdk.onesdk_tracer_error(tracer, err.class.name, err.message)
      # handle or re-raise
    ensure
      OneAgentSdk.onesdk_tracer_end(tracer)
    end
  end

  OneAgentSdk.onesdk_webapplicationinfo_delete(web_application_info_handle)
end

def perform_webrequest_outgoing(url)
  require 'net/http'

  url = 'http://www.thisismostlikelytofail123.com' if Random.rand(10) == 0

  tracer = OneAgentSdk.onesdk_outgoingwebrequesttracer_create(url, 'GET')

  OneAgentSdk.onesdk_outgoingwebrequesttracer_add_request_header(tracer, 'Accept-Charset', 'utf-8')

  OneAgentSdk.onesdk_tracer_start(tracer)

  begin
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)

    tag = OneAgentSdk.onesdk_tracer_get_outgoing_dynatrace_string_tag(tracer)
    request[OneAgentSdk::ONESDK_DYNATRACE_HTTP_HEADER_NAME] = tag

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    OneAgentSdk.onesdk_outgoingwebrequesttracer_set_status_code(tracer, response.code.to_i)
    response.header.each do |name, value|
      OneAgentSdk.onesdk_outgoingwebrequesttracer_add_response_header(tracer, name, value)
    end
  rescue StandardError => err
    OneAgentSdk.onesdk_tracer_error(tracer, err.class.name, err.message)
    # handle or re-raise
  ensure
    OneAgentSdk.onesdk_tracer_end(tracer)
  end
end

def test_webrequest_outgoing
  puts '=== test_webrequest_outgoing ==='

  10.times do |i|
    url = "http://www.example.com?param=#{i}"

    puts "outgoing web request to '#{url}'"
    perform_webrequest_outgoing(url)
  end
end

class DatabaseError < StandardError
  def message
    'Generic DatabaseError'
  end
end

def perform_database_call(stmt, dbinfo_handle)
  tracer = OneAgentSdk.onesdk_databaserequesttracer_create_sql(dbinfo_handle, stmt)

  OneAgentSdk.onesdk_tracer_start(tracer)

  begin
    # perform the database request, consume results ...
    sleep 0.01 * Random.rand(10)
    raise DatabaseError if Random.rand(10) == 0

    OneAgentSdk.onesdk_databaserequesttracer_set_returned_row_count(tracer, 42 * Random.rand(10))
    OneAgentSdk.onesdk_databaserequesttracer_set_round_trip_count(tracer, 3)
  rescue DatabaseError => err
    OneAgentSdk.onesdk_tracer_error(tracer, err.class.name, err.message)
    # handle or re-raise
  ensure
    OneAgentSdk.onesdk_tracer_end(tracer)
  end
end

def test_database_call
  puts '=== test_database_call ==='

  dbinfo_handle = OneAgentSdk.onesdk_databaseinfo_create(
    'My Postgres DB',
    OneAgentSdk::ONESDK_DATABASE_VENDOR_POSTGRESQL,
    OneAgentSdk::ONESDK_CHANNEL_TYPE_TCP_IP,
    'localhost:12345'
  )

  10.times do |i|
    stmt = "SELECT * FROM foo WHERE bar = #{i};"

    puts "db query '#{stmt}'"
    perform_database_call(stmt, dbinfo_handle)
  end

  OneAgentSdk.onesdk_databaseinfo_delete(dbinfo_handle)
end

def test_webrequest_incoming__db_call__webrequest_outgoing
  puts '=== test_webrequest_incoming__db_call__webrequest_outgoing ==='

  web_application_info_handle = OneAgentSdk.onesdk_webapplicationinfo_create('example.com', 'MyRailsApplication', '/my-rails-app/')
  dbinfo_handle = OneAgentSdk.onesdk_databaseinfo_create(
    'My Postgres DB',
    OneAgentSdk::ONESDK_DATABASE_VENDOR_POSTGRESQL,
    OneAgentSdk::ONESDK_CHANNEL_TYPE_TCP_IP,
    'localhost:12345'
  )

  10.times do |i|
    path = "/my-rails-app/endpoint?param=#{i}"

    puts "incoming web request at '#{path}'"

    incoming_webrequest_tracer = OneAgentSdk.onesdk_incomingwebrequesttracer_create(web_application_info_handle, path, 'GET')

    remote_address = "1.2.3.#{i % 255}:#{(i + 1) % 2**16}"
    request_headers = [['Connection', 'keep-alive'], ['Pragma', 'no-cache']]

    OneAgentSdk.onesdk_incomingwebrequesttracer_set_remote_address(incoming_webrequest_tracer, remote_address)
    request_headers.each do |header|
      OneAgentSdk.onesdk_incomingwebrequesttracer_add_request_header(incoming_webrequest_tracer, header[0], header[1])
    end

    OneAgentSdk.onesdk_tracer_start(incoming_webrequest_tracer)

    begin
      # process incoming web request ...
      sleep 0.01 * Random.rand(10)

      get_url = "http://www.example.com?param=#{i}"
      puts "> outgoing web request to '#{get_url}'"
      perform_webrequest_outgoing(get_url)

      # some more processing
      sleep 0.01 * Random.rand(10)

      3.times do |j|
        stmt = "SELECT * FROM foo WHERE bar = #{i} AND baz = #{j};"
        puts "> db query '#{stmt}'"
        perform_database_call(stmt, dbinfo_handle)
      end

      # some more processing
      sleep 0.01 * Random.rand(10)

      raise WebApplicationError if Random.rand(10) == 0

      OneAgentSdk.onesdk_incomingwebrequesttracer_add_response_header(incoming_webrequest_tracer, 'Transfer-Encoding', 'chunked')
      OneAgentSdk.onesdk_incomingwebrequesttracer_add_response_header(incoming_webrequest_tracer, 'Content-Length', '1234')
      OneAgentSdk.onesdk_incomingwebrequesttracer_set_status_code(incoming_webrequest_tracer, 200)
    rescue WebApplicationError => err
      OneAgentSdk.onesdk_tracer_error(incoming_webrequest_tracer, err.class.name, err.message)
      # handle or re-raise
    ensure
      OneAgentSdk.onesdk_tracer_end(incoming_webrequest_tracer)
    end
  end

  OneAgentSdk.onesdk_webapplicationinfo_delete(web_application_info_handle)
  OneAgentSdk.onesdk_databaseinfo_delete(dbinfo_handle)
end

logging_callback = proc do |msg|
  puts "### OneAgent SDK Logging Callback: <#{msg}>"
end

ret_init = init_oneagent_sdk(logging_callback)

test_webrequest_incoming
test_webrequest_outgoing
test_database_call
test_webrequest_incoming__db_call__webrequest_outgoing
puts 'done.'

sleep 30

shutdown_oneagent_sdk(ret_init)
