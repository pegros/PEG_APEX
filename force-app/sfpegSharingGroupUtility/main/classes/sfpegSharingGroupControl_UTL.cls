/***
* @description  Utility Class for the control of the public groups associated to a
*               hierarchy of structure records and user structure memberships records,
*               as generated via the sfpegMultiSharingGroup_UTL asynch process.
*               It controls the naming of the public groups and the minimum number
*               of members in the groups.
* @author       P-E GROS
* @date         March 2024
* @see sfpegMultiSharingGroup_UTL
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

public with sharing class sfpegSharingGroupControl_UTL {

    //##################################################
    //################ DATA STRUCTURES #################
    //##################################################

    /***
    * @description  Specific Subclass to manage configuration parameters of the Queueable process status
    ***/ 
    public class StatusConfiguration {
        public String className;        // Name of the queueable process (dependent on configuration provided), for logs
        public String statusOK;         // API Name of the Boolean status field on the Structure object
        public String statusDetails;    // API Name of the Text field on the Structure object to provide details about the issues
        public String statusDate;       // API Name of the Timestamp field to track the last status review. 
        public Integer maxIDs = 100;    // Max number of Structure objects analysed at each queueable iteration.
    }
    
    /***
    * @description  private enum categorizing the 3 types of Public Groups
    ***/ 
    private enum GroupType {LOCAL, UP, DOWN}


    //##################################################
    //############ CONFIGURATION VARIABLES #############
    //##################################################

    /***
    * @description  Status Configuration of the Queueable execution process
    ***/
    @TestVisible
    private StatusConfiguration statusConfig;

    /***
    * @description  Sharing Configuration of the Queueable execution process
    ***/
    @TestVisible
    private sfpegMultiSharingGroup_UTL.SharingConfiguration sharingConfig;

    /***
    * @description  Set of Public Group identification fields on the Structure object
    ***/
    private Set<String> groupFields;

    /***
    * @description  Set of active membership fields on the Membership object
    ***/
    private Set<String> memberFields;

    /***
    * @description  Set of active membership fields on the Structure object
    ***/
    private Set<String> groupMemberFields;

    /***
    * @description  Textual detail field on the Structure object to provide 
    *               more details about the problem encountered.
    ***/
    private String statusDetails;

    /***
    * @description  Timestamp of the last status review. 
    ***/
    private String statusDate;

    /***
    * @description  Record Types of the current Structure object
    ***/
    private Map<Id,Schema.RecordTypeInfo> recordTypeMap;


    //##############################################
    //############ ITERATION VARIABLES #############
    //##############################################

    /***
    * @description  This variable registers the dateTime at which the queuable
    *               job was created. It enables to track wait time and check
    *               if new modifications have been done on processed Structures
    *               before upserting them.
    ***/     
    private DateTime creationTS;

    /***
    * @description  This variable registers the last Structure ID processed by the 
    *               previous queuable job (upon requeuing). It to progressively 
    *               process all Structure records.
    ***/     
    private String lastRecordId = '';


    //#########################################
    //############ CONSTRUCTORS ###############
    //#########################################

    /***
    * @description	Standard public constructor used to launch the Queueable process.
    ***/
    public sfpegSharingGroupControl_UTL(final sfpegMultiSharingGroup_UTL.SharingConfiguration sharingConfig, StatusConfiguration statusConfig) {
        sfpegDebug_UTL.debug('START standard init');
        this.creationTS = System.now();

        if (sharingConfig == null) {
            sfpegDebug_UTL.error('END KO / Missing sharing config');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided SharingConfiguration parameter is null');
            throw error;
        }
        else if ((sharingConfig.hierarchies == null) || (sharingConfig.hierarchies.isEmpty())) {
            sfpegDebug_UTL.error('END KO / Missing sharing config hierarchy');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided SharingConfiguration parameter is missing hierarchy map property');
            throw error;
        }
        else if (statusConfig == null) {
            sfpegDebug_UTL.error('END KO / Missing status config');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided StatusConfiguration parameter is null');
            throw error;
        }

        this.sharingConfig = sharingConfig;
        this.groupFields = new Set<String>(); 
        this.groupMemberFields = new Set<String>();
        this.memberFields = new Set<String>();
        for (sfpegMultiSharingGroup_UTL.SharingHierarchy iterHS : this.sharingConfig.hierarchies.values()) {
            sfpegDebug_UTL.finest('Analysing hierarchy ',iterHS);
            if (String.isNotBlank(iterHS.structLocal) && String.isNotBlank(iterHS.structUp) && String.isNotBlank(iterHS.structDown)) {
                this.groupFields.add(iterHS.structLocal);
                this.groupFields.add(iterHS.structUp);
                this.groupFields.add(iterHS.structDown);
            }
            else {
                sfpegDebug_UTL.error('END KO / Missing group ID property in hierarchy configuration');
                Exception error = new System.NullPointerException();
                error.setMessage('Provided SharingConfiguration hierarchy parameter misses group field configuration');
                throw error;
            }

            if (iterHS.structMbrs != null) {
                this.groupMemberFields.addAll(iterHS.structMbrs);
            }
            else if (String.isNotBlank(iterHS.mbrActive)) {
                this.memberFields.add(iterHS.mbrActive);
            }
            else {
                sfpegDebug_UTL.error('END KO / Missing active membership property in hierarchy configuration');
                Exception error = new System.NullPointerException();
                error.setMessage('Provided SharingConfiguration hierarchy parameter misses active membership field configuration');
                throw error;
            }
        }
        this.statusConfig = statusConfig;

        sfpegDebug_UTL.debug('END standard init');
    }

    /***
    * @description  Private Constructor used internally by the Queueable process to
    *               requeue itself when there are still elements to process.
    ***/
    @TestVisible
    private sfpegSharingGroupControl_UTL(final ID lastID, final sfpegMultiSharingGroup_UTL.SharingConfiguration sharingConfig, final Set<String> groupFields, final Set<String> groupMemberFields, final Set<String> memberFields, StatusConfiguration statusConfig) {
        sfpegDebug_UTL.debug('START for requeuing with lastID',lastID);
        this.creationTS = System.now();
        this.lastRecordId = lastID;
        this.sharingConfig = sharingConfig;
        this.groupFields = groupFields;
        this.groupMemberFields = groupMemberFields;
        this.memberFields = memberFields;
        this.statusConfig = statusConfig;
        sfpegDebug_UTL.debug('END for requeuing');
    }


    //##########################################
    //########### EXECUTION LOGIC ##############
    //##########################################
    
    /***
    * @description  Main execute method of the Queuable process.
    *               It basically looks for Structure records and operates a check
    *               on them before requeuing, passing the Id of the last processed
    *               record to the next iteration.
    * @return       sfpegSharingGroup_UTL Next execution context to be executed in new enqueued process
    *               (null if end of processing reached)
    * @exception    None special (all catched and logged).
    ***/     
    public sfpegSharingGroupControl_UTL execute(){
        sfpegDebug_UTL.info('START with lastRecordId',this.lastRecordId);
        sfpegDebug_UTL.finest('Current sharing configuration',this.sharingConfig);
        sfpegDebug_UTL.finest('Current hierarchies',this.sharingConfig?.hierarchies);
        sfpegDebug_UTL.finest('Current groupFields',this.groupFields);
        sfpegDebug_UTL.finest('Current groupMemberFields',this.groupMemberFields);
        sfpegDebug_UTL.finest('Current memberFields',this.memberFields);
        sfpegDebug_UTL.finest('Current statusConfig',this.statusConfig);

        DateTime startTS = System.Now();
        Integer waitTime = sfpegQueueable_UTL.getTimeDelta(this.creationTS,startTS);
        sfpegDebug_UTL.finest('WaitTime evaluated',waitTime);

        if (this.sharingConfig.useRT) {
            sfpegDebug_UTL.finer('Fetching RTs for structObject',this.sharingConfig.structObject);
            this.recordTypeMap = ((SObject)Type.forName('Schema.' + this.sharingConfig.structObject).newInstance()).getSObjectType().getDescribe().getRecordTypeInfosById();
            //Change reversed because generating issue with standard Location object
            //this.recordTypeMap = Schema.getGlobalDescribe().get(this.sharingConfig.structObject).getDescribe().getRecordTypeInfosById();
            sfpegDebug_UTL.finer('#RT fetched for Naming',this.recordTypeMap.size());
        }

        // Preparation
        String createQuery = (this.sharingConfig.useRT ? 'SELECT Name,RecordTypeId,' : 'SELECT Name,')
                            + this.sharingConfig.structExtID + ',' + this.sharingConfig.structParentId + ',' + this.sharingConfig.structStatus + ',' + String.join(this.groupFields,',')
                            + ' FROM ' + this.sharingConfig.structObject
                            + ' WHERE Id > :lastRecordId ORDER BY Id LIMIT :maxIDs';              
        sfpegDebug_UTL.finest('Structure Query template built',createQuery);

        Map<String, Object> queryParams = new Map<String, Object>{
            'lastRecordId'  => this.lastRecordId,
            'maxIDs'        => this.statusConfig.maxIDs};
        sfpegDebug_UTL.finest('Query Params init',queryParams);

        // Structure Fetch
        Map<ID,SObject> structureMap = new Map<ID,SObject>(Database.queryWithBinds(createQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.debug('#Structures fetched',structureMap.size());
        if (structureMap.size() == 0) {
            sfpegDebug_UTL.info('END / All Structures processed');
            return null;
        }

        // Groups fetch
        Set<String> groupIDs = new Set<String>();
        for (SObject iter : structureMap.values()) {
            for (String iterG : this.groupFields) {
                groupIds.add((String)iter.get(iterG));
            }
        }
        sfpegDebug_UTL.debug('#Group IDs identified ', groupIds.size());
        sfpegDebug_UTL.finest('Groups IDs',groupIds);

        Map<ID,Group> groupMap = new Map<ID,Group>([SELECT Name, DeveloperName FROM Group WHERE Id IN :groupIDs ]);
        sfpegDebug_UTL.debug('#Groups fetched',groupMap.size());

        AggregateResult[] groupMbrCounts = [SELECT count(Id) NBR, GroupId FROM GroupMember WHERE GroupId IN :groupIDs GROUP BY GroupId];
        sfpegDebug_UTL.debug('#Group member counts fetched',groupMbrCounts.size());
        Map<ID,Integer> groupMbrMap = new Map<ID,Integer>();
        for (AggregateResult iter : groupMbrCounts) {
            groupMbrMap.put((ID)iter.get('GroupId'),(Integer)iter.get('NBR'));
        }
        sfpegDebug_UTL.debug('#Group member counts indexed',groupMbrMap.size());


        // Structure Analysis
        List<Group> groups2update = new List<Group>();
        String lastStructureID = null;
        for (SObject iterS : structureMap.values()) {
            sfpegDebug_UTL.finest('Analysing structure', iterS);
            lastStructureID = (String) iterS.Id;

            List<String> iterDetails = new List<String>();
            for (sfpegMultiSharingGroup_UTL.SharingHierarchy iterHV : this.sharingConfig.hierarchies.values()) {
                sfpegDebug_UTL.finest('Analysing hierarchy',iterHV);

                String iterNR = getNameRoot(iterHV,iterS);
                sfpegDebug_UTL.finest('Name root init',iterNR);

                String fieldDetails = checkGroup(iterHV.structLocal,iterNR + '_L', this.sharingConfig.structStatus, iterHV, iterS, groupMap, groups2update);
                if (fieldDetails != null) iterDetails.add(fieldDetails);
                fieldDetails = checkGroupMbrs(iterHV.structLocal,this.sharingConfig.structStatus,iterS,groupMbrMap,GroupType.LOCAL);
                if (fieldDetails != null) iterDetails.add(fieldDetails);

                fieldDetails = checkGroup(iterHV.structUp,iterNR + '_U', this.sharingConfig.structStatus, iterHV, iterS, groupMap, groups2update);
                if (fieldDetails != null) iterDetails.add(fieldDetails);
                fieldDetails = checkGroupMbrs(iterHV.structUp,this.sharingConfig.structStatus,iterS,groupMbrMap,GroupType.UP);
                if (fieldDetails != null) iterDetails.add(fieldDetails);

                fieldDetails = checkGroup(iterHV.structDown,iterNR + '_D', this.sharingConfig.structStatus, iterHV, iterS, groupMap, groups2update);
                if (fieldDetails != null) iterDetails.add(fieldDetails);
                fieldDetails = checkGroupMbrs(iterHV.structDown,this.sharingConfig.structStatus,iterS,groupMbrMap,GroupType.DOWN);
                if (fieldDetails != null) iterDetails.add(fieldDetails);
            }

            iterS.put(this.statusConfig.statusDate,startTS);
            iterS.put(this.statusConfig.statusOK, iterDetails.isEmpty());
            if (!iterDetails.isEmpty()) {
                sfpegDebug_UTL.finest('Requesting Structure reevaluation', iterS);
                iterS.put(this.sharingConfig.structStatus, true);
            }
            iterS.put(this.statusConfig.statusDetails,String.join(iterDetails,'\n'));
            sfpegDebug_UTL.finest('Structure updated', iterS);
        }
        sfpegDebug_UTL.debug('All structures processed --> #Groups to update',groups2update.size());
        
        // Updating
        update structureMap.values();
        sfpegDebug_UTL.debug('#Structures updated',structureMap.size());
        if (!groups2update.isEmpty()) {
            sfpegDebug_UTL.fine('Updating #Groups',groups2update.size());
            sfpegDebug_UTL.finest('Updating Groups',groups2update);
            update groups2update;
            sfpegDebug_UTL.debug('#Groups updated',groups2update.size());
        }

        // Process logging and Requeueing
        sfpegDebug_UTL.finest('#max IDs configured',this.statusConfig.maxIDs);
        if (structureMap.size() < this.statusConfig.maxIDs) {
            sfpegQueueable_UTL.logExecution(    this.statusConfig.className,structureMap.size(),0,
                                                '' + groups2update.size() + ' STOP',
                                                null,waitTime);
            sfpegDebug_UTL.info('END / Last iteration reached');
            return null;
        }
        else {
            sfpegQueueable_UTL.logExecution(    this.statusConfig.className,structureMap.size(),0,
                                                ' ' + groups2update.size(),
                                                null,waitTime);
            sfpegDebug_UTL.info('END / Triggering new iteration');
            return new sfpegSharingGroupControl_UTL(lastStructureID, this.sharingConfig, this.groupFields, this.groupMemberFields, this.memberFields, this.statusConfig);
        }
    }

    //##########################################
    //########### UTILITY METHODS ##############
    //##########################################
    
    /***
    * @description  Private utility method controlling the existence, unicity and naming of a Public Group registered on a Structure
    * @return       String Comment to register on the Structure (null if Status OK)
    ***/  

    private String checkGroup(final String groupField, final String groupName, final String statusField, final sfpegMultiSharingGroup_UTL.SharingHierarchy sharingDesc, SObject structure, final Map<ID,Group> groupMap, List<Group> groups2update) {
        sfpegDebug_UTL.finer('START with structure', structure.Id);
        sfpegDebug_UTL.finer('for group name', groupName);

        String groupId = (String)structure.get(groupField);
        if (String.isBlank(groupId)) {
            if ((Boolean)structure.get(statusField)) {
                sfpegDebug_UTL.finer('END OK / No group set, Init pending on structure ID',structure.Id);
                return null;
            }
            sfpegDebug_UTL.warn('END KO / No group set, Init missing on structure ID',structure.Id);
            return 'Group not init: ' + groupField;
        }
        sfpegDebug_UTL.finer('Analysing group ID ',groupId);

        if (groupMap.containsKey(groupId)) {
            Group groupRcd = groupMap.get(groupId);
            sfpegDebug_UTL.finest('Group found with name',groupRcd?.Name);
            groupMap.remove(groupId);
            if (groupRcd.Name == groupName) {
                sfpegDebug_UTL.finer('END OK / Group found with correct name for ID',groupId);
                return null;
            }
            groupRcd.Name = groupName;
            groups2update.add(groupRcd);
            sfpegDebug_UTL.warn('END KO / Group found with incorrect name for ID', groupId);
            return 'Group with incorrect name: ' + groupId + ' for ' + groupField;
        }
        sfpegDebug_UTL.warn('END KO / Group not found or with duplicate use on Structure ID',structure.Id);
        structure.put(groupField,null);
        return 'Invalid Group ID set: ' + groupId + ' for ' + groupField;
    }


    /***
    * @description  Private utility method controlling the number of members of a Public Group registered on a Structure
    * @return       String Comment to register on the Structure (null if Status OK)
    ***/  
    private String checkGroupMbrs(final String groupField, final String statusField, SObject structure, final Map<ID,Integer> groupMbrMap, final GroupType type) {
        sfpegDebug_UTL.finer('START with structure', structure.Id);
        sfpegDebug_UTL.finer('for group name', groupField);

        String groupId = (String)structure.get(groupField);
        if (String.isBlank(groupId)) {
            sfpegDebug_UTL.finer('END OK / Ignoring null Group ID on structure ID',structure.Id);
            return null;
        }
        sfpegDebug_UTL.finer('Analysing group ID ',groupId);

        if (groupMbrMap.containsKey(groupId)) {
            Integer mbrCount = groupMbrMap.get(groupId);
            sfpegDebug_UTL.finest('Group has #members',mbrCount);
            if (type == GroupType.UP) {
                if (structure.isSet(this.sharingConfig.structParentId) && String.isNotBlank((String)(structure.get(this.sharingConfig.structParentId)))) {
                    sfpegDebug_UTL.finest('Structure has parent');
                    if (mbrCount != 2) {
                        sfpegDebug_UTL.warn('END KO / With parent, UP Group should have 2 members',groupId);
                        structure.put(this.sharingConfig.structStatus, true);
                        return 'UP Group ' + groupId + ' (' + groupField + ') should have 2 members';
                    }
                }
                else {
                    sfpegDebug_UTL.fine('Structure has no parent');
                    if (mbrCount != 1) {
                        sfpegDebug_UTL.warn('END KO / Without parent, UP Group should have 1 member',groupId);
                        structure.put(this.sharingConfig.structStatus, true);
                        return 'UP Group ' + groupId + ' (' + groupField + ') should have 1 member';
                    }
                }
            }
        }
        else {
            sfpegDebug_UTL.finest('Group has no member');
            if ((Boolean)structure.get(statusField)) {
                sfpegDebug_UTL.finer('END OK / No member available, Init pending on structure ID',structure.Id);
                return null;
            }
            else if (type == GroupType.UP) {
                sfpegDebug_UTL.warn('END KO / UP Group should have at least 1 member',groupId);
                structure.put(this.sharingConfig.structStatus, true);
                return 'UP Group ' + groupId + ' (' + groupField + ') should have min 1 member';
            }
            else if (type == GroupType.DOWN) {
                sfpegDebug_UTL.warn('END KO / DOWN Group should have at least 1 member',groupId);
                structure.put(this.sharingConfig.structStatus, true);
                return 'DOWN Group ' + groupId + ' (' + groupField + ') should have min 1 member';
            }
        }
        sfpegDebug_UTL.finer('END OK');
        return null;
    }

    /***
    * @description  Private utility method to generate the standard name root of Public Groups related to a Structure
    * @return       String standard name root for Public Groups
    ***/  

    private String getNameRoot(final sfpegMultiSharingGroup_UTL.SharingHierarchy sharingDesc, SObject structure) {
        sfpegDebug_UTL.finest('START for hierarchy',sharingDesc);

        String externalId = (String) structure.get(this.sharingConfig.structExtID);
        sfpegDebug_UTL.finest('and Structure External ID',externalId);

        String nameRoot = (String.isNotBlank(sharingDesc.prefix) ? sharingDesc.prefix + '_' : '');
        if ((this.recordTypeMap != null) && (String.isNotBlank((String)structure.get('RecordTypeId')))) {
            sfpegDebug_UTL.finest('Structure RecordType ID fetched', structure.get('RecordTypeId'));
            nameRoot += this.recordTypeMap.get((String)structure.get('RecordTypeId')).getDeveloperName() + '_' + externalId;
        }
        else {
            sfpegDebug_UTL.finest('No Structure RecordType ID');
            nameRoot += '_' + externalId;
        }

        nameRoot += (String.isNotBlank(sharingDesc.suffix) ? '_' + sharingDesc.suffix : '');
        sfpegDebug_UTL.finest('END with NameRoot initialized', nameRoot);
        return nameRoot;
    }
}