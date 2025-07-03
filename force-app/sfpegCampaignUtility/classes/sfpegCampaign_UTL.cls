/***
* @description  Utility class providing various business logic
*               for the Campaign and Campaign Member objects.
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

public without sharing class sfpegCampaign_UTL {
    
    static final private String RT_ID = 'RecordTypeId';
    static final private String ACCOUNT_ID = 'AccountId';

    /***
    * @description Custom Setting to dynamically influence Campaign and Campaign MemberBusiness Logic
    *              (mainly Trigger feature bypasses).
    ***/
    static final public sfpegCampaignSettings__c SETTING = sfpegCampaignSettings__c.getInstance();

    /***
    * @description Static Map providing the configuration for each Campaign RT. 
    ***/
    static final private Map<ID,CmRtConfig> RT_CONFIG_MAP = initRtMap();

    /***
    * @description Method to copy some standard Campaign local count and budget numeric
    *              fields into other fields to support hierarchy rollups based on the
    *              Campaign Member record type set on the Campaign (CampaignMemberRecordTypeId field).
    *              It is meant to be used in the before update trigger, the input Campaign list
    *              records being possibly updated by the method.
    * @param       newList   list of campaigns newly updated
    * @exception   none specific.      
    ***/
    public static void doHierarchyPropagation(list<Campaign> newList) {
        sfpegDebug_UTL.debug('START with #items',newList.size());

        for (Campaign iterC : newList) {
            sfpegDebug_UTL.fine('Processing Campaign',iterC.Name);
            sfpegDebug_UTL.fine('with CM RT Id',iterC.CampaignMemberRecordTypeId);

            if (String.isBlank(iterC.CampaignMemberRecordTypeId)) {sfpegDebug_UTL.warn('No CampaignMember RT Id set on Campaign',iterC.Name);continue;}
            
            CmRtConfig iterConfig = RT_CONFIG_MAP.get(iterC.CampaignMemberRecordTypeId);
            if (iterConfig == null) {sfpegDebug_UTL.fine('No configuration for CampaignMember RT',iterC.CampaignMemberRecordTypeId);continue;}
            sfpegDebug_UTL.finer('Campaign Member RT Configuration fetched',iterConfig.DeveloperName);

            if (iterConfig.hierarchyFieldMap == null) {sfpegDebug_UTL.finer('No Field Value Propagation configured for CM RT',iterConfig.DeveloperName);continue;}
            sfpegDebug_UTL.finer('Propagating field values',iterConfig.hierarchyFieldMap);

            for (String iterF : iterConfig.hierarchyFieldMap.keySet()) {iterC.put(iterF, iterC.get(iterConfig.hierarchyFieldMap.get(iterF)));}
            sfpegDebug_UTL.finest('Campaign updated',iterC);
        }

        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description Method to control the member Object types of the Campaign members
    *              based on the Campaign Member record type.
    *              It is meant to be used in the before insert trigger, error handling being done
    *              being set on the input Campaign Member records when control fails..
    * @param       newCmList   list of campaign members newly created
    * @exception   none specific.      
    ***/
    public static void controlMembers(list<CampaignMember> newCmList) {
        sfpegDebug_UTL.debug('START with #items',newCmList.size());

        for (CampaignMember iterCm : newCmList) {
            sfpegDebug_UTL.fine('Processing Campaign Member',iterCm.Name);
            sfpegDebug_UTL.fine('with RT Id',(iterCm.isSet(RT_ID)?iterCm.get(RT_ID):null));

            //if (String.isBlank(iterCm.RecordTypeId)) {sfpegDebug_UTL.warn('No RT Id set on CampaignMember',iterCm.Name);continue;}
            if (!iterCm.isSet(RT_ID)) {sfpegDebug_UTL.warn('No RT Id set on CampaignMember',iterCm.Name);continue;}
            
            //CmRtConfig iterConfig = RT_CONFIG_MAP.get(iterCm.RecordTypeId);
            CmRtConfig iterConfig = RT_CONFIG_MAP.get((ID)(iterCm.get(RT_ID)));
            //if (iterConfig == null) {sfpegDebug_UTL.fine('No configuration for CampaignMember RT',iterCm.RecordTypeId);continue;}
            if (iterConfig == null) {sfpegDebug_UTL.fine('No configuration for CampaignMember RT',(ID)(iterCm.get(RT_ID)));continue;}
            sfpegDebug_UTL.finer('Campaign Member RT Configuration fetched',iterConfig.DeveloperName);

            if (iterConfig.allowedMbrObjects == null) {
                sfpegDebug_UTL.finer('No Campaign Member type allowed for CM RT',iterConfig.DeveloperName);
                iterCm.addError(String.format(System.Label.sfpegCampaignMemberNotAllowed, new List<String>{iterConfig.masterLabel}));
                continue;
            }
            sfpegDebug_UTL.finer('Checking allowed member types',iterConfig.allowedMbrObjects);

            Boolean iterTypeOK = (  ((String.isNotBlank(iterCm.ContactId)) && (iterConfig.allowedMbrObjects.contains('Contact')))
                                    ||  ((String.isNotBlank(iterCm.LeadId)) && (iterConfig.allowedMbrObjects.contains('Lead')))
                                    ||  ((iterCm.isSet(ACCOUNT_ID)) && (iterConfig.allowedMbrObjects.contains('Account'))) );
                                    //||  ((String.isNotBlank(iterCm.AccountId)) && (iterConfig.allowedMbrObjects.contains('Account'))) );
            sfpegDebug_UTL.finer('Member type check OK?',iterTypeOK);
            if (!iterTypeOK) {
                sfpegDebug_UTL.warn('Campaign Member type not allowed',iterConfig.DeveloperName);
                iterCm.addError(String.format(System.Label.sfpegCampaignMemberTypeNotAllowed, new List<String>{iterConfig.masterLabel}));
            }
            else {sfpegDebug_UTL.finest('Campaign Member type allowed');}
        }

        sfpegDebug_UTL.debug('END');
    }


    /***
    * @description  Method to initialize automatically the list of campaign member statuses applicable
    *               to the campaigns being created based on their CampaignMember RecordType ID field value.
    *               It is meant to be used once in the after insert trigger and assumes this value never
    *               changes once set (no after update logic).
    *               Depending on the RecordType, it leverages the CM RT configuration provided by the
    ¨               sfpegCampaignMbrRT__mdt metadata to define the aplicable CampaignMember statuses to 
    *               register for each new Campaign.
    *               The logic is quite complex especially if a new custom default or responded status
    *               value must be added in the list: some statuses need to be created before 
    *               removing the standard default statuses, while others need to be created after
    *               if the same label as a standard one is reused.
    *               This method executes all required insert and delete DMLs required.
    *               This method calls parseCampaignCmStatuses() to analyse the Campaigns.
    * @param        newList   Map by RecordType ID of Maps by Record ID of campaigns records newly created
    * @exception    none specific.      
    ***/

    public static void initMemberStatuses(final List<Campaign> newList) { // NOPMD
        sfpegDebug_UTL.debug('START with #items',newList.size());

        List<CampaignMemberStatus> newCmsBefore = new List<CampaignMemberStatus>();
        List<CampaignMemberStatus> newCmsAfter  = new List<CampaignMemberStatus>();
        Set<ID> campaigns2clean                 = new Set<ID>();

        parseCampaignCmStatuses(newList,newCmsBefore,newCmsAfter,campaigns2clean);
        sfpegDebug_UTL.debug('Campaigns parsed');

        List<CampaignMemberStatus> oldCms = null;
        if (!campaigns2clean.isEmpty()) {
            sfpegDebug_UTL.finest('Campaigns to clean',campaigns2clean);
            oldCms = [SELECT Id FROM CampaignMemberStatus WHERE CampaignID IN :campaigns2clean WITH SYSTEM_MODE];
            sfpegDebug_UTL.debug('#CM statuses to remove',oldCms.size());
            //sfpegDebug_UTL.finest('CM statuses to remove',oldCms);
        }

        if (!newCmsBefore.isEmpty()) {
            sfpegDebug_UTL.debug('Adding new #CM statuses',newCmsBefore.size());
            //sfpegDebug_UTL.finest('CM statuses to adds',newCmsBefore);
            insert newCmsBefore; // NOPMD Bypass CRUD controls
        }

        if ((oldCms != null) && (!newCmsBefore.isEmpty())) {
            sfpegDebug_UTL.debug('Deleting old #CM statuses',oldCms.size());
            delete oldCms; // NOPMD Bypass CRUD controls
        }

        if (!newCmsAfter.isEmpty()) {
            sfpegDebug_UTL.debug('Adding new additional #CM statuses',newCmsAfter.size());
            //sfpegDebug_UTL.finest('Additional CM statuses to add',newCmsAfter);
            insert newCmsAfter; // NOPMD Bypass CRUD controls
        }

        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description  Utility method to parse the provided list of Campaigns to define the 
    *               list of CM Status values to add (as first or second insert) and the 
    *               list of Campaign for which default status values should be removed.
    *               The last 3 input lists are initialized from the input Campaign List
    * @param        campaignList   list of campaigns to parse
    * @param        newCmsBefore   list of CampaignMemberStatuses to add before cleaning
    * @param        newCmsAfter    list of CampaignMemberStatuses to add after cleaning
    * @param        campaigns2clean   set of Campaign IDs to clean
    * @exception    none specific.
    ***/
    @TestVisible
    private static void parseCampaignCmStatuses(    final List<Campaign> campaignList, // NOPMD
                                                    List<CampaignMemberStatus> newCmsBefore, // NOPMD
                                                    List<CampaignMemberStatus> newCmsAfter, // NOPMD
                                                    Set<ID> campaigns2clean) { // NOPMD
        sfpegDebug_UTL.fine('START for #Campaigns',campaignList.size());

        for (Campaign iterC : campaignList) {
            sfpegDebug_UTL.finer('Processing Campaign',iterC.Name);

            if (String.isBlank(iterC.CampaignMemberRecordTypeId)) {sfpegDebug_UTL.warn('No Campaign Member RT Id set on Campaign',iterC.Name);continue;}

            CmRtConfig iterConfig = RT_CONFIG_MAP.get(iterC.CampaignMemberRecordTypeId);
            if (iterConfig == null) {sfpegDebug_UTL.finer('No configuration for CM RT ID',iterC.CampaignMemberRecordTypeId);continue;}
            sfpegDebug_UTL.finer('CampaignMember RT Configuration fetched',iterConfig.DeveloperName);

            if (iterConfig.CmStatuses2add?.size() > 0) {
                sfpegDebug_UTL.finer('Registering #Campaign member statuses',iterConfig.CmStatuses2add.size());
                newCmsBefore.addAll(getCampaignMbrStatuses(iterC,iterConfig.CmStatuses2add));
            }
            if (iterConfig.doCmStatusCleaning) {
                campaigns2clean.add(iterC.Id);
                sfpegDebug_UTL.finer('Campaign cleaning requested');
            }
            if (iterConfig.CmStatuses2addAfter?.size() > 0) {
                sfpegDebug_UTL.finer('Registering other #Campaign member statuses',iterConfig.CmStatuses2addAfter.size());
                newCmsAfter.addAll(getCampaignMbrStatuses(iterC,iterConfig.CmStatuses2addAfter));
            }
        }
        sfpegDebug_UTL.fine('#CM Status registered',newCmsBefore.size());
        sfpegDebug_UTL.fine('#Additional CM Statuses registered',newCmsAfter.size());
        sfpegDebug_UTL.fine('END with #Campaigns to clean registered',campaigns2clean.size());
        return;
    }

    /***
    * @description  Utility method to clone a list of reference CampaignMemberStatus records
    *               coming from configuration into the same list for the provided Campaign.
    * @exception    none specific.
    ***/
    @TestVisible
    private static List<CampaignMemberStatus> getCampaignMbrStatuses(final Campaign campaign, final List<CampaignMemberStatus> refStatusList) {
        sfpegDebug_UTL.finer('START for Campaign',campaign.Name);
        sfpegDebug_UTL.finer('for #Ref statuses',refStatusList.size());

        List<CampaignMemberStatus> statusList = new List<CampaignMemberStatus>();
        for (CampaignMemberStatus iterCms : refStatusList) {
            sfpegDebug_UTL.finest('Registering Campaign Status',iterCms.Label);
            statusList.add(new CampaignMemberStatus(
                CampaignId = campaign.Id,
                HasResponded = iterCms.HasResponded,
                Label = iterCms.Label,
                SortOrder = iterCms.SortOrder,
                isDefault = iterCms.isDefault
            ));
        }
        sfpegDebug_UTL.finer('END with #Statuses',statusList.size());
        return statusList;
    }

    /***
    * @description  Utility method to initialize configuration map per CampaignMember RecordType ID.
    *               Relies on the getConfigMapByName() and getConfigMapByRtId() utility methods
    * @exception    none specific.
    ***/
    @TestVisible
    private static Map<ID,CmRtConfig> initRtMap() {
        sfpegDebug_UTL.debug('START');
        if (RT_CONFIG_MAP != null) {sfpegDebug_UTL.debug('END (init already done)');return RT_CONFIG_MAP;}

        Map<String,CmRtConfig> configMapByName = getConfigMapByName();
        sfpegDebug_UTL.debug('Config fetched for #RTs', configMapByName.size());

        Map<ID,CmRtConfig> configMapByRtID = getConfigMapByRtId(configMapByName);
        sfpegDebug_UTL.debug('END with #RTs', configMapByRtID.size());
        return configMapByRtID;
    }

    /***
    * @description  Utility method to fetch configuration metadata and register them per CampaignMember RecordType DeveloperName
    * @exception    none specific.      
    ***/
    @TestVisible
    private static Map<String,CmRtConfig> getConfigMapByName() {
        sfpegDebug_UTL.finer('START');

        List<sfpegCampaignMbrRT__mdt> configList = new List<sfpegCampaignMbrRT__mdt>(
            [   SELECT MasterLabel,  DeveloperName, CmTypes__c, CmStatuses__c, CmStatusesAfter__c, HierarchyPropagation__c
                FROM sfpegCampaignMbrRT__mdt WITH SYSTEM_MODE]);
        sfpegDebug_UTL.finer('#Items found for CM RT Configuration', configList.size());
            
        Map<String,CmRtConfig> configMapByName = new Map<String,CmRtConfig>();
        for (sfpegCampaignMbrRT__mdt iter : configList) {
            sfpegDebug_UTL.finest('Processing config CM RT DevName', iter.DeveloperName);
            configMapByName.put(iter.DeveloperName, new CmRtConfig(iter));
        }
        sfpegDebug_UTL.finer('END with RTs', configMapByName.keySet());
        return configMapByName;
    }

    /***
    * @description  Utility method to fetch configuration CampaignMember RT IDs and register configuration per RT ID instead of DeveloperName
    * @exception    none specific.      
    ***/
    @TestVisible
    private static Map<ID,CmRtConfig> getConfigMapByRtId(Map<String,CmRtConfig> configMapByName) {
        sfpegDebug_UTL.finer('START');

        List<RecordType> cmRtList = [select DeveloperName FROM RecordType WHERE SobjectType = 'CampaignMember' WITH SYSTEM_MODE];
        sfpegDebug_UTL.finer('#RTs for Campaign Members fetched', cmRtList.size());

        Map<ID,CmRtConfig> configMapByRtID = new Map<ID,CmRtConfig>();
        for (RecordType iter : cmRtList) {
            if (configMapByName.containsKey(iter.DeveloperName)) {
                sfpegDebug_UTL.finest('Registering CM RT Configuration', iter.DeveloperName);
                configMapByRtID.put(iter.Id, configMapByName.get(iter.DeveloperName));
            }
            else {
                sfpegDebug_UTL.finest('Ignoring CM RT', iter.DeveloperName);
            }
        }
        sfpegDebug_UTL.finer('END with RT IDs', configMapByRtID.keySet());
        return configMapByRtID;
    }

    /***
    * @description  Utility subclass to store parsed Campaign Member RT configuration
    * @exception    none specific.      
    ***/
    @TestVisible
    private class CmRtConfig {
        public String masterLabel;              // MasterLabel of the RT
        public String developerName;            // DeveloperName of the RT
        public Set<String> allowedMbrObjects;   // Set of object types (Account, Lead and Or Contact) allowed as Member for the RT
        public List<CampaignMemberStatus> cmStatuses2add; // First set of standard CampaignMember Statuses to add
        public Boolean doCmStatusCleaning;      // Flag to indicate if standard CampaignMember Statuses must be cleaned
        public List<CampaignMemberStatus> cmStatuses2addAfter; // Second set of CampaignMember Statuses to add after cleaning
        public Map<String,String> hierarchyFieldMap; // Map of Campaign field names to propagate within Campaign records for this CampaignMember RT

        /***
        * @description  Constructor to initialize configuration from a custom metadata type sfpegCampaignMbrRT__mdt record.
        *               Relies on initMbrObjects(), initHierarchyFieldMap() and initCmStatuses() utility methods to
        *               parse and store the configuration.
        * @param        config   metadata record fetched from the custom metadata type sfpegCampaignMbrRT__mdt
        * @exception    none specific.      
        ***/
        public CmRtConfig(sfpegCampaignMbrRT__mdt config) { // NOPMD Class length
            sfpegDebug_UTL.finer('START for RT dev name', config.DeveloperName);
            sfpegDebug_UTL.finest('with config', config);

            this.masterLabel = config.MasterLabel;
            this.developerName = config.DeveloperName;

            initHierarchyFieldMap(config);
            initMbrObjects(config);
            initCmStatuses(config);

            sfpegDebug_UTL.finer('END with config',this);
        }

        /***
        * @description  Utility method to parse and store allowed CampaignMember object types
        * @exception    none specific.      
        ***/
        @TestVisible
        private void initMbrObjects(sfpegCampaignMbrRT__mdt config) {
            sfpegDebug_UTL.finest('START with config',config.CmTypes__c);
            if (String.isBlank(config.CmTypes__c)) {
                sfpegDebug_UTL.finest('No Allowed CM types');
            }
            else {
                sfpegDebug_UTL.finest('Parsing allowed CM types',config.CmTypes__c);
                List<String> rawList = config.CmTypes__c.split(';');
                sfpegDebug_UTL.finest('Parsing done',rawList);
                this.allowedMbrObjects = new Set<String>(rawList);
            }
            sfpegDebug_UTL.finest('END with set',this.allowedMbrObjects);
        }

        /***
        * @description  Utility method to parse and store field hierarchy propagation configuration
        * @exception    none specific.      
        ***/
        @TestVisible
        private void initHierarchyFieldMap(sfpegCampaignMbrRT__mdt config) {
            sfpegDebug_UTL.finest('START with config',config.HierarchyPropagation__c);
            if (String.isBlank(config.HierarchyPropagation__c)) {
                sfpegDebug_UTL.finest('No field hierarchy propagation');
            }
            else {
                sfpegDebug_UTL.finest('Parsing field propagation config',config.HierarchyPropagation__c);
                Map<String,Object> rawMap = (Map<String,Object>) JSON.deserializeUntyped(config.HierarchyPropagation__c); 
                sfpegDebug_UTL.finest('Parsing done',rawMap);
                this.hierarchyFieldMap = new Map<String,String>();
                for (String iter : rawMap.keySet()) {
                    this.hierarchyFieldMap.put(iter,(String)rawMap.get(iter));
                }
            }
            sfpegDebug_UTL.finest('END with map',this.hierarchyFieldMap);
        }

        /***
        * @description  Utility method to parse and store CampaignMember statuses configuration
        * @exception    none specific.      
        ***/
        @TestVisible
        private void initCmStatuses(sfpegCampaignMbrRT__mdt config) {
            sfpegDebug_UTL.finest('START with CM Status',config.CmStatuses__c);
            sfpegDebug_UTL.finest('and CM Status After',config.CmStatusesAfter__c);

            this.doCmStatusCleaning = false;
            if (String.isNotBlank(config.CmStatuses__c)) {
                this.cmStatuses2add = (List<CampaignMemberStatus>) JSON.deserialize(config.CmStatuses__c, List<CampaignMemberStatus>.class);
                sfpegDebug_UTL.finest('CmStatuses set', this.CmStatuses2add);
            }
            if (String.isNotBlank(config.CmStatusesAfter__c)) {
                this.cmStatuses2addAfter = (List<CampaignMemberStatus>) JSON.deserialize(config.CmStatusesAfter__c, List<CampaignMemberStatus>.class);
                sfpegDebug_UTL.finest('CmStatusesAfter set', this.CmStatuses2addAfter);
                this.doCmStatusCleaning = true;
            }
            sfpegDebug_UTL.finest('END with CM Statuses to clean?',this.doCmStatusCleaning);
        }
    }
}