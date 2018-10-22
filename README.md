# Dynatrace OneAgent SDK Sample Binding for Ruby

> **DISCLAIMER**: This project was developed as part of an innovation / hacker day from Dynatrace R&D. It is not complete, nor supported and only intended as a starting point for those wanting to integrate the OneAgent SDK for C/C++ with Ruby.

This repository provides a partial Ruby binding for the [Dynatrace OneAgent SDK for C](https://github.com/Dynatrace/OneAgent-SDK-for-C) using [FFI](https://github.com/ffi/ffi). The FFI module is defined in `oneagentsdk.rb` and sample code using it can be found in `oneagentsdk_demo.rb`.

Currently the bindings for the following features of the OneAgent SDK are implemented:
* Incoming web request tracing
* Outgoing web request tracing
* SQL database query tracing

An object-oriented wrapper might be desirable when including the FFI module in your Ruby application, as the module's methods mostly resemble the plain C functions provided by the SDK. Please refer to the [OneAgent SDK for C documentation](https://dynatrace.github.io/OneAgent-SDK-for-C/index.html) for usage information.

The sample binding and demo app were tested with MRI/CRuby v2.5.1 and FFI v1.9.25 on Ubuntu 18.04 x64 with OneAgent SDK for C v1.2.0 so far.

## Dependencies

* [Dynatrace OneAgent SDK for C](https://github.com/Dynatrace/OneAgent-SDK-for-C) version 1.2.0 (and above)
  * see [its documentation](https://github.com/Dynatrace/OneAgent-SDK-for-C#compatibility-of-dynatrace-oneagent-sdk-for-cc-releases-with-oneagent-releases) for compatible versions of Dynatrace OneAgent
* [Ruby FFI](https://github.com/ffi/ffi)


## Support
This project is NOT SUPPORTED and is provided "AS IS" by Dynatrace.  
We welcome community work in this project! Extensions and fixes can be provided via pull request, to report issues and/or ask questions please use GitHub issues.

## Further reading

* [What is the OneAgent SDK?](https://www.dynatrace.com/support/help/extend-dynatrace/oneagent-sdk/what-is-oneagent-sdk/) in the Dynatrace documentation
* [Language independent documentation of the SDK's APIs and concepts](https://github.com/Dynatrace/OneAgent-SDK)
* [Blog: Dynatrace OneAgent SDK for C: Service and transaction monitoring for C++ and other native applications](https://www.dynatrace.com/news/blog/dynatrace-oneagent-sdk-c-service-transaction-monitoring-c-native-applications/)
