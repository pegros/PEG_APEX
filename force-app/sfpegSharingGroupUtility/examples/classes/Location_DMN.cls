/***
* @description	Domain Class for the Location standard Object (used by the different triggers)
*				Its main purpose is to manage the Sharing public groups associated to each Location
*				and needed to properly manage various record visibility strategies (via apex sharing).
* @author		P-E GROS
* @date			May 2023
* @see PEG_APEX package (https://github.com/pegros/PEG_APEX)
*
* Legal Notice
*
* MIT License
*
* Copyright (c) 2023 pegros
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
***/

public with sharing class Location_DMN {

    // #############################################
    // ############# STATIC VARIABLES  #############
    // #############################################
       
    /***
    * @description	Static variable enabling to leverage analysis done in before triggers
    *               to trigger Sharing Group management logic in the after triggers.
    ***/   
    private Static Boolean UPDATE_SHARING_GROUPS = false;

    /***
    * @description	Static variable providing the necessary configuration for the SharingGroup process
    *               implemented in the sfpegSharingGroup_QUE 
    ***/
    /*
    Map<String,Object> CONFIG_MAP = new Map<String,Object>{
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
    };
    */
    
    // ##############################################
    // ############## BUSINESS RULES  ###############
    // ##############################################
    
    /***
    * @description	This method is used in before triggers to set/update/control a whole series of values on records:
    *				* SharingToEval__c set to true if any of the SharingXXX__c public group ID fields is empty
    *                 (typicval creation case) or if the ParentLocationId field value changes (in case of
    *                 record reparenting)
    *               * controls that the ExternalId__c is properly set and not modified
    *				The UPDATE_SHARING_GROUPS static variable is set to true if any record gets a 
    *				SharingToEval__c flag set to true (to execute the actual control/launch of the
    *               Public Group management Queuable process via the managePublicGroups() method
    *               in the after trigger logic).
    * @param		locationList    List of records being created/updated (updated by the method).
    * @param		oldLocationMap  Map of the same Location records before modification (in update case).
    * @exception	None special
    ***/
    public static void reviewLocations(List<Schema.Location> locationList, final Map<ID,Schema.Location> oldLocationMap){
        sfpegDebug_UTL.info('START with #items',locationList.size());
        UPDATE_SHARING_GROUPS = false;

        // Step #1 - 1st Record Review
        for (Schema.Location iter: locationList) {
            Schema.Location iterOld = (oldLocationMap == null ? null : oldLocationMap.get(iter.Id));

            if  (   (   (oldLocationMap != null)
                    &&  (iter.ParentLocationId != oldLocationMap.get(iter.Id).ParentLocationId))
                ||  (String.isBlank(iter.SharingLocal__c))
                ||  (String.isBlank(iter.SharingUp__c))
                ||  (String.isBlank(iter.SharingDown__c))) {
                sfpegDebug_UTL.fine('Registering Item for Public Group review',iter.Name);
                iter.SharingToEval__c = true;
                UPDATE_SHARING_GROUPS = true;
            }
            else if (iter.SharingToEval__c) {
                sfpegDebug_UTL.fine('Item already registered for Public Group review',iter.Name);
                UPDATE_SHARING_GROUPS = true;
            }

            if (String.isBlank(iter.ExternalId__c)) {
                sfpegDebug_UTL.warn('Location has no External ID',iter.Name);
                iter.addError(Label.Location_MissingExternalIdError);
            }
        }
        
        // Step #2 - Additional Data fetch
        

        // Step #3 - 2nd Record Review
        
        
        sfpegDebug_UTL.info('END');         
    }
        
    /***
    * @description	This method is used in before delete triggers control the Location 
    *               records being deleted. 
    *               * check that any Location has no child Location (to simplify overall management)
    *               Errors are added on records not passing controls.
    *               It uses the Location_DeletionWithChildrenError custom label.     
    *				The UPDATE_SHARING_GROUPS static variable is set to true (to execute the actual
    *               control/launch of the Public Group management Queuable process via the
    *               managePublicGroups() method in the after trigger logic).
    * @param		locationMap     Map of records being deleted (with their IDs as keys)
    * @exception	None special (an error being added on each record being rejected)
    ***/
    public static void controlDeletions(Map<ID,Schema.Location> locationMap){
        sfpegDebug_UTL.info('START with #items',locationMap.size());
        UPDATE_SHARING_GROUPS = true;

         // Step #1 - 1st Record Review

        // Step #2 - Additional Data fetch
        AggregateResult[] childLocations = [	SELECT count(Id), ParentLocationId
                                                FROM Location
                                                WHERE ParentLocationId in :locationMap.keySet()
                                                GROUP BY ParentLocationId];
        sfpegDebug_UTL.debug('#children found',childLocations.size());
        
        if (childLocations.size() == 0) {
            sfpegDebug_UTL.info('END / All records OK');
            return;
        }
        sfpegDebug_UTL.debug('Processing children list');

        // Step #3 - 2nd Record Review            
        for (AggregateResult iter : childLocations) {
            ID iterId = (Id)(iter.get('ParentLocationId'));
            sfpegDebug_UTL.warn('Blocking Location deletion',iterId);
            locationMap.get(iterId).addError(Label.Location_DeletionWithChildrenError);
        }

        sfpegDebug_UTL.info('END / #Errors positioned',childLocations.size());            
    }

    /***
    * @description	This method is typically triggered in the After trigger logic to possibly
    *               launch the Sharing Group reevaluation process if needed.
    *               It relies on the UPDATE_SHARING_GROUPS static variable (typically set
    *               in the Before trigger logic) to actually trigger the process implemented
    *               in the sfpegSharingGroup_QUE class via the checkLaunch() method of the 
    *               sfpegQueueable_UTL (implementing the Apex queueable singleton pattern).
    * @exception	None special.
    * @see			sfpegQueueable_UTL
    * @see			sfpegSharingGroup_QUE  
    ***/  
    public static void managePublicGroups() {
        sfpegDebug_UTL.info('START with reevaluation required?',UPDATE_SHARING_GROUPS);
        if (UPDATE_SHARING_GROUPS) {
            //sfpegQueueable_UTL.checkLaunch('sfpegSharingGroup_QUE');
            sfpegQueueable_UTL.checkLaunch('LocationSharingGroup_QUE');
        }
        sfpegDebug_UTL.info('END');
    } 
    
    /***
    * @description	This method is typically triggered in the After trigger logic (usually update)
    *               to reevaluate the Apex sharing of the Locations.
    *               It checks that the different Location records have manual record share records
    *               sharing with their Upwards public groups (as set in SharingUp__c).
    * @param		locationMap     Map of records being updated (updated by the method).
    * @exception	None special.
    * @see			sfpegQueueable_UTL
    * @see			sfpegSharingGroup_QUE  
    ***/  
    public static void shareLocations(final Map<ID,Schema.Location> locationMap) {
        sfpegDebug_UTL.info('START with #items',locationMap.size());

        // Step #1 - Fetch current Sharing records
        List<LocationShare> existingShares = [  SELECT ParentId, UserOrGroupId, AccessLevel
                                                FROM LocationShare
                                                WHERE ParentId in :locationMap.keySet()
                                                    AND RowCause = 'Manual'];
        sfpegDebug_UTL.debug('#Sharing records fetched', existingShares.size());

        // Step #2 - Sharing Record Review
        Set<Id> locations2share = new Set<ID>(locationMap.keySet());
        if (existingShares != null) {
            for (LocationShare iter : existingShares) {
                sfpegDebug_UTL.finest('Processing Sharing record',iter);
                Schema.Location iterLocation = locationMap.get(iter.ParentId);
                sfpegDebug_UTL.finest('Location fetched',iterLocation);
                if (String.isBlank(iterLocation.SharingUp__c)) {
                    sfpegDebug_UTL.fine('Location has no Group',iterLocation.Id);
                    locations2share.remove(iterLocation.Id);
                }
                else if (iter.UserOrGroupId == iterLocation.SharingUp__c) {
                    sfpegDebug_UTL.fine('Location already shared',iterLocation.Id);
                    locations2share.remove(iterLocation.Id);
                }
            }
        }
        sfpegDebug_UTL.debug('#Locations remaining to share',locations2share.size());

        if (locations2share.size() == 0) {
            sfpegDebug_UTL.info('END / Sharing already OK');
            return;
        }

        // Step #3 - Sharing Record Review
        List<LocationShare> shares2add = new List<LocationShare>();
        for (ID iter : locations2share) {
            sfpegDebug_UTL.finest('Sharing Location record',iter);
            Schema.Location iterLocation = locationMap.get(iter);
            if (String.isNotBlank(iterLocation.SharingUp__c)) {
                sfpegDebug_UTL.fine('Sharing Location with Upward Group ',iter);
                shares2add.add(new LocationShare(
                    ParentId = iter,
                    UserOrGroupId = iterLocation.SharingUp__c,
                    RowCause = 'Manual',
                    AccessLevel   = 'Edit'
                ));
            }
            else {
                sfpegDebug_UTL.fine('Ignoring Location with no Upward Group',iter);
            }
        }
        sfpegDebug_UTL.fine('#Location Shares init',shares2add.size());

        insert shares2add;
        sfpegDebug_UTL.info('END / #Shares added',shares2add.size());
    } 
}