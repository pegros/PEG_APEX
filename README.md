# ![Logo](/media/Logo.png) &nbsp; SFPEG APEX Utilities

## Introduction

This package contains a set of Apex utility classes providing features often missing when
implementing custom logic in Apex.

These components were built as contributions/examples for former & ongoing Advisory assignments by 
[Pierre-Emmanuel Gros](https://github.com/pegros). 

External links towards interesting Apex frameworks are alsdo referenced here.

## Package Content

This package provides a set of Apex utility classes.
Detailed informations about these classes (behaviour, usage, technical details) are available in their help dedicated pages.

### [sfpegDebugUtility](/help/sfpegDebugUtility.md)
The **sfpegDebug_UTL** Apex class enables to optimise and homogenize `System.debug()` statements within
Apex code. Its primary objective is to keep all detailed debug statements in the Apex code to support
any investigation on a production Org when necessary, without having too much performance impact coming
from implicit data `toString()` serializations.

### [sfpegQueueableUtility](help/sfpegQueueableUtility.md)
The **sfpegQueueable_UTL** Apex class provides various utilities to manage asynchronous Queueable Apex
processes: Singleton process execution control (e.g. triggered from Apex trigger), aggregated
Queueable execution statistics logging and aggregation.

## Interesting Links
### Naming Conventions

* see [Success Cloud Coding Conventions](https://trailhead.salesforce.com/content/learn/modules/success-cloud-coding-conventions) on Trailhead.

### Triggers & Bypass
Various Frameworks are available to structure Trigger logic and ensure logic bypass on demand.
Some interesting solutions are available here:

* [Kevin O'Hara](https://github.com/kevinohara80/sfdc-trigger-framework/blob/master/src/classes/TriggerHandler.cls)
* [Mitch Spano](https://github.com/mitchspano/apex-trigger-actions-framework)
* [PAD by Jean-Luc Antoine](https://jla.ovh/pad)

### Application Logs
Logging some transactions may be required on a permanent basis to monitor the platform (i.e. not for debug),
possibly in addition to standard **Shield Event Monitoring** feature.
Some interesting solutions are available here:
* [Nebula Logger by Jonathan Gillespie](https://github.com/jongpie/NebulaLogger)

## Technical Details

Each Apex Utility is packaged independently and may be deployed on a standalone basis (unless stated othewise).
Each package basically contains the Apex utility class as well as some supporting metadata (Apex test class, custom setting...).