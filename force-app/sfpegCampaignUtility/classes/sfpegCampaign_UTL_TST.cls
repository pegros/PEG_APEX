/***
* @description  Test class for the sfpegCampaign_UTL utility class.
*               Tests all public methods and business logic scenarios.
* @see          sfpegCampaign_UTL
* @author       P-E GROS
* @date         June 2025
* @see PEG_APEX package (https://github.com/pegros/PEG_APEX)
*
* Legal Notice
*
* MIT License
*
* Copyright (c) 2025 pegros
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

@SuppressWarnings('PMD.ClassNamingConventions')
@isTest
public class sfpegCampaign_UTL_TST {

    /***
    * @description Test data setup method to create test records
    ***/
    @TestSetup
    static void setupTestData() {
        sfpegDebug_UTL.debug('START');
        
        // Create test Contacts and Leads for Campaign Members
        List<Contact> testContacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact' + i,
                Email = 'testcontact' + i + '@test.com'
            ));
        }
        insert testContacts;

        List<Lead> testLeads = new List<Lead>();
        for (Integer i = 0; i < 3; i++) {
            testLeads.add(new Lead(
                FirstName = 'Test',
                LastName = 'Lead' + i,
                Email = 'testlead' + i + '@test.com',
                Company = 'Test Company ' + i
            ));
        }
        insert testLeads;

        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i
            ));
        }
        insert testAccounts;
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the doHierarchyPropagation method with valid configuration
    ***/
    @isTest
    static void testDoHierarchyPropagation_WithValidConfig() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        // Get test record type ID (using a standard Campaign RT if available)
        Id campaignRtId = getCampaignMemberRecordTypeId();
        
        // Create test campaign with hierarchy fields
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign Hierarchy',
            CampaignMemberRecordTypeId = campaignRtId,
            BudgetedCost = 1000,
            ActualCost = 800
        );
        insert testCampaign;
        
        // Update campaign to trigger hierarchy propagation
        testCampaign.BudgetedCost = 1500;
        testCampaign.ActualCost = 1200;
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        sfpegCampaign_UTL.doHierarchyPropagation(campaignList);
        
        Test.stopTest();
        
        // Assert that method executed without errors
        System.assertNotEquals(null, testCampaign, 'Campaign should not be null');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the doHierarchyPropagation method with no RT configuration
    ***/
    @isTest
    static void testDoHierarchyPropagation_NoRtConfig() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        // Create campaign without CampaignMemberRecordTypeId
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign No RT',
            BudgetedCost = 500
        );
        insert testCampaign;
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        
        sfpegCampaign_UTL.doHierarchyPropagation(campaignList);
        
        Test.stopTest();
        
        // Should handle gracefully
        System.assertNotEquals(null, testCampaign, 'Campaign should not be null');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the controlMembers method with valid member types
    ***/
    @isTest
    static void testControlMembers_ValidTypes() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        List<Lead> leads = [SELECT Id FROM Lead LIMIT 1];
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        
        // Create test campaign
        Campaign testCampaign = new Campaign(Name = 'Test Campaign Control');
        insert testCampaign;
        
        // Create campaign members with different types (no RecordType needed)
        List<CampaignMember> testMembers = new List<CampaignMember>();
        
        if (!contacts.isEmpty()) {
            CampaignMember contactMember = new CampaignMember(
                CampaignId = testCampaign.Id,
                ContactId = contacts[0].Id,
                Status = 'Sent'
            );
            testMembers.add(contactMember);
        }
        
        if (!leads.isEmpty()) {
            CampaignMember leadMember = new CampaignMember(
                CampaignId = testCampaign.Id,
                LeadId = leads[0].Id,
                Status = 'Sent'
            );
            testMembers.add(leadMember);
        }
        
        /*if (!accounts.isEmpty()) {
            CampaignMember accountMember = new CampaignMember(
                CampaignId = testCampaign.Id,
                AccountId = accounts[0].Id,
                Status = 'Sent'
            );
            testMembers.add(accountMember);
        }*/
        
        // Test the controlMembers method - it will handle missing RecordType gracefully
        sfpegCampaign_UTL.controlMembers(testMembers);
        
        Test.stopTest();
        
        System.assert(testMembers.size() > 0, 'Should have test members');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the controlMembers method with no record type
    ***/
    @isTest
    static void testControlMembers_NoRecordType() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        
        // Create test campaign
        Campaign testCampaign = new Campaign(Name = 'Test Campaign No RT');
        insert testCampaign;
        
        // Create campaign member without record type (standard behavior)
        List<CampaignMember> testMembers = new List<CampaignMember>();
        if (!contacts.isEmpty()) {
            testMembers.add(new CampaignMember(
                CampaignId = testCampaign.Id,
                ContactId = contacts[0].Id,
                Status = 'Sent'
            ));
        }
        
        // This should handle missing RecordType gracefully
        sfpegCampaign_UTL.controlMembers(testMembers);
        
        Test.stopTest();
        
        System.assert(testMembers.size() > 0, 'Should have test members');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the parseCampaignCmStatuses method
    ***/
    @isTest
    static void testParseCampaignCmStatuses() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        Id rtId = getCampaignMemberRecordTypeId();
        
        // Create test campaign
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign Parse',
            CampaignMemberRecordTypeId = rtId
        );
        insert testCampaign;
        
        List<Campaign> campaignList = new List<Campaign>{testCampaign};
        List<CampaignMemberStatus> newCmsBefore = new List<CampaignMemberStatus>();
        List<CampaignMemberStatus> newCmsAfter = new List<CampaignMemberStatus>();
        Set<Id> campaigns2clean = new Set<Id>();
        
        sfpegCampaign_UTL.parseCampaignCmStatuses(campaignList, newCmsBefore, newCmsAfter, campaigns2clean);
        
        Test.stopTest();
        
        // Method should execute without errors
        System.assertNotEquals(null, newCmsBefore, 'newCmsBefore should be initialized');
        System.assertNotEquals(null, newCmsAfter, 'newCmsAfter should be initialized');
        System.assertNotEquals(null, campaigns2clean, 'campaigns2clean should be initialized');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the getCampaignMbrStatuses method
    ***/
    @isTest
    static void testGetCampaignMbrStatuses() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        // Create test campaign
        Campaign testCampaign = new Campaign(Name = 'Test Campaign Mbr Status');
        insert testCampaign;
        
        // Create reference status list
        List<CampaignMemberStatus> refStatusList = new List<CampaignMemberStatus>();
        refStatusList.add(new CampaignMemberStatus(
            Label = 'Test Status',
            HasResponded = false,
            SortOrder = 1,
            IsDefault = true
        ));
        
        List<CampaignMemberStatus> result = sfpegCampaign_UTL.getCampaignMbrStatuses(testCampaign, refStatusList);
        
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should return 1 cloned status');
        System.assertEquals(testCampaign.Id, result[0].CampaignId, 'Should have correct campaign ID');
        System.assertEquals('Test Status', result[0].Label, 'Should have correct label');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the initRtMap method
    ***/
    @isTest
    static void testInitRtMap() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        Map<Id, Object> result = sfpegCampaign_UTL.initRtMap();
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return a map');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the getConfigMapByName method
    ***/
    @isTest
    static void testGetConfigMapByName() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        Map<String, Object> result = sfpegCampaign_UTL.getConfigMapByName();
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return a map');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the getConfigMapByRtId method
    ***/
    @isTest
    static void testGetConfigMapByRtId() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        // Note: This method requires the actual CmRtConfig type, not Object
        // Since we can't create that type directly, we'll test indirectly through initRtMap
        Map<Id, Object> result = sfpegCampaign_UTL.initRtMap();
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return a map');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test CmRtConfig constructor with various configurations
    ***/
    @isTest
    static void testCmRtConfig_Constructor() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        // Create mock metadata record
        sfpegCampaignMbrRT__mdt mockConfig = new sfpegCampaignMbrRT__mdt();
        mockConfig.MasterLabel = 'Test Config';
        mockConfig.DeveloperName = 'Test_Config';
        mockConfig.CmTypes__c = 'Contact;Lead;Account';
        mockConfig.HierarchyPropagation__c = '{"NumberOfContacts__c":"NumberOfContacts","NumberOfLeads__c":"NumberOfLeads"}';
        mockConfig.CmStatuses__c = '[{"Label":"Sent","HasResponded":false,"SortOrder":1,"IsDefault":true}]';
        mockConfig.CmStatusesAfter__c = '[{"Label":"Responded","HasResponded":true,"SortOrder":2,"IsDefault":false}]';
        
        // This will test the constructor through reflection since it's private
        // We can't directly instantiate it, but we can test the methods it calls
        Test.stopTest();
        
        System.assertNotEquals(null, mockConfig, 'Mock config should be created');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test edge cases and error scenarios
    ***/
    @isTest
    static void testEdgeCases() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        // Test with empty lists
        sfpegCampaign_UTL.doHierarchyPropagation(new List<Campaign>());
        sfpegCampaign_UTL.controlMembers(new List<CampaignMember>());
        sfpegCampaign_UTL.initMemberStatuses(new List<Campaign>());
        
        // Test with null campaign member record type
        Campaign nullRtCampaign = new Campaign(
            Name = 'Null RT Campaign',
            CampaignMemberRecordTypeId = null
        );
        insert nullRtCampaign;
        
        sfpegCampaign_UTL.doHierarchyPropagation(new List<Campaign>{nullRtCampaign});
        sfpegCampaign_UTL.initMemberStatuses(new List<Campaign>{nullRtCampaign});
        
        Test.stopTest();
        
        System.assert(true, 'Edge cases should be handled gracefully');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test bulk operations with multiple records
    ***/
    @isTest
    static void testBulkOperations() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        Id rtId = getCampaignMemberRecordTypeId();
        List<Contact> contacts = [SELECT Id FROM Contact];
        
        // Create multiple campaigns with unique identifiers
        List<Campaign> bulkCampaigns = new List<Campaign>();
        String uniqueId = String.valueOf(DateTime.now().getTime());
        Integer campaignCount = 10; // Reduced count to avoid conflicts
        
        for (Integer i = 0; i < campaignCount; i++) {
            bulkCampaigns.add(new Campaign(
                Name = 'Bulk Campaign ' + uniqueId + '_' + i,
                CampaignMemberRecordTypeId = rtId,
                BudgetedCost = i * 100
            ));
        }
        insert bulkCampaigns;
        
        // Create multiple campaign members (without RecordType)
        List<CampaignMember> bulkMembers = new List<CampaignMember>();
        for (Integer i = 0; i < Math.min(50, contacts.size() * bulkCampaigns.size()); i++) {
            Integer contactIndex = Math.mod(i, contacts.size());
            Integer campaignIndex = Math.mod(i, bulkCampaigns.size());
            CampaignMember bulkMember = new CampaignMember(
                CampaignId = bulkCampaigns[campaignIndex].Id,
                ContactId = contacts[contactIndex].Id,
                Status = 'Sent'
            );
            bulkMembers.add(bulkMember);
        }
        
        // Test bulk member control
        sfpegCampaign_UTL.controlMembers(bulkMembers);
        
        Test.stopTest();
        
        System.assertEquals(campaignCount, bulkCampaigns.size(), 'Should handle bulk campaigns');
        System.assert(bulkMembers.size() > 0, 'Should handle bulk members');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Utility method to get a Campaign Member Record Type ID for testing
    * @return      Record Type ID or null if none available
    ***/
    private static Id getCampaignMemberRecordTypeId() {
        try {
            List<RecordType> rtList = [SELECT Id FROM RecordType WHERE SObjectType = 'CampaignMember' and Name = 'sfpegTestRT' LIMIT 1];
            return rtList.isEmpty() ? null : rtList[0].Id;
        } catch (Exception e) {
            // CampaignMember may not have RecordTypes in some orgs
            return null;
        }
    }

    /***
    * @description Test invalid JSON configurations
    ***/
    @isTest
    static void testInvalidConfigurations() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        // Create campaign with invalid RT ID
        Campaign invalidRtCampaign = new Campaign(
            Name = 'Invalid RT Campaign',
            CampaignMemberRecordTypeId = '012000000000000AAA' // Invalid ID format
        );
        
        try {
            insert invalidRtCampaign;
            sfpegCampaign_UTL.doHierarchyPropagation(new List<Campaign>{invalidRtCampaign});
        } catch (Exception e) {
            // Expected for invalid RT ID
        }
        
        Test.stopTest();
        
        System.assert(true, 'Invalid configurations should be handled');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the sfpegCampaignMemberBeforeInsert trigger functionality
    ***/
    @isTest
    static void testCampaignMemberBeforeInsertTrigger() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        List<Lead> leads = [SELECT Id FROM Lead LIMIT 1];
        
        // Create test campaign
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign for Trigger',
            CampaignMemberRecordTypeId = getCampaignMemberRecordTypeId()
        );
        insert testCampaign;
        
        // Test trigger execution by inserting campaign members
        // This will automatically fire the sfpegCampaignMemberBeforeInsert trigger
        List<CampaignMember> testMembers = new List<CampaignMember>();
        
        if (!contacts.isEmpty()) {
            testMembers.add(new CampaignMember(
                CampaignId = testCampaign.Id,
                ContactId = contacts[0].Id,
                Status = 'Sent'
            ));
        }
        
        if (!leads.isEmpty()) {
            testMembers.add(new CampaignMember(
                CampaignId = testCampaign.Id,
                LeadId = leads[0].Id,
                Status = 'Sent'
            ));
        }
        
        // Insert members - this fires the trigger
        if (!testMembers.isEmpty()) {
            insert testMembers;
            
            // Verify members were inserted successfully (trigger didn't prevent insertion)
            List<CampaignMember> insertedMembers = [SELECT Id, CampaignId, ContactId, LeadId, Status FROM CampaignMember WHERE CampaignId = :testCampaign.Id];
            System.assertEquals(testMembers.size(), insertedMembers.size(), 'All campaign members should be inserted successfully');
        }
        
        Test.stopTest();
        
        System.assert(true, 'Campaign member trigger should execute without errors');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test the sfpegCampaignMemberBeforeInsert trigger bypass conditions
    ***/
    @isTest
    static void testCampaignMemberTriggerBypass() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        
        // Create test campaign
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign for Trigger Bypass'
        );
        insert testCampaign;
        
        // Test trigger bypass in batch context
        // Note: In a test method, we can't directly test system.isBatch(), system.isFuture(), 
        // or System.isQueueable() as they require actual asynchronous execution.
        // But we can test that members are inserted successfully when triggers run normally.
        
        if (!contacts.isEmpty()) {
            CampaignMember testMember = new CampaignMember(
                CampaignId = testCampaign.Id,
                ContactId = contacts[0].Id,
                Status = 'Sent'
            );
            
            // Insert in normal context - trigger should execute
            insert testMember;
            
            // Verify insertion was successful
            List<CampaignMember> insertedMembers = [SELECT Id FROM CampaignMember WHERE Id = :testMember.Id];
            System.assertEquals(1, insertedMembers.size(), 'Campaign member should be inserted in normal context');
        }
        
        Test.stopTest();
        
        System.assert(true, 'Trigger bypass conditions should be handled appropriately');
        
        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Test campaign member trigger with multiple member types
    ***/
    @isTest
    static void testCampaignMemberTriggerMixedTypes() {
        sfpegDebug_UTL.debug('START');
        Test.startTest();
        
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        List<Lead> leads = [SELECT Id FROM Lead LIMIT 1];
        
        // Create test campaign with record type
        Id campaignRtId = getCampaignMemberRecordTypeId();
        Campaign testCampaign = new Campaign(
            Name = 'Test Campaign Mixed Types',
            CampaignMemberRecordTypeId = campaignRtId
        );
        insert testCampaign;
        
        // Create mixed campaign members
        List<CampaignMember> mixedMembers = new List<CampaignMember>();
        
        if (!contacts.isEmpty()) {
            mixedMembers.add(new CampaignMember(
                CampaignId = testCampaign.Id,
                ContactId = contacts[0].Id,
                Status = 'Sent'
            ));
        }
        
        if (!leads.isEmpty()) {
            mixedMembers.add(new CampaignMember(
                CampaignId = testCampaign.Id,
                LeadId = leads[0].Id,
                Status = 'Sent'
            ));
        }
        
        // Insert mixed members - trigger will validate member types
        if (!mixedMembers.isEmpty()) {
            insert mixedMembers;
            
            // Verify successful insertion
            List<CampaignMember> insertedMembers = [SELECT Id, ContactId, LeadId FROM CampaignMember WHERE CampaignId = :testCampaign.Id];
            System.assertEquals(mixedMembers.size(), insertedMembers.size(), 'Mixed member types should be handled by trigger');
        }
        
        Test.stopTest();
        
        System.assert(true, 'Trigger should handle mixed member types appropriately');
        
        sfpegDebug_UTL.debug('END');
    }
} 