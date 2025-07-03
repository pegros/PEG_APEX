# ![Logo](/media/Logo.png) &nbsp; SFPEG Queueable UX Extension

## Introduction

The **sfpegQueueableUX** is an extension to the **[sfpegQueueableUtility](help/sfpegQueueableUtility.md)** Apex package.

It bascially provides an enriched **Queueable Log** record page with a set of **[PEG_LIST](https://github.com/pegros/PEG_LIST)**
actions and related lists to ease supervision of the Queueable processes.


## Installation

This extension may be installed and upgraded as the `sfpegApex-queueableUX` unlocked package
directly on your Org via the installation link provided in the [release notes](#release-notes).

⚠️ It requires the **[sfpegApex-queueable](help/sfpegQueueableUtility.md)** and **[sfpegApex-core](https://github.com/pegros/PEG_LIST)**
packages to be already installed on your Org. These two packages come with their own permissions which need to be assigned to the proper users.

⚠️ After package installation, you need to change the default Lightning record page for **Queueable Log** records by activating
the provided `Queueable_Log_Extended_Record_Page` one (e.g. as Org default for desktop and mobile).


## Solution Principles

The Lightning record page for the `sfpegQueueableLog__c` custom object included in the **sfpegQueueableUtility** package
(called `Queueable_Log_Record_Page`) only provides a standalone display of the different fields of each individual record.

The **sfpegQueueableUX** extension package provides an enriched Lightning record page layout for administration and 
supervision purposes (called `Queueable_Log_Extended_Record_Page`). The resulting layout adopts a tab layout with
an additional _Related_ tab displaying various related lists and actions.

![sfpegQueueableLog Record Extended View](/media/sfpegQueueableLogExtendedView.png)


### Recent Queueable Logs

By adding the `SF PEG Custom List` Lightning component to your layout and selecting the `QueueableLog Recent`
metadata record as `Query Configuration` in its setup, the list of the most recent Queueable Log records for
the current queueuable Apex class is displayed. This enables to see the most recent evolution and easily
open the most recent one to get more detailed information.

![sfpegQueueableLog Record Logs](/media/sfpegQueueableRecentLogs.png)


### Recent Asynch Jobs

By adding the `SF PEG Custom List` Lightning component to your layout and selecting the `QueueableLog Latest Jobs`
metadata record as `Query Configuration` in its setup, the list of the most recent indivudal `AsyncApexJob`records corresponding to the current queueuable Apex is displayed. This enables to see the most recent Job evolution and easily
open the most recent one to get more detailed information.

![sfpegQueueableLog Recent Asynch Jobs](/media/sfpegQueueableRecentJobs.png)


### Quick Queueable Actions

By adding the `SF PEG Action Bar` Lightning component to your layout and selecting the `QueueableLog Actions`
metadata record as `Action Configuration` in its setup, two action buttons are automatically displayed and
enable to easily stop / relaunch the queueable Apex process corresponding to the log record.

![sfpegQueueableLog Actions](/media/sfpegQueueableActions.png)


Alternatively, you may include it as `Header Action Configuration` to one of the lists,
such as the _Recent Queueable Logs_ one (as done in the extended layout).

![sfpegQueueableLog Recent Logs with Actions](/media/sfpegQueueableRecentLogsWithActions.png)



## Package Content

The **sfpegQueueableUX** folder contains:
* a set of Apex action classes implementing the `sfpegAction_SVC` virtual class (with their test classes) to 
start / stop queueable jobs from the Lightning UI
* a set of `sfpegList` custom metadata records containing the configuration to list the most recent `sfpegQueueableLog__c` 
and `AsyncApexJobJobs` correponding to the current queueable Apex class.
* a set of `sfpegAction` custom metadata record containing the buttons to trigger the two Apex actions.
* a new Lightning page layout for the `sfpegQueueableLog__c` object including a related tab with the two `sfpegList` lists
and the `sfpegAction` action bar.


## Technical Details

* It relies on the **Core** components of **[PEG_LIST](https://github.com/pegros/PEG_LIST)** package and benefits
from its whole set of customisation and extension capabilities.


## Release Notes

### June 2025 - v1.0
* First version with the new unlocked package structure.
* Lightning record page layout added
* Install it from [here ⬇️](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ7000000xH4sIAE).
