/***
* @description  Test class for the sfpegGroupManagement_UTL utility class.
*               Requires the sfpegTestStructure__c and sfpegTestMember__c 
*               test custom objects, as well as the sfpegSharingGroupTest
*               test permission set to be already deployed on the Org.
* @author       P-E GROS
* @date         Apr 2024
* @see sfpegGroupManagement_UTL
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
public class sfpegGroupManagement_TST {
    
    //##############################################################################
    // STATIC VARIABLES
    //##############################################################################

    /**
    * @description  Static variable containing the number of records for tests
    *               Min value is 2.
    **/
    final static Integer RCD_NBR = 2;


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
    * @description Test method for propagation logic on Structure records
    **/   
    @isTest
    static void testGroupMgt(){
        sfpegDebug_UTL.MAX_LOG_LEVEL = 7;
		sfpegDebug_UTL.debug('START');

        List<sfpegTestStructure__c> indepRecords = getStructureRecords('Indep', RCD_NBR);
        for (sfpegTestStructure__c iter : indepRecords) {
            iter.doGroupEval__c = true;
        } 
        insert indepRecords;
        List<sfpegTestStructure__c> rootRecords = getStructureRecords('Root', RCD_NBR);
        for (sfpegTestStructure__c iter : rootRecords) {
            iter.doGroupEval__c = true;
        }
        insert rootRecords;
        List<sfpegTestStructure__c> childRecords = getStructureRecords(rootRecords, RCD_NBR);
        for (sfpegTestStructure__c iter : childRecords) {
            iter.doGroupEval__c = true;
        }
        insert childRecords;
        Set<ID> recordIDs = new Set<ID>();
        recordIDs.addAll((new Map<ID,sfpegTestStructure__c>(indepRecords)).keySet());
        recordIDs.addAll((new Map<ID,sfpegTestStructure__c>(rootRecords)).keySet());
        recordIDs.addAll((new Map<ID,sfpegTestStructure__c>(childRecords)).keySet());
		sfpegDebug_UTL.debug('Data inserted');

        sfpegGroupManagement_UTL.GlobalConfiguration globalConfig = getConfiguration();
        sfpegDebug_UTL.fine('Configuration initialized', globalConfig);
        sfpegGroupManagement_UTL queueUtil = new sfpegGroupManagement_UTL(globalConfig);
        sfpegDebug_UTL.fine('Queue utility initialized',queueUtil);

		System.Test.startTest();

        // Test Case #1 - Standard Group Creations
        sfpegDebug_UTL.debug('TEST Case #1 - Standard Group Creations');

        try {
            queueUtil.execute();
            sfpegDebug_UTL.debug('Group creation process executed');
        }
        catch (Exception e) {
            sfpegDebug_UTL.error('TEST Case #1 KO - Group Creations failed',e);
            Assert.fail('Group Creations for new Populations should not fail: ' + e.getMessage());
        }

        Map<ID,sfpegTestStructure__c> newMap = loadStructureRecords(recordIDs);
        sfpegDebug_UTL.debug('#Structures fetched',newMap.size());
        sfpegDebug_UTL.finest('Structures fetched',newMap);

        Set<ID> groupIDs = new Set<ID>();
        for (sfpegTestStructure__c iter : newMap.values()) {
            sfpegDebug_UTL.finest('Analysing Structure',iter.Name);
            Assert.isNotNull(iter.localGroupId__c,'Structures created should have a local group registered');
            groupIDs.add(iter.localGroupId__c);
            Assert.isNotNull(iter.upGroupId__c,'Structures created should have an upward group registered');
            groupIDs.add(iter.upGroupId__c);
            Assert.isNotNull(iter.downGroupId__c,'Structures created should have a downward group registered');
            groupIDs.add(iter.downGroupId__c);
            Assert.isNotNull(iter.otherLocalGroupId__c,'Structures created should have an other local group registered');
            groupIDs.add(iter.otherLocalGroupId__c);
        }
        sfpegDebug_UTL.debug('Structures checked OK and #Group IDs extracted',groupIDs.size());

        // There are RCD_NBR indep records + RCD_NBR root records + RCD_NBR^2 child records = RCD_NBR * (2 + RCD_NBR) records
        Assert.areEqual(4 * RCD_NBR * (2 + RCD_NBR), groupIDs.size(),'There should be 4 Groups registered per Structure created');
        List<Group> newGroups = [SELECT Name FROM Group WHERE Id IN :groupIDs];
        sfpegDebug_UTL.debug('#Groups refetched',newGroups.size());
        sfpegDebug_UTL.finest('Groups fetched',newGroups);
        Assert.areEqual(groupIDs.size(), newGroups.size(),'There should be 4 Groups actually created per Structure');
        // Naming to check.
        sfpegDebug_UTL.debug('TEST Case #1 OK - Standard Group Creations checked OK ');


        // Test Case #2 - Group reparenting
        sfpegDebug_UTL.debug('TEST Case #2 - Group Reparenting');

        Integer index = 0;
        for (sfpegTestStructure__c iter : childRecords) {
            sfpegTestStructure__c iterP = rootRecords.get(index);
            iter.Parent__c = iterP.Id;
            index += 1;
            if (index >= rootRecords.size()) index = 0;
        }
        sfpegDebug_UTL.debug('#Structures to reparent',childRecords.size());

        try {
            update childRecords;
            sfpegDebug_UTL.debug('Structures reparented');
            queueUtil = new sfpegGroupManagement_UTL(globalConfig);
            sfpegGroupManagement_UTL nextQueueUtil = queueUtil.execute();
            sfpegDebug_UTL.debug('Group update process executed');
            nextQueueUtil.execute();
            sfpegDebug_UTL.debug('Group update process finalization executed');
        }
        catch (Exception e) {
            sfpegDebug_UTL.error('TEST Case #2 KO - Group Reparenting failed',e);
            Assert.fail('Group reevaluation for reparented Structures should not fail: ' + e.getMessage());
        }
        sfpegDebug_UTL.debug('TEST Case #2 OK - Group Reparenting checked OK ');


        // Test Case #3 - Standard Group Deletions
        sfpegDebug_UTL.debug('TEST Case #3 - Standard Group Deletions');
        // Cleansing data
        for (sfpegTestStructure__c iter : childRecords) {
            iter.doGroupEval__c = false;
        } 
        update childRecords;

        Map<ID,sfpegTestStructure__c> indepMap = new Map<ID,sfpegTestStructure__c>(indepRecords);
        Set<ID> indepGroupIDs = new Set<ID>();
        for (ID iter : indepMap.keySet()) {
            sfpegTestStructure__c iterS = newMap.get(iter);
            indepGroupIDs.add(iterS.localGroupId__c);
            indepGroupIDs.add(iterS.upGroupId__c);
            indepGroupIDs.add(iterS.downGroupId__c);
            indepGroupIDs.add(iterS.otherLocalGroupId__c);
        }
        sfpegDebug_UTL.debug('#Structures to delete',indepMap.size());
        sfpegDebug_UTL.debug('#Groups for deleted Structures to check',indepGroupIDs.size());

        try {
            delete indepMap.values();
            sfpegDebug_UTL.debug('Structures deleted');
            
            queueUtil = new sfpegGroupManagement_UTL(globalConfig);
            sfpegGroupManagement_UTL nextQueueUtil = queueUtil.execute();
            sfpegDebug_UTL.debug('Group delete process executed');
            nextQueueUtil.execute();
            sfpegDebug_UTL.debug('Group delete process finalization executed');
        }
        catch (Exception e) {
             sfpegDebug_UTL.error('TEST Case #3 KO - Group Deletions failed',e);
             Assert.fail('Group Deletions for deleted Structures should not fail: ' + e.getMessage());
        }
 
        List<Group> oldGroups = [SELECT Name FROM Group WHERE Id IN :indepGroupIDs];
        sfpegDebug_UTL.debug('#Groups refetched',oldGroups.size());
        Assert.areEqual(0, oldGroups.size(),'All Groups for deleted Structures should be deleted');
        sfpegDebug_UTL.debug('TEST Case #3 OK - Group Deletions checked OK ');


        // Test Case #4 - Empty Propagation execution
        sfpegDebug_UTL.debug('TEST Case #4 - Empty processing');
        // Cleansing data
        for (sfpegTestStructure__c iter : rootRecords) {
            iter.doGroupEval__c = false;
        } 
        update rootRecords;
        for (sfpegTestStructure__c iter : childRecords) {
            iter.doGroupEval__c = false;
        } 
        update childRecords;

        try {
            queueUtil = new sfpegGroupManagement_UTL(globalConfig);
            sfpegGroupManagement_UTL nextQueueUtil = queueUtil.execute();
            sfpegDebug_UTL.debug('Empty process executed');
            Assert.areEqual(null, nextQueueUtil, 'No next process should be returned when nothing to do');
            sfpegDebug_UTL.debug('TEST Case #4 OK - Empty processing checked OK');
        }
        catch (Exception e) {
            sfpegDebug_UTL.error('TEST Case #4 KO - Empty process failed',e);
            Assert.fail('Standard Empty Group Management process should not fail: ' + e.getMessage());
        }

        System.Test.stopTest();          
		sfpegDebug_UTL.debug('END');
    }


    /**
    * @description Test method for propagation logic on Member records
    **/   
    @isTest
    static void testMemberMgt(){
        //sfpegDebug_UTL.MAX_LOG_LEVEL = 7;
		sfpegDebug_UTL.debug('START');

        sfpegGroupManagement_UTL.GlobalConfiguration globalConfig = getConfiguration();
        sfpegDebug_UTL.fine('Configuration initialized', globalConfig);
        sfpegGroupManagement_UTL queueUtil = new sfpegGroupManagement_UTL(globalConfig);
        sfpegDebug_UTL.fine('Queue utility initialized',queueUtil);

        List<sfpegTestStructure__c> structures = getStructureRecords('Structure', RCD_NBR * 2);
        for (sfpegTestStructure__c iter : structures) {
            iter.doGroupEval__c = true;
        }
        insert structures;
        queueUtil.execute();
        Map<ID,sfpegTestStructure__c> structureMap = new Map<ID,sfpegTestStructure__c>(structures);
        sfpegDebug_UTL.debug('#Structures inserted',structureMap.size());

        List<sfpegTestMember__c> members = getMemberRecords(structures, new Set<ID>{(ID)(UserInfo.getUserId())}, 3);
        insert members;
        Map<ID,sfpegTestMember__c> memberMap = new Map<ID,sfpegTestMember__c>(members);
        sfpegDebug_UTL.debug('#Members inserted',memberMap.size());

		System.Test.startTest();

        // Test Case #1 - User Member registration
        sfpegDebug_UTL.debug('TEST Case #1 - User Member registration');

        try {
            sfpegGroupManagement_UTL nextUtil = queueUtil.execute();
            sfpegDebug_UTL.debug('User Member registration process initiated');
            nextUtil.execute();
            sfpegDebug_UTL.debug('User Member registration process finalized');
        }
        catch (Exception e) {
            sfpegDebug_UTL.error('TEST Case #1 KO - User Member registration failed',e);
            Assert.fail('User Member registration should not fail: ' + e.getMessage());
        }

        System.Test.stopTest();          
		sfpegDebug_UTL.debug('END');
    }


    //##############################################################################
    // DATA INIT METHODS
    //##############################################################################

    /**
    * @description  Public method that initiates the .
    **/
    public static sfpegGroupManagement_UTL.GlobalConfiguration getConfiguration() {
        sfpegDebug_UTL.finer('START');

        // Main Configuration
        sfpegGroupManagement_UTL.GlobalConfiguration config = new sfpegGroupManagement_UTL.GlobalConfiguration();
        config.className        = 'sfpegGroupManagement_TST';
        config.maxCreate        = RCD_NBR * (2 + RCD_NBR);
        config.maxUpdate        = RCD_NBR * (2 + RCD_NBR);
        config.maxDelete        = RCD_NBR * (2 + RCD_NBR);
        config.structObject     = 'sfpegTestStructure__c';
        config.structKey	    = 'UniqueID__c';
        config.structStatus	    = 'doGroupEval__c';
        config.structTS 		= 'lastGroupEvalTS__c';
        config.structMsg 		= 'lastGroupEvalMsg__c';
        config.useRT            = false;
        config.structParent     = 'Parent__r';
        config.structParentId   = 'Parent__c';
        config.structChildren   = 'Children__r';
        config.groupConfigs     = new Map<String,sfpegGroupManagement_UTL.GroupConfiguration>();
        sfpegDebug_UTL.fine('Main configuration init',config);

        // Agent Groups configuration
        sfpegGroupManagement_UTL.GroupConfiguration mainGroups = new sfpegGroupManagement_UTL.GroupConfiguration();
        config.groupConfigs.put('MAIN',mainGroups);
        mainGroups.suffix       = 'MAIN';
        mainGroups.structLocal  = 'localGroupId__c';
        mainGroups.structUp     = 'upGroupId__c';
        mainGroups.structDown   = 'downGroupId__c';
        mainGroups.mbrObject    = 'sfpegTestMember__c';
        mainGroups.mbrActive    = 'Status__c';
        mainGroups.mbrStruct    = 'Structure__c';
        mainGroups.mbrIDs       = new List<String>{'User__c'};
        sfpegDebug_UTL.fine('Main Groups configuration init',mainGroups);

        // Gestion Groups configuration
        sfpegGroupManagement_UTL.GroupConfiguration otherGroup = new sfpegGroupManagement_UTL.GroupConfiguration();
        config.groupConfigs.put('OTHER',otherGroup);
        otherGroup.suffix         = 'OTHER';
        otherGroup.structLocal    = 'otherLocalGroupId__c';
        otherGroup.mbrObject      = 'sfpegTestMember__c';
        otherGroup.mbrStruct      = 'Structure__c';
        otherGroup.mbrIDs         = new List<String>{'User__c'};
        sfpegDebug_UTL.fine('Other Group configuration init',otherGroup);

        sfpegDebug_UTL.debug('END');
        return config;
    }

    /**
    * @description  Public method that initiates a single standalone Structure record.
    **/
    public static sfpegTestStructure__c getStructureRecord(final String name, final ID parentId) {
        sfpegDebug_UTL.finer('START with Name',name);
        sfpegDebug_UTL.finest('and parentId',parentId);

        sfpegTestStructure__c newRecord = new sfpegTestStructure__c(
            Name = name,
            UniqueID__c = name
        );
        if (String.isNotBlank(parentId)) newRecord.Parent__c = parentId;
        
        sfpegDebug_UTL.finer('END');
        return newRecord;
    }

    /**
    * @description  Public method that initiates a single standalone Member record.
    **/
    public static sfpegTestMember__c getMemberRecord(final String name, final ID structureId, final boolean status, final ID userId) {
        sfpegDebug_UTL.finer('START with Name',name);
        sfpegDebug_UTL.finest('and structureId',structureId);
        sfpegDebug_UTL.finest('and status',status);
        sfpegDebug_UTL.finest('and userId',userId);

        sfpegTestMember__c newRecord = new sfpegTestMember__c(
            Name = name,
			Structure__c = structureId,
			Status__c = status
        );
        if (String.isNotBlank(userId)) newRecord.User__c = userId;
        
        sfpegDebug_UTL.finer('END');
        return newRecord;
    }

    /**
    * @description  Public method that initiates a list of Structure records.
    *               For each record, the Names are appended with the record iterator (between 0 and recordCount - 1)
    **/
    public static List<sfpegTestStructure__c> getStructureRecords(final String name, final Integer recordCount) {
        sfpegDebug_UTL.finer('START with Name',name);
        sfpegDebug_UTL.finest('and #records',recordCount);

        List<sfpegTestStructure__c> results = new List<sfpegTestStructure__c>();
        for (Integer iter = 0; iter < recordCount; iter++) {
            sfpegDebug_UTL.finest('Processing record',iter);
            results.add(getStructureRecord(name + '-' + iter, null));
        }
        sfpegDebug_UTL.finer('END with #records',results.size());
        return results;
    }

    /**
    * @description  Public method that initiates a list of children Structures records for a set of Structures.
    *               For each child record, the Names of the parent are appended with the record iterator (between 0 and recordCount - 1)
    **/
    public static List<sfpegTestStructure__c> getStructureRecords(final List<sfpegTestStructure__c> parents, final Integer childCount) {
        sfpegDebug_UTL.finer('START with #parents',parents.size());
        sfpegDebug_UTL.finest('and #records',childCount);

        List<sfpegTestStructure__c> results = new List<sfpegTestStructure__c>();
        for (sfpegTestStructure__c iter : parents) {
            sfpegDebug_UTL.finest('Processing record',iter.Name);
            for (Integer iterC = 0; iterC < childCount; iterC++) {
                sfpegDebug_UTL.finest('Processing child',iterC);
                results.add(getStructureRecord(iter.Name + '-' + iterC, iter.Id));
            }
        }
        sfpegDebug_UTL.finer('END with #records',results.size());
        return results;
    }

    /**
    * @description  Public method that initiates a list of Member records.
    *               For each record, the Names are the Structure Name appended with the record iterator (between 0 and recordCount - 1)
    **/
    public static List<sfpegTestMember__c> getMemberRecords(final List<sfpegTestStructure__c> structures, final Set<ID> users, final Integer recordCount) {
        sfpegDebug_UTL.finer('START with #structures',structures.size());
        sfpegDebug_UTL.finest('and #users',users.size());
        sfpegDebug_UTL.finest('and #records',recordCount);

        List<ID> userIDs = new List<ID>(users);
        List<sfpegTestMember__c> results = new List<sfpegTestMember__c>();
        Integer indexP = 0;
        for (sfpegTestStructure__c iter : structures) {
            sfpegDebug_UTL.finest('Processing structure',iter.Name);
            for (Integer iterRcd = 0; iterRcd <= recordCount; iterRcd++) {
                results.add(getMemberRecord(iter.Name + iterRcd,iter.Id, (Math.mod(indexP,2) == 0), (iterRcd >= userIDs.size() ? null : userIDs[indexP])));
                indexP++;
                if (indexP > userIDs.size()) indexP = 0;
            }
        }
        sfpegDebug_UTL.finer('END with #records',results.size());
        return results;
    }


    //##############################################################################
    // DATA UTILITIES
    //##############################################################################

    /**
    * @description  Public method to reload a standard set of fields for integrity tests on structure
    *               records previously inserted/updated.
    **/
    public static Map<ID,sfpegTestStructure__c> loadStructureRecords(final Set<ID> recordIDs) {
        return new Map<ID,sfpegTestStructure__c>(
            [   SELECT  Name, UniqueID__c, Parent__c,
                        localGroupId__c,upGroupId__c, downGroupId__c,otherLocalGroupId__c,
                        doGroupEval__c, lastGroupEvalTS__c, lastGroupEvalMsg__c,
                        SystemModStamp
                FROM sfpegTestStructure__c
                WHERE Id IN :recordIDs]);
    }

    /**
    * @description  Public method to reload a standard set of fields for integrity tests on structure
    *               records previously inserted/updated.
    **/
    public static Map<ID,sfpegTestMember__c> loadMemberRecords(final Set<ID> recordIDs) {
        return new Map<ID,sfpegTestMember__c>(
            [   SELECT  Name, status__c,
                        user__c,structure__c,
                        SystemModStamp
                FROM sfpegTestMember__c
                WHERE Id IN :recordIDs]);
    }

}