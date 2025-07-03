# ![Logo](/media/Logo.png) &nbsp; SFPEG APEX Utilities



## Introduction

This package contains a set of Apex utility classes providing features often missing when
implementing custom logic in Apex.

These components were built as contributions/examples for former & ongoing Advisory assignments by 
[Pierre-Emmanuel Gros](https://github.com/pegros). 

External links towards interesting Apex frameworks are alsdo referenced here.

ℹ️ The current version is a full re-packaging of the previous repository as modular
unlocked packages. The previous version remains available in the v0 branch and will no
longer evolve.


## Package Content

The **PEG_APEX** package provides a set of Apex utility classes, grouped by purpose in separate folders 
(corresponding to distinct unlocked packages).
Detailed informations about these utilities (behaviour, usage, technical details) are available in their 
own help pages.

### [sfpegDebugUtility](/help/sfpegDebugUtility.md)
The **sfpegDebug_UTL** Apex class enables to optimise and homogenize `System.debug()` statements within
Apex code. Its primary objective is to keep all detailed debug statements in the Apex code to support
any investigation on a production Org when necessary, without having too much performance impact coming
from implicit data `toString()` serializations.

### [sfpegQueueableUtility](help/sfpegQueueableUtility.md)
The **sfpegQueueable_UTL** Apex class provides various utilities to manage asynchronous Queueable Apex
processes: Singleton process execution control (e.g. triggered from Apex trigger), aggregated
Queueable execution statistics logging and aggregation.

### [sfpegQueueableUX](help/sfpegQueueableUX.md)
This is an add-on to the **sfpegQueueableUtility** package by extending the **Queueable Log** record 
page with a set of **[PEG_LIST](https://github.com/pegros/PEG_LIST)** actions and related lists to ease
supervision of the Queueable processes.

### [sfpegSharingGroupUtility](help/sfpegSharingGroupUtility.md)
The **sfpegSharingGroup_UTL** Apex class provides a generic Apex logic for Queueable processes to 
manage Public Groups linked to a  hierarchical Structure object to be used for Apex Sharing
(local, upwards or downwards to each Structure record) and manage User Structure assignments.

### [sfpegCampaignUtility](help/sfpegCampaignUtility.md)
The **sfpegCampaign_UTL** Apex utility class (called from Campaign and CampaignMember
Apex triggers) enables to implement some usual business logic missing in standard
Salesforce for Campaign management.


## Technical Details

Each Apex Utility is packaged independently as an [unlocked package](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_unlocked_pkg_whats_a_package.htm). Some are completely standalone (e.g.
[sfpegDebugUtility](/help/sfpegDebugUtility.md)) while others have dependencies
(e.g. [sfpegQueueableUtility](help/sfpegQueueableUtility.md) depends on [sfpegDebugUtility](/help/sfpegDebugUtility.md)
and [sfpegSharingGroupUtility](help/sfpegSharingGroupUtility.md) on [sfpegQueueableUtility](help/sfpegQueueableUtility.md)).

Each package basically contains the Apex utility class(es) as well as some supporting metadata (Apex test class,
custom setting, custom object, permission set...).


## Miscellaneous Useful Links

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

### Tooling Data
* The **[Salesforce Inspector Reloaded](https://chromewebstore.google.com/detail/salesforce-inspector-relo/hpijlohoihegkfehhibggnkbjhoemldh?hl=en)** chrome extension is the ultimate tool to deal with data and metadata from the Salesforce UI.
* The **[SFDX Data Move Utility](https://help.sfdmu.com/)** plugin for the **[Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)** is very useful to seed data within dev sandboxes from a reference Org 
(prodiction, full sandbox...).
