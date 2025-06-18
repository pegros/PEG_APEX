# ![Logo](/media/Logo.png) &nbsp; SFPEG Queueable Utility

## Introduction

The **sfpegQueueableUtility** Apex package provides various utilities to monitor and manage asynchronous Queueable Apex processes.

The core purpose is to track various KPIs when executing queueable Apex classes (such as number of records processed, 
execution wait and processing times) in a scalable way. When completing a Queueable job, these KPIs are registered within
a custom object record, aggregated by timestamp range (every 10 min by default).

Additionally it provides means to implement a singleton approach for queueable job execution, e.g. triggering a queueable 
Apex class from a trigger only if not already running. Adopting such a singleton approach enables to reduce the number of jobs 
enqueued and provide more control on the way queueable logic should be executed (e.g. avoiding parallel execuion on same records,
prioritizing creation handling over updates or deletes...).

At last, it provides a way to easily check whether queueable executions governor limits are almost reached to avoid job queue saturation
and a schedulable logic to relaunch the execution of the relevant queueable singleton processes if needed when more capacity becomes 
available.


## Installation

It may be installed and upgraded as the `sfpegApex-queueable` unlocked package
directly on your Org via the installation link provided in the [release notes](#release-notes).

⚠️ It requires the `[sfpegApex-debug](/help/sfpegDebugUtility.md)` package to be already installed on your Org (as it relies on it for debug logs).

After installation, you need to grant the `sfpegQueueableUsage` permission set to adminstrators in order to
let them access the **Queueable Log** object tab.

ℹ️ This Package may be extended with some UI actions and lists leveraging the [PEG_LIST](https://github.com/pegros/PEG_LIST) package.
Please see `[sfpegApex-queueableUX](/help/sfpegQueueableUX.md)` package.


## Solution Principles

### Aggregated Queueable Execution Logging

The principle for Queueable Job execution logging is to aggregate various queueable execution KPIs
per period of time.
* During a given time window, all executions of a given Apex queueable class 
update the same record before termination/requeueing, incrementing the number of runs,
the wait and execution time, the number of records processed...
* When entering a new time window upon Apex class execution, a new log record is
automatically created. If the class does not run during a period, no log record is created.
* Multiple instances of the same queueable Apex class may run in parallel, all of which updating the
same log record upon completion.

Log data are stored in the `sfpegQueueableLog__c` custom object which may then be viewed via standard
Lightning UX and used in standard reports. Many KPIs are available as well as a detailed message
logging information about each execution within the considered time window.

![sfpegQueueableLog Record View](/media/sfpegQueueableLogView.png)

ℹ️ The `sfpegQueueableUsage` permission set is available to easily get read only access to 
all `sfpegQueueableLog__c` records.

The aggregation is configurable in the `sfpegQueueableSetting__c` custom setting
via its `Logging Window` property.

![sfpegQueueableSetting Configuration](/media/sfpegQueueableLogConfig.png)


Logging is done in the Apex queueable class via the `sfpegQueueableContext_SVC` service class
which provides easy ways to fetch most log data and easily report record processing statuses
(e.g. out of DML execution results). The following points are necessary to properly track wait
and execution times and :
* a private timestamp `creationTS` property should be initialized in the queueable Apex 
constructor to track when the job was enqueued
* a `sfpegQueueableContext_SVC` instance should be initialized at the start of the `execute()`
method of the queueable Apex class to track when the job actually started to execute
* this `sfpegQueueableContext_SVC` instance may then be updated with details about the rows
processed, e.g. via is `analyseResults()`, `registerOK()` or `registerKO()` methods
* before exiting, the `execute()` method should make a call to one of the logging method of the 
`sfpegQueueableContext_SVC` instance to actually update the log record:
    * `logExecution()` for normal logging of an execution (implying that the job is requeued).
    * `logExecutionEnd()` for normal termination of a queueable job chain (e.g. no more record to process)
    * `logExecutionAbort()` for abnormal termination of a queueable job chain (e.g. when asynch job governor limit reached)

***Notes:***
* a private integer `iteration` property may be used to track the number of iterations within a same
queueable job chain. It is initialized at 1 upon initial launch and incremented at each requeueing.
* the string `Message__c` field on the log record is extended each time one of the logging methods
is called, which enables to track a short summary of each job execution.
* the string `LastContext__c` field on the log record may be updated at each job execution to provide
information of the last job context (e.g. timestamp or record Id of the last record processed). This data 
is then easily available when starting a job chain via a call to the `getLastContext()` method of the 
`sfpegQueueable_UTL` class.

⚠️ When dealing with setup objects (such as user groups, permission set assignments, roles...), beware that
logging involves the creation or update of a `sfpegQueueableLog__c` record and this may raise a `Mixed DML`
exception. In such cases, it may be required to requeue the job just to log the result of the
previous execution, as done in the `sfpegGroupManagement_UTL` class of the 
[sfpegSharingGroupUtility](help/sfpegSharingGroupUtility.md) add-on.


### Singleton Queueable Execution

One efficient approach to queueable Apex processes is to enforce a singleton execution pattern, 
i.e. having only one job of a given queueable Apex class running at a given moment. 
* this prevents job queue overflow and enforces better parallelisation of asynch processes
* this provides more control on the order in which business logic should be applied on records
* this reduces the risk of concurrent access to the same records

Typical use case is to trigger an asynchronous process upon record creation / update to 
finalize the records, e.g. because callouts are required or if its logic consumes too
much resources to be executed synchronously in the initial trigger transaction.

The proposed approach consists in:
* registering a boolean `toProcess` field on the Object to process, the value of which
is set to `true` when applicable conditions are met when creating / updating the record
(e.g. within a `before` trigger logic)
* implement a queueable Apex Class with no input parameter to its constructorn and an `execute()`
method fetching a set of records tagged as to be processed (i.e. `toProcess` set to true`) and 
requeuing itself if there are more records to be processed.
* calling the static `checkLaunch()` method of the `sfpegQueueable_UTL` class with the name
of the queueable Apex class from the `after` logic of the trigger, this method enqueuing a 
new queueable job only if none is currently in wait or running state for this class. 

ℹ️ Compared to an Apex batch, this queueable solution enables to dynamically adapt the number of records
actually processed to the actual limits reached when executing the Apex logic (especially when callouts
are involved or when the set of DMLs executed vary depending on the record conditions).


### Queueable Execution Governor Limits Handling

The `sfpegQueueable_UTL` class provides a static `isWithinExecutionRatio()` method to check
the current `DailyAsyncApexExecutions` governor limit and compare it to a configurable
ratio. This enables to automatically prevent consuming job queue capacity when some 
urgent jobs need to be prioritized.

This control is automatically done in the static `checkLaunch()` method of the `sfpegQueueable_UTL`
utility class when triggering a process but it may be done systematically at the end `execute()`
method of the queueable Apex class before requeing itself.

```
if (!sfpegQueueable_UTL.isWithinExecutionRatio()) {
	execContext.logExecutionAbort('STOP: Daily queueable limit reached',null);
	sfpegDebug_UTL.warn('END / Queueable limit reached');
}
```

Execution of the queueable processes resumes automatically upon the next `checkLaunch()` invocations
if the ratio is correct at that moment. This requires this logic to be triggered which may not be 
always the case (e.g. when there  is no activity on the database) and the `sfpegQueueable_SCH`
schedulable apex class may be scheduled to relaunch a selection of queueable Apex class processes if the
`DailyAsyncApexExecutions` governor limit is below another ratio.

The configuration of the ratios and the list of queueable Apex classes is done via the 
the `sfpegQueueableSetting__c` custom setting.

![sfpegQueueableSetting Configuration](/media/sfpegQueueableLogConfig.png)


The schedulable Apex may be directly scheduled from the Apex class setup page.
Alternatively, an Apex command may be used to schedule it with a finer granularity,
e.g. from the _anonymous execution window_ of the _dev console_.
```
String hourlySchedule = '0 0 * * * ?'; 
sfpegQueueable_SCH relaunchJob = new sfpegQueueable_SCH(); 
system.schedule('Hourly Queueable Relaunch', hourlySchedule, relaunchJob);
```

## Implementation Example

A standard implementation of the logging framework in a Queueable Apex class would be:

```
public with sharing class MyQueueable_QUE implements Queueable {

    // STATIC CONSTANTS
    final private static String PROCESS_NAME = 'MyQueueable_QUE';
    final private static Integer RCD_NBR = 10;
    
    // EXECUTION VARIABLES
    private DateTime creationTS;
    private Integer iteration = 1;
    private ID lastRecordId;

    // INITIALIALISATION
    public MyQueueable_QUE() {
        sfpegDebug_UTL.debug('START for initialization');
        this.creationTS = System.Now();
        this.iteration = 1;
        sfpegDebug_UTL.debug('END for initialization at',this.creationTS );
    }

    @TestVisible
    private MyQueueable_QUE(final Integer iteration, final ID lastRecordId) {
        sfpegDebug_UTL.debug('START for iteration ',iteration);
        this.creationTS = System.Now();
        this.iteration = iteration;
        this.lastRecordId = lastRecordId;
        sfpegDebug_UTL.finest('Last record ID provided ',lastRecordId);
        sfpegDebug_UTL.debug('END for iteration at',this.creationTS );
    }

    // EXECUTION LOGIC
    public void execute(QueueableContext context){
        sfpegDebug_UTL.info('START with context',context);
        sfpegDebug_UTL.fine('for iteration',this.iteration);
        sfpegQueueableContext_SVC execContext = new sfpegQueueableContext_SVC(PROCESS_NAME,this.iteration, this.creationTS);

        if (!sfpegQueueable_UTL.isWithinExecutionRatio()) {
			execContext.logExecutionAbort('STOP: Daily queueable limit reached',this.lastRecordId);
			sfpegDebug_UTL.warn('END / Queueable limit reached');
		}
        else if ((doOperationA(execContext)) || (doOperationB(execContext)) || (doOperationC(execContext))) {            
            sfpegDebug_UTL.info('END / Requeuing for further processing');
            if (!Test.isRunningTest()) {
                try {
	                System.enqueueJob( new MyQueueable_QUE(this.iteration + 1,this.lastRecordId));
                }
                catch(Exception e) {
					execContext.logExecutionAbort('STOP: Exception raised ' + e.getMessage(), this.lastRecordId);
                }
            }
        }
        else {
            execContext.logExecutionEnd(this.lastRecordId);
            sfpegDebug_UTL.info('END / No record left to process');
        }
    }
        
    private boolean doOperationA(final sfpegQueueableContext_SVC execContext) {
        sfpegDebug_UTL.debug('START with lastRecordId',this.lastRecordId);

        List<Schema.Location> recordList = [    SELECT ... FROM XXX
                                                WHERE ... AND Id > :this.lastRecordId  
                                                ORDER BY Id ASC LIMIT :RCD_NBR];
        sfpegDebug_UTL.fine('#records fetched',recordList.size());

        if (recordList == null || recordList.size() == 0) {
            sfpegDebug_UTL.debug('END / No record to process');
            return false;
        }

        Map<ID,XXX> records2update = new Map<ID,XXX>();
        ID lastRecordId;
        for (XXX iter : recordList) {
            sfpegDebug_UTL.finest('Processing record ID', iter.Id);
            ...
        }
        sfpegDebug_UTL.finest('All records processed resulting in #changes',records2update.size());
    
        this.lastRecordId = lastRecordId;
        sfpegDebug_UTL.finest('LastRecordId updated', this.lastRecordId);

        Database.SaveResult[] updateResults = Database.update(records2update.values(),false);
        sfpegDebug_UTL.debug('Updates executed with #results',updateResults.size());
 
        execContext.analyseResults(updateResults);
        execContext.logExecution('Operation A',this.lastRecordId);
        
        sfpegDebug_UTL.debug('END / Updates executed');
        return true;
    }

    private boolean doOperationB(final sfpegQueueableContext_SVC execContext) {
        ...
    }

    private boolean doOperationC(final sfpegQueueableContext_SVC execContext) {
        ...
    }
}
```


## Package Content

All the required metadata is available in the **sfpegQueueableUtility** folder, which contains
* the `sfpegQueueable_UTL` utility class and its `sfpegQueueable_TST` test class
* the `sfpegQueueable_SCH` schedulable class and its `sfpegQueueable_SCH_TST` test class
* the `sfpegQueueableContext_SVC` service class and its `sfpegQueueableContext_TST` test class
* the `sfpegQueueableSetting__c` hierarchical custom setting providing some configuration constants
* the `sfpegQueueableLog__c` custom object storing queueable execution statistics, along with its page layout and object tab.
* the `sfpegQueueableUsage` permission set granting access to the `sfpegQueueableLog__c` object (for admins)


## Technical Details

* Queueable Apex classes are instantiated via `Type.forNameforName()` statements. Beware to the class
name provided as input to the `checkLaunch()` method !
* ⚠️ There have been some rare occurences of duplicate launches of the same Apex class in very active 
Orgs. If the implemented `execute()` logic is robust enough, this should not be a real issue and the 
situation should disappear once the job queue terminates.
* From a queueable Apex class, only one new job may be enqueued. Usually it is used to requeue itself
until there is no record to process but you may also choose to start another process at that moment
(e.g. to propagate changes to another object).
* If you test from a developer Org, beware that there is a special behaviour with regards to queueable Apex :
max 5 job iterations are allowed, an exception being raised at the 6th.


## Release Notes

### June 2025 - v1.0
* First version with the new unlocked package structure.
* Minor code refactoring.
* [Issue #1](/issues/1) on daily asynch Apex Org limit addressed
* Install it from [here](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ7000000xH4iIAE).