# frozen_string_literal: true

require 'ffi'
# require 'ffi/tools/const_generator'

module OneAgentSDK
  extend FFI::Library

  if FFI::Platform.unix?
    ffi_lib './OneAgent-SDK-for-C/lib/linux-x86_64/libonesdk_shared.so'
  elsif FFI::Platform.windows?
    ffi_lib './OneAgent-SDK-for-C/lib/windows-x86_64/onesdk_shared.dll'
  else
    raise 'undefined platform'
  end

  # Constants = FFI::ConstGenerator.new do |gen|
  #   gen.const :ONESDK_SUCCESS
  #   gen.const :ONESDK_CCSID_ASCII
  # end

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

  # ======================================================================================================
  #    Common
  # ======================================================================================================

  ONESDK_SUCCESS = 0
  ONESDK_CCSID_ASCII = 367

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

  ONESDK_DYNATRACE_HTTP_HEADER_NAME = "X-dynaTrace"

  attach_function :onesdk_initialize, [], :int
  attach_function :onesdk_shutdown, [], :int

  attach_function :onesdk_agent_get_current_state, [], :int
  attach_function :onesdk_agent_get_version_string, [], :string
  attach_function :onesdk_stub_get_version, [Onesdk_string_t], :void

  # attach_function :onesdk_asciistr, [:string], Onesdk_string_t
  def self.onesdk_asciistr(str)
    struct = Onesdk_string_t.new
    struct[:data] = FFI::MemoryPointer.from_string(str)
    struct[:byte_length] = str.length
    struct[:ccsid] = ONESDK_CCSID_ASCII
    struct
  end

  # typedef void ONESDK_CALL onesdk_agent_logging_callback_t(char const* message);
  # ONESDK_DECLARE_FUNCTION(void) onesdk_agent_set_logging_callback(onesdk_agent_logging_callback_t* agent_logging_callback);
  callback :onesdk_agent_logging_callback_t, [:string], :void
  attach_function :onesdk_agent_set_logging_callback, [:onesdk_agent_logging_callback_t], :void

  attach_function :onesdk_tracer_start, [:handle_t], :void
  attach_function :onesdk_tracer_end, [:handle_t], :void

  # ======================================================================================================
  #    Outgoing Web Request Tracing
  # ======================================================================================================

  # onesdk_size_t onesdk_tracer_get_outgoing_dynatrace_string_tag(onesdk_tracer_handle_t tracer_handle, char* buffer, onesdk_size_t buffer_size, onesdk_size_t* required_buffer_size);
  attach_function :onesdk_tracer_get_outgoing_dynatrace_string_tag_internal, :onesdk_tracer_get_outgoing_dynatrace_string_tag, [:handle_t, :pointer, :size_t, :pointer], :size_t
  def self.onesdk_tracer_get_outgoing_dynatrace_string_tag(tracer)
    string_tag_size_p = FFI::MemoryPointer.new(:size_t)
    onesdk_tracer_get_outgoing_dynatrace_string_tag_internal(tracer, FFI::Pointer::NULL, 0, string_tag_size_p)
    string_tag_size = string_tag_size_p.read(:size_t)
    buffer_p = FFI::MemoryPointer.new(:char, string_tag_size)
    onesdk_tracer_get_outgoing_dynatrace_string_tag_internal(tracer, buffer_p, string_tag_size, FFI::Pointer::NULL)
    tag = buffer_p.read_string
  end

  # attach_function :onesdk_outgoingwebrequesttracer_create, [Onesdk_string_t, Onesdk_string_t], :handle_t
  attach_function :onesdk_outgoingwebrequesttracer_create_p, [:pointer, :pointer], :handle_t
  def self.onesdk_outgoingwebrequesttracer_create(url, method)
    onesdk_outgoingwebrequesttracer_create_p(url, method)
  end
  attach_function :onesdk_outgoingwebrequesttracer_set_status_code, [:handle_t, :int], :void
  # attach_function :onesdk_outgoingwebrequesttracer_add_response_header, [:handle_t, Onesdk_string_t, Onesdk_string_t], :void
  attach_function :onesdk_outgoingwebrequesttracer_add_response_headers_p, [:handle_t, :pointer, :pointer, :int], :void
  def self.onesdk_outgoingwebrequesttracer_add_response_header(tracer, name, value)
    onesdk_outgoingwebrequesttracer_add_response_headers_p(tracer, name, value, 1)
  end
  # attach_function :onesdk_outgoingwebrequesttracer_add_request_header, [:handle_t, Onesdk_string_t, Onesdk_string_t], :void
  attach_function :onesdk_outgoingwebrequesttracer_add_request_headers_p, [:handle_t, :pointer, :pointer, :int], :void
  def self.onesdk_outgoingwebrequesttracer_add_request_header(tracer, name, value)
    onesdk_outgoingwebrequesttracer_add_request_headers_p(tracer, name, value, 1)
  end

  # ======================================================================================================
  #    Database Tracing
  # ======================================================================================================

  ONESDK_DATABASE_VENDOR_APACHE_HIVE = "ApacheHive"
  ONESDK_DATABASE_VENDOR_CLOUDSCAPE = "Cloudscape"
  ONESDK_DATABASE_VENDOR_HSQLDB = "HSQLDB"
  ONESDK_DATABASE_VENDOR_PROGRESS = "Progress"
  ONESDK_DATABASE_VENDOR_MAXDB = "MaxDB"
  ONESDK_DATABASE_VENDOR_HANADB = "HanaDB"
  ONESDK_DATABASE_VENDOR_INGRES = "Ingres"
  ONESDK_DATABASE_VENDOR_FIRST_SQL = "FirstSQL"
  ONESDK_DATABASE_VENDOR_ENTERPRISE_DB = "EnterpriseDB"
  ONESDK_DATABASE_VENDOR_CACHE = "Cache"
  ONESDK_DATABASE_VENDOR_ADABAS = "Adabas"
  ONESDK_DATABASE_VENDOR_FIREBIRD = "Firebird"
  ONESDK_DATABASE_VENDOR_DB2 = "DB2"
  ONESDK_DATABASE_VENDOR_DERBY_CLIENT = "Derby Client"
  ONESDK_DATABASE_VENDOR_DERBY_EMBEDDED = "Derby Embedded"
  ONESDK_DATABASE_VENDOR_FILEMAKER = "Filemaker"
  ONESDK_DATABASE_VENDOR_INFORMIX = "Informix"
  ONESDK_DATABASE_VENDOR_INSTANT_DB = "InstantDb"
  ONESDK_DATABASE_VENDOR_INTERBASE = "Interbase"
  ONESDK_DATABASE_VENDOR_MYSQL = "MySQL"
  ONESDK_DATABASE_VENDOR_MARIADB = "MariaDB"
  ONESDK_DATABASE_VENDOR_NETEZZA = "Netezza"
  ONESDK_DATABASE_VENDOR_ORACLE = "Oracle"
  ONESDK_DATABASE_VENDOR_PERVASIVE = "Pervasive"
  ONESDK_DATABASE_VENDOR_POINTBASE = "Pointbase"
  ONESDK_DATABASE_VENDOR_POSTGRESQL = "PostgreSQL"
  ONESDK_DATABASE_VENDOR_SQLSERVER = "SQL Server"
  ONESDK_DATABASE_VENDOR_SQLITE = "sqlite"
  ONESDK_DATABASE_VENDOR_SYBASE = "Sybase"
  ONESDK_DATABASE_VENDOR_TERADATA = "Teradata"
  ONESDK_DATABASE_VENDOR_VERTICA = "Vertica"
  ONESDK_DATABASE_VENDOR_CASSANDRA = "Cassandra"
  ONESDK_DATABASE_VENDOR_H2 = "H2"
  ONESDK_DATABASE_VENDOR_COLDFUSION_IMQ = "ColdFusion IMQ"
  ONESDK_DATABASE_VENDOR_REDSHIFT = "Amazon Redshift"
  ONESDK_DATABASE_VENDOR_COUCHBASE = "Couchbase"

  #ONESDK_DEFINE_INLINE_FUNCTION(onesdk_databaseinfo_handle_t) onesdk_databaseinfo_create(onesdk_string_t name, onesdk_string_t vendor, onesdk_int32_t channel_type, onesdk_string_t channel_endpoint) {
  #ONESDK_DECLARE_FUNCTION(onesdk_databaseinfo_handle_t) onesdk_databaseinfo_create_p(onesdk_string_t const* name, onesdk_string_t const* vendor, onesdk_int32_t channel_type, onesdk_string_t const* channel_endpoint);
  #ONESDK_DECLARE_FUNCTION(onesdk_tracer_handle_t) onesdk_databaserequesttracer_create_sql_p(onesdk_databaseinfo_handle_t databaseinfo_handle, onesdk_string_t const* statement);
  #ONESDK_DECLARE_FUNCTION(void) onesdk_databaseinfo_delete(onesdk_databaseinfo_handle_t databaseinfo_handle);

  attach_function :onesdk_databaseinfo_create_p, [:pointer, :pointer, :int32, :pointer], :handle_t
  def self.onesdk_databaseinfo_create(name, vendor, channel_type, channel_endpoint)
    onesdk_databaseinfo_create_p(
      onesdk_asciistr(name),
      onesdk_asciistr(vendor),
      channel_type,
      onesdk_asciistr(channel_endpoint)
    )
  end
  attach_function :onesdk_databaserequesttracer_create_sql_p, [:handle_t, :pointer], :handle_t
  def self.onesdk_databaserequesttracer_create_sql(databaseinfo_handle, statement)
    onesdk_databaserequesttracer_create_sql_p(databaseinfo_handle, onesdk_asciistr(statement))
  end
  attach_function :onesdk_databaseinfo_delete, [:handle_t], :void

  # attach_function :onesdk_outgoingwebrequesttracer_create, [Onesdk_string_t, Onesdk_string_t], :handle_t
  attach_function :onesdk_outgoingwebrequesttracer_create_p, [:pointer, :pointer], :handle_t
  def self.onesdk_outgoingwebrequesttracer_create(url, method)
    onesdk_outgoingwebrequesttracer_create_p(url, method)
  end

  attach_function :onesdk_databaserequesttracer_set_returned_row_count, [:handle_t, :int32], :void
  attach_function :onesdk_databaserequesttracer_set_round_trip_count, [:handle_t, :int32], :void
end