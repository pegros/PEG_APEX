/***
* @description  Test class for the sfpegGroupControl_UTL utility class.
*               Requires the sfpegTestStructure__c and sfpegTestMember__c 
*               test custom objects, as well as the sfpegSharingGroupTest
*               test permission set to be already deployed on the Org.
* @author       P-E GROS
* @date         Apr 2024
* @see sfpegGroupControl_UTL
* @see PEG_APEX package (https://github.com/pegros/PEG_APEX)
*
* Legal Notice
*
* MIT License
*
* Copyright (c) 2024 pegros
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

@isTest
public class sfpegGroupControl_TST {
    
    //##############################################################################
    // STATIC VARIABLES
    //##############################################################################

    /**
    * @description  Static variable containing the number of records for tests
    *               Min value is 2.
    **/
    final static Integer RCD_NBR = 2;

    private static final String STATUS_OK_FIELD = 'areGroupsOK__c';
    private static final String STATUS_DETAILS_FIELD = 'KoGroupDetails__c';

    //##############################################################################
    // TEST INITIALIZATION
    //##############################################################################
    
    /**
    * @description  Add required Population PSets to current test user.
    **/
    @testSetup
	static void testSetup() {
        sfpegDebug_UTL.MAX_LOG_LEVEL = 7;
    	sfpegDebug_UTL.debug('START');
        
        // Step #1 - PSets assignments
		String currentUserId = UserInfo.getUserId();
		sfpegDebug_UTL.debug('Current UserId fetched',currentUserId);

		Map<ID,PermissionSet> psetMap = new Map<ID,PermissionSet>([SELECT Name FROM PermissionSet WHERE Name = 'sfpegSharingGroupTest']);
		sfpegDebug_UTL.debug('Location Permission Sets fetched', psetMap);

		List<PermissionSetAssignment> currentAssignments = [	SELECT PermissionSetId FROM PermissionSetAssignment
																WHERE AssigneeId = :currentUserId AND PermissionSetId in :psetMap.keySet()];
		sfpegDebug_UTL.debug('Current Location PSet Assignments fetched ',currentAssignments);
		for (PermissionSetAssignment iter : currentAssignments) {
			sfpegDebug_UTL.fine('Removing PermissionSet',iter.PermissionSetId);
			psetMap.remove(iter.PermissionSetId);
		}
		sfpegDebug_UTL.debug('Missing Location Permission Sets determined',psetMap);

		List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
		for (PermissionSet iter : psetMap.values()) {
			sfpegDebug_UTL.fine('Processing PSet',iter);
			newAssignments.add(new PermissionSetAssignment(AssigneeId = currentUserId, PermissionSetId = iter.Id));
		}
		sfpegDebug_UTL.debug('New Assignments init',newAssignments);

		insert newAssignments;
		sfpegDebug_UTL.debug('New Assignments inserted',newAssignments);

		sfpegDebug_UTL.debug('END');
    }


    //##############################################################################
    // TEST EXECUTION
    //##############################################################################

    /**
    * @description Test method for public group controls on Structures
    **/   
    @isTest
    static void testGroupControl(){
        sfpegDebug_UTL.MAX_LOG_LEVEL = 5;
		sfpegDebug_UTL.debug('START');
        sfpegDebug_UTL.MAX_LOG_LEVEL = 6;

        // Test data preparation
        List<sfpegTestStructure__c> rootRecords = sfpegGroupManagement_TST.getStructureRecords('Root', RCD_NBR);
        for (sfpegTestStructure__c iter : rootRecords) {
            iter.doGroupEval__c = true;
        }
        insert rootRecords;
        List<sfpegTestStructure__c> childRecords = sfpegGroupManagement_TST.getStructureRecords(rootRecords, RCD_NBR);
        for (sfpegTestStructure__c iter : childRecords) {
            iter.doGroupEval__c = true;
        }
        insert childRecords;
        sfpegDebug_UTL.debug('All Structures inserted');
        Set<ID> recordIDs = new Set<ID>();
        recordIDs.addAll((new Map<ID,sfpegTestStructure__c>(rootRecords)).keySet());
        recordIDs.addAll((new Map<ID,sfpegTestStructure__c>(childRecords)).keySet());
		sfpegDebug_UTL.debug('#Structure IDs registered',recordIDs.size());

        sfpegGroupManagement_UTL.GlobalConfiguration globalConfig = sfpegGroupManagement_TST.getConfiguration();
        sfpegDebug_UTL.fine('Group Configuration initialized', globalConfig);
        sfpegGroupManagement_UTL mgtQueueUtil = new sfpegGroupManagement_UTL(globalConfig);
        sfpegDebug_UTL.fine('Group Management utility initialized',mgtQueueUtil);
        mgtQueueUtil.execute();
        sfpegDebug_UTL.debug('Group creation process executed');

        Map<ID,sfpegTestStructure__c> newMap = sfpegGroupManagement_TST.loadStructureRecords(recordIDs);
        sfpegDebug_UTL.debug('#Structures fetched',newMap.size());
        sfpegDebug_UTL.finest('Structures data fetched',newMap);

        Map<ID,ID> groupStructMap = new Map<ID,ID>();
        for (sfpegTestStructure__c iter : newMap.values()) {
            sfpegDebug_UTL.finest('Analysing Structure',iter.Name);
            groupStructMap.put(iter.localGroupId__c,iter.Id);
            groupStructMap.put(iter.upGroupId__c,iter.Id);
            groupStructMap.put(iter.downGroupId__c,iter.Id);
            groupStructMap.put(iter.otherLocalGroupId__c,iter.Id);
        }
        sfpegDebug_UTL.debug('#Group IDs extracted',groupStructMap.size());

        List<Group> newGroups = [SELECT Name FROM Group WHERE Id IN :groupStructMap.keySet()];
        sfpegDebug_UTL.debug('#Groups refetched',newGroups.size());


		System.Test.startTest();
        sfpegDebug_UTL.MAX_LOG_LEVEL = 7;

        // Test Case #1 - All OK Execution
        sfpegDebug_UTL.debug('TEST Case #1 - All OK Execution');

        sfpegGroupControl_UTL.ControlConfiguration controlConfig = getConfiguration();
        sfpegDebug_UTL.fine('Group Configuration initialized', globalConfig);

        sfpegGroupControl_UTL queueUtil = new sfpegGroupControl_UTL(globalConfig,controlConfig);
        sfpegDebug_UTL.fine('Group control utility initialized',queueUtil);
        
        try {
            sfpegGroupControl_UTL nextUtil = queueUtil.execute();
            sfpegDebug_UTL.debug('All OK Control Execution done');
            nextUtil.execute();
            sfpegDebug_UTL.debug('All OK Termination done');
        }
        catch (Exception e) {
            sfpegDebug_UTL.error('TEST Case #1 KO - All OK Control Execution should not raise exception',e);
            Assert.fail('All OK Control Execution should not fail: ' + e.getMessage());
        }

        newMap = sfpegGroupManagement_TST.loadStructureRecords(recordIDs);
        sfpegDebug_UTL.debug('#Structures refetched',newMap.size());

        for (sfpegTestStructure__c iter : newMap.values()) {
            sfpegDebug_UTL.finer('Analysing structure',iter);
            Assert.areEqual(true, iter.areGroupsOK__c,'All OK Structures should be marked as OK by control');
        }
        sfpegDebug_UTL.debug('TEST Case #1 - All Structures controlled OK');


        // Test Case #2 - Missing/wrong Inputs
        sfpegDebug_UTL.debug('TEST Case #2 - Missing/wrong Inputs');

        try {
            sfpegGroupControl_UTL badQueueUtl = new sfpegGroupControl_UTL(null,null);
            sfpegDebug_UTL.error('TEST Case #2 KO - Bad Group Configuration should raise exception');
            Assert.fail('Bad Group Configuration should raise exception');
        }
        catch (Exception e) {
            sfpegDebug_UTL.debug('TEST Case #1 OK - Bad Group Configuration properly raised exception',e);
        }

        try {
            sfpegGroupManagement_UTL.GlobalConfiguration badGroupConfig = new sfpegGroupManagement_UTL.GlobalConfiguration();
            sfpegGroupControl_UTL badQueueUtl = new sfpegGroupControl_UTL(badGroupConfig,null);
            sfpegDebug_UTL.error('TEST Case #2 KO - No Group Detailed Configuration should raise exception');
            Assert.fail('No Group Detailed Configuration should raise exception');
        }
        catch (Exception e) {
            sfpegDebug_UTL.debug('TEST Case #1 OK - No Group Detailed Configuration properly raised exception',e);
        }

        try {
            sfpegGroupManagement_UTL.GlobalConfiguration badGroupConfig = new sfpegGroupManagement_UTL.GlobalConfiguration();
            badGroupConfig.groupConfigs = new Map<String,sfpegGroupManagement_UTL.GroupConfiguration>();
            sfpegGroupControl_UTL badQueueUtl = new sfpegGroupControl_UTL(badGroupConfig,null);
            sfpegDebug_UTL.error('TEST Case #2 KO - Empty Group Detailed Configuration should raise exception');
            Assert.fail('Empty  Group Detailed Configuration should raise exception');
        }
        catch (Exception e) {
            sfpegDebug_UTL.debug('TEST Case #1 OK - Empty Group Detailed Configuration properly raised exception',e);
        }

        try {
            sfpegGroupControl_UTL badQueueUtl = new sfpegGroupControl_UTL(globalConfig,null);        
            sfpegDebug_UTL.error('TEST Case #2 KO - Bad Control Configuration should raise exception');
            Assert.fail('Bad Control Configuration should raise exception');
        }
        catch (Exception e) {
            sfpegDebug_UTL.debug('TEST Case #1 OK - Bad Control Configuration properly raised exception',e);
        }

        try {
            sfpegGroupManagement_UTL.GlobalConfiguration badGroupConfig = new sfpegGroupManagement_UTL.GlobalConfiguration();
            badGroupConfig.groupConfigs = new Map<String,sfpegGroupManagement_UTL.GroupConfiguration>();
            badGroupConfig.groupConfigs.put('TEST',new sfpegGroupManagement_UTL.GroupConfiguration());
            sfpegGroupControl_UTL badQueueUtl = new sfpegGroupControl_UTL(badGroupConfig,controlConfig);
            sfpegDebug_UTL.error('TEST Case #2 KO - Bad Group Detailed Configuration should raise exception');
            Assert.fail('Bad Group Detailed Configuration should raise exception');
        }
        catch (Exception e) {
            sfpegDebug_UTL.debug('TEST Case #1 OK - Bad Group Detailed Configuration properly raised exception',e);
        }

        // Test Case #3 - Missing Groups
        sfpegDebug_UTL.debug('TEST Case #3 - Missing Groups');
        List<sfpegTestStructure__c> indepRecords = sfpegGroupManagement_TST.getStructureRecords('Indep', RCD_NBR);
        insert indepRecords;

        recordIDs = new Set<ID>();
        recordIDs.addAll((new Map<ID,sfpegTestStructure__c>(indepRecords)).keySet());

        newMap = sfpegGroupManagement_TST.loadStructureRecords(recordIDs);
        sfpegDebug_UTL.debug('#New Structures fetched',newMap.size());
        sfpegDebug_UTL.finest('New Structures data fetched',newMap);

        try {
            queueUtil.execute();
            sfpegDebug_UTL.debug('All OK Control Execution done');
        }
        catch (Exception e) {
            sfpegDebug_UTL.error('TEST Case #3 KO - All New Control Execution should not raise exception',e);
            Assert.fail('All New Control Execution should not fail: ' + e.getMessage());
        }

        newMap = sfpegGroupManagement_TST.loadStructureRecords(recordIDs);
        sfpegDebug_UTL.debug('#Structures refetched',newMap.size());
        sfpegDebug_UTL.finest('New Structures data fetched',newMap);

        for (sfpegTestStructure__c iter : newMap.values()) {
            sfpegDebug_UTL.finer('Analysing structure',iter);
            Assert.areEqual(false, iter.areGroupsOK__c,'All New Structures should be marked as KO by control');
            Assert.areEqual(true, iter.doGroupEval__c,'All New Structures should be marked as for Eval by control');
        }
        sfpegDebug_UTL.debug('TEST Case #3 - New Structures controlled OK');

        System.Test.stopTest();          
		sfpegDebug_UTL.debug('END');
    }


    //##############################################################################
    // DATA INIT METHODS
    //##############################################################################

    /**
    * @description  Public method that initiates the .
    **/
    public static sfpegGroupControl_UTL.ControlConfiguration getConfiguration() {
        sfpegDebug_UTL.debug('START');

        sfpegGroupControl_UTL.ControlConfiguration config = new sfpegGroupControl_UTL.ControlConfiguration();
        config.className        = 'sfpegGroupControl_TST';
        config.statusOK         = 'areGroupsOK__c';
        config.statusDetails    = 'KoGroupDetails__c';
        config.statusDate	    = 'LastGroupControlTS__c';
        config.maxIDs           = 100;

        sfpegDebug_UTL.debug('END with config',config);
        return config;
    }
    
}