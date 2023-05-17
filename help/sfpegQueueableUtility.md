# ![Logo](/media/Logo.png) &nbsp; SFPEG Queueable Utility

🚧 Documentation is Work in Progress...

## Introduction

The **sfpegQueueable_UTL** Apex class provides various utilities to manage asynchronous Queueable Apex
processes: Singleton process execution control (e.g. triggered from Apex trigger), aggregated
Queueable execution statistics logging and aggregation.



## Solution Principles

🚧 To be continued...


## Package Content

All the required metadata is available in the **sfpegQueueUtility** folder, which contains
* the `sfpegQueueable_UTL` utility class
* its `sfpegQueueable_UTL_TST` test class
* the `sfpegQueueableSetting__c` hierarchical custom setting providing some configuration constants
* the `sfpegQueueableLog__c` custom object storing queueable execution statistics

⚠️ It requires the [sfpegDebugUtility](/help/sfpegDebugUtility.md) to be deployed (part of the same **PEG_APEX** package),
as it relies on its features for debug logs.


## Technical Details

🚧 To be continued...