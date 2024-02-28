public with sharing class LocationSharingGroup_QUE implements Queueable {

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
