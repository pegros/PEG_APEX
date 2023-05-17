public with sharing class LocationSharingGroup_QUE implements Queueable {

    /***
    * @description	Static variable providing the necessary configuration for the SharingGroup process
    *               implemented in the sfpegSharingGroup_QUE 
    ***/  
    
    /*private final Static Map<String,Object> CONFIG_MAP = new Map<String,Object>{
        'CLASS'             => 'LocationSharingGroup_QUE', // Name of the Queueable Apex Class with custom configuration
        'PREFIX'            => 'VIRTUO',            // Prefix used for Public Group Names created
        'MAX_ITER_NBR'      => 5,                   // Max. Number of iterations with no record to process before stopping Queueable
        'STRUCT_OBJECT'     => 'Location',          // Hierarchical Structure Object API Name
        'STRUCT_EXT_ID'     => 'ExternalId__c',     // API Name of the Structure External ID Field used for Public Group Naming
        'STRUCT_LOCAL'      => 'SharingLocal__c',   // API Name of the Structure String field storing the Local Public Group ID
        'STRUCT_UP'         => 'SharingUp__c',      // API Name of the Structure String field storing the Upwards Public Group ID
        'STRUCT_DOWN'       => 'SharingDown__c',    // API Name of the Structure String field storing the Downwards Public Group ID
        'STRUCT_PARENT'     => 'ParentLocation',    // API Name of the Structure Relation to access Data of the Parent Structure
        'STRUCT_CHILDREN'   => 'ChildLocations',    // API Name of the Structure Relation to access Data of the Children Structures
        'STRUCT_MEMBERS'    => 'LocationUsers__r',  // API Name of the Structure Relation to access Data of the Structure Member Users
        'STRUCT_STATUS'     => 'SharingToEval__c',  // API Name of the Structure Boolean field indicating the Structures to process 
        'STRUCT_TS'         => 'SharingLastEval__c', // API Name of the Structure DateTime field storin the last evaluation fo a Structure
        'MBR_OBJECT'        => 'LocationUsers__c',  // Structure User Member Object API Name
        'MBR_USER'          => 'User__c',           // API Name of the User Member Lookup field providing the User ID fo a Structure Member
        'MBR_ACTIVE'        => 'IsActive__c'        // API Name of the User Member Boolean field indicating if the Membership is active 
    };*/

    private final sfpegSharingGroup_UTL  queueUtil;

    //#########################################
    //############ CONSTRUCTORS ###############
    //#########################################

    /***
    * @description	Standard public constructor used to launch the Queueable process.
    ***/
    public LocationSharingGroup_QUE() {
        sfpegDebug_UTL.debug('START standard init');

        this.queueUtil = new sfpegSharingGroup_UTL();
        sfpegDebug_UTL.fine('Generic utility constructor called');

        this.queueUtil.config.className = 'LocationSharingGroup_QUE';
        this.queueUtil.config.namePrefix = 'VIRTUO';
        sfpegDebug_UTL.fine('Utility configuration parameters set',this.queueUtil.config);

        sfpegDebug_UTL.debug('END standard init');
    }

    /***
    * @description	Private constructor used to continue the Queueable process.
    ***/
    private LocationSharingGroup_QUE(sfpegSharingGroup_UTL newUtil) {
        sfpegDebug_UTL.debug('START requeue init');

        this.queueUtil = newUtil;
        sfpegDebug_UTL.fine('New generic utility processor registered');

        sfpegDebug_UTL.debug('END requeue init');
    }

    //##########################################
    //########### EXECUTION LOGIC ##############
    //##########################################
    
    /***
    * @description  Main execute method of the Queuable process.
    ***/
    public void execute(QueueableContext context){
        sfpegDebug_UTL.info('START with context',context);

        sfpegDebug_UTL.fine('Configuration parameters fetched',this.queueUtil.config);

        sfpegSharingGroup_UTL nextProcess = this.queueUtil.execute();
        sfpegDebug_UTL.fine('Generic execute completed');

        if (nextProcess != null) {
            sfpegDebug_UTL.fine('Requeueing');
            if (!Test.isRunningTest()) {
                System.enqueueJob(new LocationSharingGroup_QUE(nextProcess));
            }
        }
        else {
            sfpegDebug_UTL.fine('End of processing reached');
        }

        sfpegDebug_UTL.info('END');
    }

}
