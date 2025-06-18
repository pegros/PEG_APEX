# ![Logo](/media/Logo.png) &nbsp; SFPEG Sharing Group Utility


## Introduction

The **sfpegSharingGroup_UTL** Apex class provides a generic Apex logic for singleton Queueable
processes to manage Public Groups matching a hierarchical Structure object and a related User
Structure assignment object.

Typical use case for such Public Groups is custom Apex Sharing to provide the ability
to share a business record related to a hierarchical Structure record with:
* all users member of the (local) Structure
* all users member of the (local) structure or any above (upwards sharing)
* all users member of the (local) structure or any below (downwards sharing)

Different groups may be used simultaneously for a record, e.g. to share in
* Read-Write with local Group members (for management)
* Read-Only with Upwards Group members (for reporting)
* Read-Only with Downwards Group members (for communication)

This is a kind of generalization of standard Salesforce Roles (which rely implicitly
on an upwards hierarchy of User Groups), enabling a User to be part of multiple 
instead of a single hierarchy.

Management of upwards and downwards groups are optional, e.g. to cope with Group volume 
limitations as indicated [here](https://help.salesforce.com/s/articleView?id=platform.user_groups_considerations.htm).

This package also provides a way to periodically control and correct the configuration 
of the Groups and Group members.

Both provisioning and control processes rely of a set of fields on the Structure and User Membership
objects to identify and track the records processed / to be processed.


## Installation

It may be installed and upgraded as the `sfpegApex-sharingGroups` unlocked package
directly on your Org via the installation link provided in the [release notes](#release-notes).

⚠️ It requires the `[sfpegApex-queueable](/help/sfpegQueueableUtility.md)` package to be
already installed on your Org (as it relies on it for singleton queueable execution and logging).


## Solution Principles

### Singleton Queueable Apex Invocation

As a baseline, the **sfpegGroupManagement_UTL** class should be
* used within a singleton Queueable implementation (see **[sfpegQueueableUtility](/help/sfpegQueueableUtility.md)**)
* instantiated when creation the first queueable Apex instance
* passed as-is to later queueable instance via dedicated creators
* used to execute the logic in the queueable `execute()`logic

Typical Queueable Apex implementation would be :
```
public with sharing class Structure_QUE implements Queueable {

    @TestVisible private sfpegGroupManagement_UTL  queueUtil;

    /**
    * @description	Public constructor used to launch the Queueable process
    **/
    public Structure_QUE() {
        sfpegDebug_UTL.debug('START standard init');
        sfpegGroupManagement_UTL.GlobalConfiguration config = getConfiguration();
        sfpegDebug_UTL.fine('Configuration initialized',config);
        this.queueUtil = new sfpegGroupManagement_UTL(config);
        sfpegDebug_UTL.fine('Queue utility set',this.queueUtil);
        sfpegDebug_UTL.debug('END standard init');
    }

    /***
    * @description	Private constructor used to continue the Queueable process.
    ***/
    @TestVisible
    private Structure_QUE(sfpegGroupManagement_UTL newUtil) {
        sfpegDebug_UTL.debug('START requeue init');
        this.queueUtil = newUtil;
        sfpegDebug_UTL.fine('New group management utility registered');
        sfpegDebug_UTL.debug('END requeue init');
    }

    /***
    * @description  Main execute method of the Queuable process.
    ***/
    public void execute(QueueableContext context){
        sfpegDebug_UTL.info('START with context',context);
        sfpegDebug_UTL.fine('Configuration parameters fetched',this.queueUtil);
        sfpegGroupManagement_UTL nextProcess = this.queueUtil.execute();
        if (nextProcess != null) {
            sfpegDebug_UTL.info('END / Requeueing the process');
            if (!Test.isRunningTest()) {System.enqueueJob(new Population_QUE(nextProcess));}
            else {this.queueUtil = nextProcess;}
        }
        else {sfpegDebug_UTL.info('END / Processing complete');}
    }

    /***
    * @description  Method providing the default configuration to be used in the Queueable process.
    ***/
    public static sfpegGroupManagement_UTL.GlobalConfiguration getConfiguration() {
        sfpegDebug_UTL.debug('START');
        sfpegGroupManagement_UTL.GlobalConfiguration config = new sfpegGroupManagement_UTL.GlobalConfiguration();
        ... // Initialization of the Sharing Group Configuration, see below.
        sfpegDebug_UTL.debug('END');
        return config;
    }
}
```


### Sharing Group Configuration

The configuration relies on two Apex classes to provide details about the Salesforce objects and fields used for 
hierarchy and user group memberships.

Both Apex classes are defined within the **sfpegGroupManagement_UTL** main classes:
* ***GlobalConfiguration*** to manage main configuration parameters of the Group Management process
    * `className`:  Name of the queueable process (dependent on configuration provided) for logs
    * `maxCreate`: Max. number of records processed at each iteration (when creating public groups), 200 by default.
    * `maxUpdate`: Max. number of records processed at each iteration (when updating public group memberships), 50 by default.
    * `maxDelete`: Max. number of records processed at each iteration (when deleting public groups), 200 by default.
    * `structObject`: Hierarchical Structure Object API Name
    * `structKey`: API Name of the Structure External ID Field used for Public Group Naming
    * `structStatus`: API Name of the Structure Boolean field indicating the Structures to process 
    * `structTS`: API Name of the Structure DateTime field storing the last evaluation for a Structure
    * `structMsg`: API Name of the Structure String field storing some info about the last evaluation for a Structure
    * `useRT`: Boolean flag to use Structure RecordType Names in Public Group Names, false by default.
    * `structParent`: API Name of the Structure Relation to access Data of the Parent Structure
    * `structParentId`: API Name of the Structure lookup Field containing the ID of the Parent Structure
    * `structChildren`: API Name of the Structure Relation to access Data of the Children Structures
    * `groupConfigs`: Map of individual Group management configurations (see below)
* ***GroupConfiguration*** to manage configuration parameters of each Group set/hierarchy processed
    * `prefix`: Prefix used for Public Group Names of this group set/hierarchy
    * `suffix`: Suffix used for Public Group Names of this group set/hierarchy
    * `structLocal`: API Name of the Structure String field storing the Local Public Group ID
    * `localSuffix`: Suffix used for Local Public Group Names of this group set/hierarchy, default being `_L`
    * `structMbrIDs`: List of API Names of Structure fields storing member IDs (Group or User) for Local Group Membership
    * `mbrObject`: Member Object API Name for Local Group Membership
    * `mbrActive`: API Name of the Member Boolean field indicating if the Member record is active 
    * `mbrStruct`: API Name of the Member lookup field identifying the related Structure
    * `mbrIDs`: List of API Names of Member fields storing member IDs (Group or User) for Local Group Membership
    * `structUp`: API Name of the Structure String field (optional) storing the Upwards Public Group ID
    * `upSuffix`: Suffix used for Upwards Public Group Names of this group set/hierarchy, default being `_U`
    * `structDown`: API Name of the Structure String field (optional) storing the Downwards Public Group ID
    * `downSuffix`: Suffix used for Downwards Public Group Names of this group set/hierarchy, default being `_D`


This can be typically initialized via the `getConfiguration()` method mentioned earlier. 
Example hereafter configures two hierarchies based on the same `Structure__c` custom object
with user assignments based on a custom `UserAssignment__c` custom object used for both
standard and management user memberships.
```
public static sfpegGroupManagement_UTL.GlobalConfiguration getConfiguration() {
    sfpegDebug_UTL.debug('START');
    
    // Main Configuration
    sfpegGroupManagement_UTL.GlobalConfiguration config = new sfpegGroupManagement_UTL.GlobalConfiguration();
    config.className        = 'StructureGroup_QUE';
    config.maxCreate        = (Integer) (Structure_CST.SETTINGS.GroupCreationSize__c ?? 100);
    config.maxUpdate        = (Integer) (Structure_CST.SETTINGS.GroupUpdateSize__c ?? 25);
    config.maxDelete        = (Integer) (Structure_CST.SETTINGS.GroupDeletionSize__c ?? 10);
    config.structObject     = 'Location';
    config.structKey	    = 'IdFonctionnel__c';
    config.structStatus	    = 'doGroupEval__c';
    config.structTS 		= 'LastGroupEvalTS__c';
    config.structMsg 		= 'LastGroupEvalMsg__c';
    config.useRT            = true;
    config.structParent     = 'ParentLocation';
    config.structParentId   = 'ParentLocationId';
    config.structChildren   = 'ChildLocations';
    config.groupConfigs     = new Map<String,sfpegGroupManagement_UTL.GroupConfiguration>();
    sfpegDebug_UTL.fine('Main configuration init',config);

    // Main Groups configuration
    sfpegGroupManagement_UTL.GroupConfiguration userGroup = new sfpegGroupManagement_UTL.GroupConfiguration();
    config.groupConfigs.put('USR',userGroup);
    userGroup.suffix       = 'USR';
    userGroup.structLocal  = 'localGroupId__c';
    userGroup.mbrObject    = 'UserAssignment__c';
    userGroup.mbrActive    = 'isActive__c';
    userGroup.mbrStruct    = 'Structure__c';
    userGroup.mbrIDs       = new List<String>{'User__c'};
    sfpegDebug_UTL.fine('Standard User Group configuration init',userGroup);
        
    // Management Groups configuration
    sfpegGroupManagement_UTL.GroupConfiguration mgtGroup = new sfpegGroupManagement_UTL.GroupConfiguration();
    config.groupConfigs.put('MGT',mgtGroup);
    mgtGroup.suffix         = 'MGT';
    mgtGroup.structLocal    = 'localMgtGroupIdl__c';
    mgtGroup.mbrObject      = 'UserAssignment__c';
    mgtGroup.mbrActive      = 'isActiveMgt__c';
    mgtGroup.mbrStruct      = 'Structure__c';
    mgtGroup.mbrIDs         = new List<String>{'User__c'};
    sfpegDebug_UTL.fine('Management Group configuration init',mgtGroup);

    sfpegDebug_UTL.debug('END');
    return config;
}
```

⚠️ By implementing this method as `public`, this configuration may be reused for
control purposes via a similar singleton queueable process using the
**sfpegGroupControl_UTL** Apex class (see further below).


### Queueable Process Launch

The singleton queueable logic is typically launched from the triggers on
both the Structure and User Membership objects.
* when the structure is created or deleted, it should update its status
field and relaunch the queueable process via a standard `sfpegQueueable_UTL.checkLaunch(()`
statement
* when a User Membership is added / deleted or has its status updated,
the status of the related Structure should be updated, which itselfs should
also trigger the same queueable process.


### Group Control

The Group configuration data may be periodically audited and fixed via the
**sfpegGroupControl_UTL** Apex class.

This can be achieved by:
* implementing an audit singleton Apex queueable class executing the **sfpegGroupControl_UTL**
control logic with the same structure hierarchy & user membership configuration
* implementing a schedulable Apex to launch it, and scheduling it to run periodically.

Typical example of the schedulable Apex is provided hereafter.
```
public with sharing class StructureControl_SCH implements Schedulable {

    public void execute(SchedulableContext context) {
        sfpegDebug_UTL.debug('START');
        sfpegQueueable_UTL.checkLaunch('StructureControl_QUE');
        sfpegDebug_UTL.debug('END');
    }

    public static void schedule() { 
        sfpegDebug_UTL.debug('START');
        String cronExpression = '0 0 0 * * ? *'; //Daily
        System.schedule('StructureControl_SCH', cronExpression, new StructureControl_SCH());
        sfpegDebug_UTL.debug('END');
    }
}
```

The configuration of the Group Control processs relies on the configuration of the main
provisioning process as well as a **sfpegGroupControl_UTL.ControlConfiguration** complement
containing the following properties:
* `className`: Name of the queueable process (dependent on configuration provided), for logs
* `controlScope`: Custom WHERE clause to add to standard SOQL template to select structures to control (all controlled by default)
* `statusOK`: API Name of the Boolean status field on the Structure object
* `statusDetails`: API Name of the Text field on the Structure object to provide details about the issues
* `statusDate`: API Name of the Timestamp field to track the last status review. 
* `maxIDs`: Max number of Structure objects analysed at each queueable iteration, with default value of 100.

Typical example of the Control Queueable class is provided hereafter.
```
public with sharing class StructureGroupControl_QUE implements Queueable {

    @TestVisible private sfpegGroupControl_UTL  queueUtil;

    /**
    * @description	Standard public constructor used to launch the Queueable process.
    */
    public StructureGroupControl_QUE() {
        sfpegDebug_UTL.debug('START standard init');

        sfpegGroupManagement_UTL.GlobalConfiguration sharingConfig = Structure_QUE.getConfiguration();
        sfpegDebug_UTL.fine('sharingConfig fetched',sharingConfig);

        sfpegGroupControl_UTL.ControlConfiguration controlConfig = getConfiguration();
        sfpegDebug_UTL.fine('controlConfig fetched',controlConfig);

        this.queueUtil = new sfpegGroupControl_UTL(sharingConfig,controlConfig);
        sfpegDebug_UTL.fine('Queue utility initialized',this.queueUtil);

        sfpegDebug_UTL.debug('END standard init');
    }

    /***
    * @description	Special private constructor used to continue the Queueable process (for requeueing)
    ***/
    @TestVisible
    private StructureGroupControl_QUE(sfpegGroupControl_UTL newUtil) {
        sfpegDebug_UTL.debug('START requeue init');

        this.queueUtil = newUtil;
        sfpegDebug_UTL.fine('New generic utility processor registered');

        sfpegDebug_UTL.debug('END requeue init');
    }

    /***
    * @description  Main execute method of the Queuable process.
    ***/
    public void execute(QueueableContext context) {
        sfpegDebug_UTL.info('START with context',context);
        sfpegDebug_UTL.fine('Configuration parameters fetched',this.queueUtil);

        sfpegGroupControl_UTL nextProcess = this.queueUtil.execute();
        if (nextProcess != null) {
            sfpegDebug_UTL.info('END / Requeueing the process with ',nextProcess);
            if (!Test.isRunningTest()) {System.enqueueJob(new StructureGroupControl_QUE(nextProcess));}
            else {this.queueUtil = nextProcess;}
        }
        else {sfpegDebug_UTL.info('END / Processing complete');}
    }

    /***
    * @description  Control configuration initialisation
    ***/
    public static getConfiguration() {
        sfpegDebug_UTL.debug('START');

        sfpegGroupControl_UTL.ControlConfiguration config = new sfpegGroupControl_UTL.ControlConfiguration();
        config.className        = 'StructureGroupControl_QUE';
        config.controlScope     = 'isManagement__c = true';
        config.statusOK         = 'areGroupsOK__c';
        config.statusDetails    = 'KoGroupDetails__c';
        config.statusDate	    = 'LastGroupControlTS__c';
        config.maxIDs           = 100;

        sfpegDebug_UTL.debug('END with config',config);
        return config;
    }
}
```


## Package Content

This package primarily consists in the following Apex classes:
* **sfpegGroupManagement_UTL** implementing the core Group management logic.
* **sfpegGroupControl_UTL** implementing the Group control logic.

They come both with their test classes as well as test custom objects and permission set.


## Technical Details

These are standard Apex classes meant to be used within singleton Queueable 
framework provided by the **[sfpegQueueableUtility](/help/sfpegQueueableUtility.md)**
class. It therefore requires this package to be installed first.


## Release Notes

### June 2025 - v1.0
* First version with the new unlocked package structure.
* Minor code refactoring.
* Install it from [here](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ7000000xH4nIAE).

