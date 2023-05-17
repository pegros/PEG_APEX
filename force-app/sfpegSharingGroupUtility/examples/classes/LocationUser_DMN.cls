/***
* @description	Domain Class for the LocationUser__c custom Object (used by the different triggers)
*				Its main purpose is to trigger reevaluation of Sharing public groups associated to
*               each Location (for Apex Sharing) upon UserLocation evolution (mainly their local Public Groups)
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

public with sharing class LocationUser_DMN {

    // #############################################
    // ############# STATIC VARIABLES  #############
    // #############################################
       
    /***
    * @description	Static variable enabling to cache Location Data required to init LocationUser__c Name.
    ***/   
    private static Map<ID,Schema.Location> LOCATION_MAP = new Map<ID,Schema.Location>();

    /***
    * @description	Static variable enabling to cache User Data required to init LocationUser__c Name.
    ***/   
    private static Map<ID,User> USER_MAP = new Map<ID,User>();
    

    // ##############################################
    // ############## BUSINESS RULES  ###############
    // ##############################################
    
    /***
    * @description	This method is used in before triggers to set/update/control a whole series of values on records:
    *				* Name set to Group Name + User Name.
    * @param		memberList    List of records being created/updated (updated by the method).
    * @param		oldMemberMap  Map of the same records before modification (in update case).
    * @exception	None special
    ***/
    public static void reviewLocationUsers(List<LocationUser__c> memberList, final Map<ID,LocationUser__c> oldMemberMap) {
        sfpegDebug_UTL.info('START with #items',memberList.size());

        // Step #1 - 1st Record Review to extract Locations and Users IDs
        Set<ID> locationIds = new Set<ID>();
        Set<ID> userIds = new Set<ID>();
        for (LocationUser__c iter: memberList) {
            if ((String.isNotBlank(iter.Location__c)) && (!LOCATION_MAP.containsKey(iter.Location__c))) {
                locationIds.add(iter.Location__c);
            }
            if ((String.isNotBlank(iter.User__c)) && (!USER_MAP.containsKey(iter.User__c))) {
                userIds.add(iter.User__c);
            }
        }
        sfpegDebug_UTL.debug('#New Locations to fetch',locationIds.size());
        sfpegDebug_UTL.debug('#New Users to fetch',userIds.size());
        
        // Step #2 - Additional Data fetch
        sfpegDebug_UTL.debug('#Locations in map',LOCATION_MAP.size());
        LOCATION_MAP.putAll(new Map<ID,Schema.Location>([SELECT Name FROM Location WHERE Id in :locationIds]));
        sfpegDebug_UTL.debug('#Locations now in map',LOCATION_MAP.size());

        sfpegDebug_UTL.debug('#Users in map',USER_MAP.size());
        USER_MAP.putAll(new Map<ID,User>([SELECT Name FROM User WHERE Id in :userIds]));
        sfpegDebug_UTL.debug('#Users now in map',USER_MAP.size());

        // Step #3 - 2nd Record Review to reset Name
        for (LocationUser__c iter: memberList) {
            iter.Name = ((String.isBlank(iter.Location__c) ? 'XXX' : LOCATION_MAP.get(iter.Location__c)?.Name)
                        + ' - ' + (String.isBlank(iter.User__c) ? 'YYY' : USER_MAP.get(iter.User__c)?.Name)).left(80);
        }
        
        sfpegDebug_UTL.info('END');         
    }

    /***
    * @description 	Method to (un)register the active Users in the local public groups (_L)
    *               of the Locations they are member of upon membership creation/deletion.
    * @param		memberList	List of new LocationUser__c records being created/deleted
    * @exception	none special.
    ***/
    public static void  reviewMemberships(final List<LocationUser__c> memberList) {
        sfpegDebug_UTL.info('START with #Members',memberList.size());

        Map<ID,Schema.Location> location2update = new Map<ID,Schema.Location>();
        for (LocationUser__c iter : memberList) {
            if (iter.IsActive__c) {
                sfpegDebug_UTL.fine('Processing active Member',iter);
                if (location2update.containsKey(iter.Location__c)) {
                    sfpegDebug_UTL.finest('Location already registered for review',iter.Location__c);
                }
                else {
                    sfpegDebug_UTL.fine('Registering Location for review',iter.Location__c);
                    location2update.put(iter.Location__c, new Schema.Location(Id = iter.Location__c, SharingToEval__c = true));
                }
            }
            else {
                sfpegDebug_UTL.finest('Ignoring inactive Member',iter);
            }
        }
        sfpegDebug_UTL.debug('#Locations registered for review', location2update.size());
        
        if (location2update.size() > 0) {
            update location2update.values();
            sfpegDebug_UTL.info('END after location review triggered');
        }
        else {
            sfpegDebug_UTL.info('END with no location review necessary');
        }
    }

    /***
    * @description 	Method to update the Memberships of Users to the local public groups (_L)
    *               of the Locations they are member of upon change of membership active statuses.
    * @param		memberList      List of new LocationUser__c records being updated
    * @param		oldMemberMap	Map of previous state of the same record.
    * @exception	none special.
    ***/
    public static void  reviewMemberships(final List<LocationUser__c> memberList, final Map<ID,LocationUser__c> oldMemberMap) {
        sfpegDebug_UTL.info('START with #Members', memberList.size());

        Map<ID,Schema.Location> location2update = new Map<ID,Schema.Location>();
        for (LocationUser__c iter : memberList) {
            LocationUser__c iterOld = oldMemberMap.get(iter.Id);
            if (iter.IsActive__c != iterOld.IsActive__c) {
                sfpegDebug_UTL.fine('Processing Member with status change',iter);
                if (location2update.containsKey(iter.Location__c)) {
                    sfpegDebug_UTL.finest('Location already registered for review',iter.Location__c);
                }
                else {
                    sfpegDebug_UTL.fine('Registering Location for review',iter.Location__c);
                    location2update.put(iter.Location__c, new Schema.Location(Id = iter.Location__c, SharingToEval__c = true));
                }
            }
            else {
                sfpegDebug_UTL.finest('Ignoring Member with non changed status',iter);
            }
        }
        sfpegDebug_UTL.debug('#Locations registered for review', location2update.size());
        
        if (location2update.size() > 0) {
            update location2update.values();
            sfpegDebug_UTL.info('END after location review triggered');
        }
        else {
            sfpegDebug_UTL.info('END with no location review necessary');
        }
    }
}