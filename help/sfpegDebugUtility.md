
# ![Logo](/media/Logo.png) &nbsp; SFPEG Debug Utility

## Introduction

The **sfpegDebug_UTL** Apex utility class enables to optimise and homogenize
`System.debug()` statements within Apex code.

Its primary objective is to keep a large number of detailed debug statements in the Apex code to
support any investigation on a production Org when necessary, while avoiding too much
performance impact, e.g. coming from implicit data `toString()` serializations.


## Installation

It may be installed and upgraded as the `sfpegApex-debug` unlocked package directly
on your Org via the installation link provided in the [release notes](#release-notes).


## Solution Principles

### Debug Performance Optimisation

`System.debug()` statements may have great performance impact on Apex code even if debug logs
are deactivated on the User via Salesforce standard mechanisms. This comes among others from the 
string concatenations and implicit Object `toString()` serializations executed before evaluating
the actual logging level of the User, e.g. as in:

```System.debug(LoggingLevel.FINE,'Account created --> ' + newAccount);```

The strategy is therefore to avoid these implicit serializations by passing the parameter as a
separate input to the `sfpegDebug_UTL` logging method, testing the current User logging level
before generating the actual  `System.debug()` statements and the parameter serializations.
The same log statement would then look as follows:

```sfpegDebug_UTL.fine('Account created',newAccount);```

As the standard User current debug level is not accessible from Apex, the **sfpegDebugSetting**
hierarchical custom setting has been defined with a **maximum debug level** parameter leveraged 
by the utility class before generating the actual `System.debug()` statement.

⚠️ This **maximum debug level** parameter is a first filter, the standard debug levels being then
applied afterwards by the platform when processing the `System.debug()` statement.


### Debug Log Homogenization

When multiple logs are generated, it is not often easy to find which piece of code has
generated it. It often relies on the Apex developer to provide information about the 
origin class and method, each developer often having also its own way to format debug logs.

The proposed approach is to standardise all debug logs in the following way:

```className | methodName | text message | additional info (optional)```

Class and method names are automatically added by the utility class and the developer
only needs to focus on the core message and optional parameter.


### Debug Level Management

Standard `System.debug` statement enable developers to set a debug level as first 
parameter, leveraging the `LoggingLevel` enum. This requires the developer to type
in additional debug information and this results in having a vast majority of
debug statements done at the default `LoggingLevel.DEBUG` level.

In order to ease work for developers, separate logging statements are proposed 
for each level (in a similar way to the Javascript `console.log` statements):
* `sfpegDebug_UTL.error()` to generate a log at `LoggingLevel.ERROR` level
* `sfpegDebug_UTL.warn()` to do it at `LoggingLevel.WARN` level
* ...
* `sfpegDebug_UTL.finest()` at the lowest level

ℹ️ All statements exist in 2 variants, i.e. with and without additional information
provided. E.g.
* `sfpegDebug_UTL.debug('simple text message')` (without)
* `sfpegDebug_UTL.debug('message with additional information', additionalInfoObject)` (with)


## Usage

### Apex Debug Statements

Logging statements may be done by simply replacing standard `System.debug()` statements
by `sfpegDebug_UTL.error()`, `sfpegDebug_UTL.warn()`... statements depending on the target
logging level.

![sfpegDebug_UTL Usage](/media/sfpegDebugUtilityUsage.png)

**⚠️ Good practices**:
* go down at least one level when entering a `for()` loop (e.g. from `debug()` to `fine()`).
* use a low level log statement (`finer()` or `finest()`) when providing a large additional
information object (e.g. a list of records)
* never concatenate strings in the text message parameter and use 2 log statements when
needing to provide more than one additional information


### Apex Debug Activation

To activate debug logs for a User, configuration must be done at 2 levels:
* in the standard Setup `Debug Logs`page to activate the proper User Trace Flags
* in the specific `sfpegDebugSetting` custom setting to set the maximum debug
level applicable to the user (either user specific or at Profile or
global Org levels)

![sfpegDebugSetting Configuration](/media/sfpegDebugUtilityConfig.png)

The `Max Debug Level`set on the custom setting corresponds to the rank of the last
logged level (in a severity decreasing order):
* `0` means no log (default value)
* `1` for `LoggingLevel.ERROR` level logs only
* `2` for `LoggingLevel.ERROR` and `LoggingLevel.WARN` level logs
* `3` for `LoggingLevel.ERROR`, `LoggingLevel.WARN` and `LoggingLevel.INFO` level logs
* `4` for `LoggingLevel.ERROR` down to `LoggingLevel.DEBUG` level logs
* ...
* `7` for all level logs

**⚠️ Beware** to set the proper levels for your Org/Profile/User in the `sfpegDebugSetting__c`
hierarchical custom setting. Otherwise, no log will be generated!


### Debug Log Output

Hereafter is an example of logs generated by the **sfpegDebug_UTL** statements.

![sfpegDebug_UTL Logs](/media/sfpegDebugUtilityOutput.png)

_Notes_:
* Originating classes and methods are provided just after the logging level.
* All log constituants are separated by a same `|`  character in order to ease any 
post processing via scripts.


## Package Content

All the required metadata is available in the **sfpegDebugUtility** folder, which contains
* the `sfpegDebug_UTL` utility class
* its `sfpegDebug_UTL_TST` test class
* the configuration `sfpegDebugSetting__c` hierarchical custom setting controlling the
actual maximum logging level authorized.


## Technical Details

* Class and method names are retrieved via dummy `StringException` instantiation
* In the **sfpegDebugSetting** custom setting, the `Max Debug Level` property is an Integer
as picklist values are not available in such metadata. 
* Class and method name are fetched by the `sfpegDebug_UTL` utility by triggering and
catching a dummy string exception. These exceptions appear in the technical log details
but not at the user debug log level.
* ⚠️ **Beware** that standard Apex debug logs may not all be logged when executed from a test class.
This is not a problem related to this utility class.


## Release Notes

### June 2025 - v1.0
* First version with the new unlocked package structure.
* Minor code refactoring.
* Install it from [here ⬇️](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ7000000xH4dIAE).