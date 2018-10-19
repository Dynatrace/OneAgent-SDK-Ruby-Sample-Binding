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

require 'ffi'

# ======================================================================================================
#   OneAgentSdk
#   -----------
#   This module provides a Ruby FFI binding for the Dynatrace OneAgent SDK for C
#   Refer to https://github.com/Dynatrace/OneAgent-SDK-for-C for usage and further information
# ======================================================================================================
module OneAgentSdk
  extend FFI::Library

  if FFI::Platform.unix?
    ffi_lib './OneAgent-SDK-for-C/lib/linux-x86_64/libonesdk_shared.so'
  elsif FFI::Platform.windows?
    ffi_lib './OneAgent-SDK-for-C/lib/windows-x86_64/onesdk_shared.dll'
  else
    raise 'undefined platform'
  end

  # ======================================================================================================
  #   Common
  # ======================================================================================================

  # TODO: get these using FFI::ConstGenerator
  ONESDK_SUCCESS = 0
  ONESDK_CCSID_ASCII = 367
  ONESDK_CCSID_UTF8 = 1209

  ONESDK_AGENT_STATE_ACTIVE = 0
  ONESDK_AGENT_STATE_TEMPORARILY_INACTIVE = 1
  ONESDK_AGENT_STATE_PERMANENTLY_INACTIVE = 2
  ONESDK_AGENT_STATE_NOT_INITIALIZED = 3
  ONESDK_AGENT_STATE_ERROR = -1

  def self.description_for_state(state)
    case state
    when ONESDK_AGENT_STATE_ACTIVE               then 'ONESDK_AGENT_STATE_ACTIVE'
    when ONESDK_AGENT_STATE_TEMPORARILY_INACTIVE then 'ONESDK_AGENT_STATE_TEMPORARILY_INACTIVE'
    when ONESDK_AGENT_STATE_PERMANENTLY_INACTIVE then 'ONESDK_AGENT_STATE_PERMANENTLY_INACTIVE'
    when ONESDK_AGENT_STATE_NOT_INITIALIZED      then 'ONESDK_AGENT_STATE_NOT_INITIALIZED'
    when ONESDK_AGENT_STATE_ERROR                then 'ONESDK_AGENT_STATE_ERROR'
    else 'unknown state'
    end
  end

  ONESDK_CHANNEL_TYPE_OTHER               = 0
  ONESDK_CHANNEL_TYPE_TCP_IP              = 1
  ONESDK_CHANNEL_TYPE_UNIX_DOMAIN_SOCKET  = 2
  ONESDK_CHANNEL_TYPE_NAMED_PIPE          = 3
  ONESDK_CHANNEL_TYPE_IN_PROCESS          = 4

  ONESDK_DYNATRACE_HTTP_HEADER_NAME = 'X-dynaTrace'

  typedef :uint64, :handle_t

  class Onesdk_stub_version_t < FFI::Struct
    layout  :major, :uint,
            :minor, :uint,
            :patch, :uint
  end
  class Onesdk_string_t < FFI::Struct
    layout  :data, :pointer,
            :byte_length, :size_t,
            :ccsid, :uint16
  end

  # onesdk_result_t onesdk_initialize(void)
  attach_function :onesdk_initialize, [], :int
  # onesdk_result_t onesdk_shutdown(void)
  attach_function :onesdk_shutdown, [], :int

  # onesdk_int32_t onesdk_agent_get_current_state(void)
  attach_function :onesdk_agent_get_current_state, [], :int
  # onesdk_xchar_t const* onesdk_agent_get_version_string(void)
  attach_function :onesdk_agent_get_version_string, [], :string
  # void onesdk_stub_get_version(onesdk_stub_version_t* out_stub_version)
  attach_function :onesdk_stub_get_version, [:pointer], :void

  def self.onesdk_asciistr(str)
    return nil unless str.encoding.ascii_compatible?
    onesdk_string = Onesdk_string_t.new
    onesdk_string[:data] = FFI::MemoryPointer.from_string(str)
    onesdk_string[:byte_length] = str.bytesize
    onesdk_string[:ccsid] = ONESDK_CCSID_ASCII
    onesdk_string
  end

  def self.onesdk_utf8str(str)
    if str.encoding != Encoding::UTF_8
      begin
        str = str.encode
      rescue EncodingError
        return nil
      end
    end
    onesdk_string = Onesdk_string_t.new
    onesdk_string[:data] = FFI::MemoryPointer.from_string(str)
    onesdk_string[:byte_length] = str.bytesize
    onesdk_string[:ccsid] = ONESDK_CCSID_UTF8
    onesdk_string
  end

  def self.onesdk_str(str)
    if str.encoding == Encoding::ASCII || str.encoding == Encoding::ASCII_8BIT
      onesdk_asciistr(str)
    else
      onesdk_utf8str(str)
    end
  end

  # typedef void ONESDK_CALL onesdk_agent_logging_callback_t(char const* message)
  callback :onesdk_agent_logging_callback_t, [:string], :void
  # void onesdk_agent_set_logging_callback(onesdk_agent_logging_callback_t* agent_logging_callback)
  attach_function :onesdk_agent_set_logging_callback, [:onesdk_agent_logging_callback_t], :void

  # void onesdk_tracer_start (onesdk_tracer_handle_t tracer_handle)
  attach_function :onesdk_tracer_start, [:handle_t], :void
  # void onesdk_tracer_end (onesdk_tracer_handle_t tracer_handle)
  attach_function :onesdk_tracer_end, [:handle_t], :void

  # void onesdk_tracer_error (onesdk_tracer_handle_t tracer_handle, onesdk_string_t error_class, onesdk_string_t error_message)
  attach_function :onesdk_tracer_error_p, [:handle_t, :pointer, :pointer], :void
  def self.onesdk_tracer_error(tracer_handle, error_class, error_message)
    onesdk_tracer_error_p(
      tracer_handle,
      onesdk_str(error_class),
      onesdk_str(error_message)
    )
  end

  # onesdk_size_t onesdk_tracer_get_outgoing_dynatrace_string_tag(onesdk_tracer_handle_t tracer_handle, char* buffer, onesdk_size_t buffer_size, onesdk_size_t* required_buffer_size)
  attach_function :onesdk_tracer_get_outgoing_dynatrace_string_tag_internal, :onesdk_tracer_get_outgoing_dynatrace_string_tag, [:handle_t, :pointer, :size_t, :pointer], :size_t
  def self.onesdk_tracer_get_outgoing_dynatrace_string_tag(tracer_handle)
    string_tag_size_p = FFI::MemoryPointer.new(:size_t)
    onesdk_tracer_get_outgoing_dynatrace_string_tag_internal(tracer_handle, FFI::Pointer::NULL, 0, string_tag_size_p)
    string_tag_size = string_tag_size_p.read(:size_t)
    buffer_p = FFI::MemoryPointer.new(:char, string_tag_size)
    onesdk_tracer_get_outgoing_dynatrace_string_tag_internal(tracer_handle, buffer_p, string_tag_size, FFI::Pointer::NULL)
    tag = buffer_p.read_string
    tag
  end

  # void onesdk_tracer_set_incoming_dynatrace_string_tag (onesdk_tracer_handle_t tracer_handle, onesdk_string_t string_tag)
  attach_function :onesdk_tracer_set_incoming_dynatrace_string_tag_p, [:handle_t, :pointer], :void
  def self.onesdk_tracer_set_incoming_dynatrace_string_tag(tracer_handle, string_tag)
    onesdk_tracer_set_incoming_dynatrace_string_tag_p(
      tracer_handle,
      onesdk_str(string_tag)
    )
  end

  # ======================================================================================================
  #   Incoming Web Request Tracing
  # ======================================================================================================

  # onesdk_webapplicationinfo_handle_t onesdk_webapplicationinfo_create (onesdk_string_t web_server_name, onesdk_string_t application_id, onesdk_string_t context_root)
  attach_function :onesdk_webapplicationinfo_create_p, [:pointer, :pointer, :pointer], :handle_t
  def self.onesdk_webapplicationinfo_create(web_server_name, application_id, context_root)
    onesdk_webapplicationinfo_create_p(
      onesdk_str(web_server_name),
      onesdk_str(application_id),
      onesdk_str(context_root)
    )
  end

  # void onesdk_webapplicationinfo_delete (onesdk_databaseinfo_handle_t databaseinfo_handle)
  attach_function :onesdk_webapplicationinfo_delete, [:handle_t], :void

  # onesdk_tracer_handle_t onesdk_incomingwebrequesttracer_create (onesdk_webapplicationinfo_handle_t webapplicationinfo_handle, onesdk_string_t url, onesdk_string_t method)
  attach_function :onesdk_incomingwebrequesttracer_create_p, [:handle_t, :pointer, :pointer], :handle_t
  def self.onesdk_incomingwebrequesttracer_create(webapplicationinfo_handle, url, method)
    onesdk_incomingwebrequesttracer_create_p(
      webapplicationinfo_handle,
      onesdk_str(url),
      onesdk_str(method)
    )
  end

  # void onesdk_incomingwebrequesttracer_set_remote_address (onesdk_tracer_handle_t tracer_handle, onesdk_string_t remote_address)
  attach_function :onesdk_incomingwebrequesttracer_set_remote_address_p, [:handle_t, :pointer], :void
  def self.onesdk_incomingwebrequesttracer_set_remote_address(tracer_handle, remote_address)
    onesdk_incomingwebrequesttracer_set_remote_address_p(
      tracer_handle,
      onesdk_str(remote_address)
    )
  end

  # void onesdk_incomingwebrequesttracer_add_request_header (onesdk_tracer_handle_t tracer_handle, onesdk_string_t name, onesdk_string_t value)
  attach_function :onesdk_incomingwebrequesttracer_add_request_headers_p, [:handle_t, :pointer, :pointer, :int], :void
  def self.onesdk_incomingwebrequesttracer_add_request_header(tracer_handle, name, value)
    onesdk_incomingwebrequesttracer_add_request_headers_p(
      tracer_handle,
      onesdk_str(name),
      onesdk_str(value),
      1
    )
  end

  # void onesdk_incomingwebrequesttracer_add_parameter (onesdk_tracer_handle_t tracer_handle, onesdk_string_t name, onesdk_string_t value)
  attach_function :onesdk_incomingwebrequesttracer_add_parameters_p, [:handle_t, :pointer, :pointer, :int], :void
  def self.onesdk_incomingwebrequesttracer_add_parameter(tracer_handle, name, value)
    onesdk_incomingwebrequesttracer_add_parameters_p(
      tracer_handle,
      onesdk_str(name),
      onesdk_str(value),
      1
    )
  end

  # void onesdk_incomingwebrequesttracer_add_response_header (onesdk_tracer_handle_t tracer_handle, onesdk_string_t name, onesdk_string_t value)
  attach_function :onesdk_incomingwebrequesttracer_add_response_headers_p, [:handle_t, :pointer, :pointer, :int], :void
  def self.onesdk_incomingwebrequesttracer_add_response_header(tracer_handle, name, value)
    onesdk_incomingwebrequesttracer_add_response_headers_p(
      tracer_handle,
      onesdk_str(name),
      onesdk_str(value),
      1
    )
  end

  # void onesdk_incomingwebrequesttracer_set_status_code (onesdk_tracer_handle_t tracer_handle, onesdk_int32_t status_code)
  attach_function :onesdk_incomingwebrequesttracer_set_status_code, [:handle_t, :int], :void

  # ======================================================================================================
  #   Outgoing Web Request Tracing
  # ======================================================================================================

  # void onesdk_outgoingwebrequesttracer_create (onesdk_string_t url, onesdk_string_t method)
  attach_function :onesdk_outgoingwebrequesttracer_create_p, [:pointer, :pointer], :handle_t
  def self.onesdk_outgoingwebrequesttracer_create(url, method)
    onesdk_outgoingwebrequesttracer_create_p(
      onesdk_str(url),
      onesdk_str(method)
    )
  end

  # void onesdk_outgoingwebrequesttracer_add_request_header (onesdk_tracer_handle_t tracer_handle, onesdk_string_t name, onesdk_string_t value)
  attach_function :onesdk_outgoingwebrequesttracer_add_request_headers_p, [:handle_t, :pointer, :pointer, :int], :void
  def self.onesdk_outgoingwebrequesttracer_add_request_header(tracer_handle, name, value)
    onesdk_outgoingwebrequesttracer_add_request_headers_p(
      tracer_handle,
      onesdk_str(name),
      onesdk_str(value),
      1
    )
  end

  # void onesdk_outgoingwebrequesttracer_set_status_code (onesdk_tracer_handle_t tracer_handle, onesdk_int32_t status_code)
  attach_function :onesdk_outgoingwebrequesttracer_set_status_code, [:handle_t, :int], :void

  # void onesdk_outgoingwebrequesttracer_add_response_header (onesdk_tracer_handle_t tracer_handle, onesdk_string_t name, onesdk_string_t value)
  attach_function :onesdk_outgoingwebrequesttracer_add_response_headers_p, [:handle_t, :pointer, :pointer, :int], :void
  def self.onesdk_outgoingwebrequesttracer_add_response_header(tracer_handle, name, value)
    onesdk_outgoingwebrequesttracer_add_response_headers_p(
      tracer_handle,
      onesdk_str(name),
      onesdk_str(value),
      1
    )
  end

  # ======================================================================================================
  #   Database Tracing
  # ======================================================================================================

  ONESDK_DATABASE_VENDOR_APACHE_HIVE = 'ApacheHive'
  ONESDK_DATABASE_VENDOR_CLOUDSCAPE = 'Cloudscape'
  ONESDK_DATABASE_VENDOR_HSQLDB = 'HSQLDB'
  ONESDK_DATABASE_VENDOR_PROGRESS = 'Progress'
  ONESDK_DATABASE_VENDOR_MAXDB = 'MaxDB'
  ONESDK_DATABASE_VENDOR_HANADB = 'HanaDB'
  ONESDK_DATABASE_VENDOR_INGRES = 'Ingres'
  ONESDK_DATABASE_VENDOR_FIRST_SQL = 'FirstSQL'
  ONESDK_DATABASE_VENDOR_ENTERPRISE_DB = 'EnterpriseDB'
  ONESDK_DATABASE_VENDOR_CACHE = 'Cache'
  ONESDK_DATABASE_VENDOR_ADABAS = 'Adabas'
  ONESDK_DATABASE_VENDOR_FIREBIRD = 'Firebird'
  ONESDK_DATABASE_VENDOR_DB2 = 'DB2'
  ONESDK_DATABASE_VENDOR_DERBY_CLIENT = 'Derby Client'
  ONESDK_DATABASE_VENDOR_DERBY_EMBEDDED = 'Derby Embedded'
  ONESDK_DATABASE_VENDOR_FILEMAKER = 'Filemaker'
  ONESDK_DATABASE_VENDOR_INFORMIX = 'Informix'
  ONESDK_DATABASE_VENDOR_INSTANT_DB = 'InstantDb'
  ONESDK_DATABASE_VENDOR_INTERBASE = 'Interbase'
  ONESDK_DATABASE_VENDOR_MYSQL = 'MySQL'
  ONESDK_DATABASE_VENDOR_MARIADB = 'MariaDB'
  ONESDK_DATABASE_VENDOR_NETEZZA = 'Netezza'
  ONESDK_DATABASE_VENDOR_ORACLE = 'Oracle'
  ONESDK_DATABASE_VENDOR_PERVASIVE = 'Pervasive'
  ONESDK_DATABASE_VENDOR_POINTBASE = 'Pointbase'
  ONESDK_DATABASE_VENDOR_POSTGRESQL = 'PostgreSQL'
  ONESDK_DATABASE_VENDOR_SQLSERVER = 'SQL Server'
  ONESDK_DATABASE_VENDOR_SQLITE = 'sqlite'
  ONESDK_DATABASE_VENDOR_SYBASE = 'Sybase'
  ONESDK_DATABASE_VENDOR_TERADATA = 'Teradata'
  ONESDK_DATABASE_VENDOR_VERTICA = 'Vertica'
  ONESDK_DATABASE_VENDOR_CASSANDRA = 'Cassandra'
  ONESDK_DATABASE_VENDOR_H2 = 'H2'
  ONESDK_DATABASE_VENDOR_COLDFUSION_IMQ = 'ColdFusion IMQ'
  ONESDK_DATABASE_VENDOR_REDSHIFT = 'Amazon Redshift'
  ONESDK_DATABASE_VENDOR_COUCHBASE = 'Couchbase'

  # onesdk_databaseinfo_handle_t onesdk_databaseinfo_create (onesdk_string_t name, onesdk_string_t vendor, onesdk_int32_t channel_type, onesdk_string_t channel_endpoint)
  attach_function :onesdk_databaseinfo_create_p, [:pointer, :pointer, :int32, :pointer], :handle_t
  def self.onesdk_databaseinfo_create(name, vendor, channel_type, channel_endpoint)
    onesdk_databaseinfo_create_p(
      onesdk_str(name),
      onesdk_str(vendor),
      channel_type,
      onesdk_str(channel_endpoint)
    )
  end

  # void onesdk_databaseinfo_delete(onesdk_databaseinfo_handle_t databaseinfo_handle)
  attach_function :onesdk_databaseinfo_delete, [:handle_t], :void

  # onesdk_tracer_handle_t onesdk_databaserequesttracer_create_sql_p(onesdk_databaseinfo_handle_t databaseinfo_handle, onesdk_string_t const* statement)
  attach_function :onesdk_databaserequesttracer_create_sql_p, [:handle_t, :pointer], :handle_t
  def self.onesdk_databaserequesttracer_create_sql(databaseinfo_handle, statement)
    onesdk_databaserequesttracer_create_sql_p(
      databaseinfo_handle,
      onesdk_str(statement)
    )
  end

  # void onesdk_databaserequesttracer_set_returned_row_count (onesdk_tracer_handle_t tracer_handle, onesdk_int32_t returned_row_count)
  attach_function :onesdk_databaserequesttracer_set_returned_row_count, [:handle_t, :int32], :void

  # void onesdk_databaserequesttracer_set_round_trip_count (onesdk_tracer_handle_t tracer_handle, onesdk_int32_t round_trip_count)
  attach_function :onesdk_databaserequesttracer_set_round_trip_count, [:handle_t, :int32], :void
end
