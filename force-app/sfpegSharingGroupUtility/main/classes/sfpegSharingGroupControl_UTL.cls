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

    
    //##################################################
    //############ CONFIGURATION VARIABLES #############
    //##################################################

    /***
    * @description  Status Configuration of the Queueable execution process
    ***/
    private StatusConfiguration statusConfig;

    /***
    * @description  Sharing Configuration of the Queueable execution process
    ***/
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
            if (String.isNotBlank(iterHS.mbrActive)) {
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
    private sfpegSharingGroupControl_UTL(final ID lastID, final sfpegMultiSharingGroup_UTL.SharingConfiguration sharingConfig, final Set<String> groupFields, final Set<String> memberFields, StatusConfiguration statusConfig) {
        sfpegDebug_UTL.debug('START for requeuing with lastID',lastID);
        this.creationTS = System.now();
        this.lastRecordId = lastID;
        this.sharingConfig = sharingConfig;
        this.groupFields = groupFields;
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
        sfpegDebug_UTL.fine('Current sharing configuration',this.sharingConfig);
        sfpegDebug_UTL.fine('Current hierarchies',this.sharingConfig?.hierarchies);
        sfpegDebug_UTL.fine('Current groupFields',this.groupFields);
        sfpegDebug_UTL.fine('Current memberFields',this.memberFields);
        sfpegDebug_UTL.fine('Current statusConfig',this.statusConfig);

        DateTime startTS = System.Now();
        Integer waitTime = sfpegQueueable_UTL.getTimeDelta(this.creationTS,startTS);
        sfpegDebug_UTL.fine('WaitTime evaluated',waitTime);

        if (this.sharingConfig.useRT) {
            //this.recordTypeMap = ((SObject)Type.forName(this.sharingConfig.structObject).newInstance()).getSObjectType().getDescribe().getRecordTypeInfosById();
            //Change reversed because generating issue with standard Location object
            this.recordTypeMap = Schema.getGlobalDescribe().get('Schema.' + this.sharingConfig.structObject).getDescribe().getRecordTypeInfosById();
            sfpegDebug_UTL.debug('#RT fetched for Naming',this.recordTypeMap.size());
        }

        // Preparation
        String createQuery = (this.sharingConfig.useRT ? 'SELECT Name,RecordTypeId,' : 'SELECT Name,')
                            + this.sharingConfig.structExtID + ',' + this.sharingConfig.structStatus + ',' + String.join(this.groupFields,',')
                            + ' FROM ' + this.sharingConfig.structObject
                            + ' WHERE Id > :lastRecordId ORDER BY Id LIMIT :maxIDs';              
        sfpegDebug_UTL.fine('Structure Query template built',createQuery);

        Map<String, Object> queryParams = new Map<String, Object>{
            'lastRecordId'  => this.lastRecordId,
            'maxIDs'        => this.statusConfig.maxIDs};
        sfpegDebug_UTL.fine('Query Params init',queryParams);

        // Structure Fetch
        Map<ID,SObject> structureMap = new Map<ID,SObject>(Database.queryWithBinds(createQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.debug('#Structures fetched',structureMap.size());
        if (structureMap.size() == 0) {
            sfpegDebug_UTL.debug('END / All Structures processed');
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

        Map<ID,Group> groupMap = new Map<ID,Group>([SELECT Name, DeveloperName FROM Group WHERE Id IN :groupIDs ]);
        sfpegDebug_UTL.debug('#Groups fetched',groupMap.size());

        // Structure Analysis
        List<Group> groups2update = new List<Group>();
        String lastStructureID = null;
        for (SObject iterS : structureMap.values()) {
            sfpegDebug_UTL.fine('Analysing structure', iterS);
            lastStructureID = (String) iterS.Id;

            List<String> iterDetails = new List<String>();
            for (sfpegMultiSharingGroup_UTL.SharingHierarchy iterHV : this.sharingConfig.hierarchies.values()) {
                sfpegDebug_UTL.finest('Analysing hierarchy',iterHV);

                String iterNR = getNameRoot(iterHV,iterS);
                sfpegDebug_UTL.finest('Name root init',iterNR);

                String fieldDetails = checkGroup(iterHV.structLocal,iterNR + '_L', this.sharingConfig.structStatus, iterHV, iterS, groupMap, groups2update);
                if (fieldDetails != null) iterDetails.add(fieldDetails);
                fieldDetails = checkGroup(iterHV.structUp,iterNR + '_U', this.sharingConfig.structStatus, iterHV, iterS, groupMap, groups2update);
                if (fieldDetails != null) iterDetails.add(fieldDetails);
                fieldDetails = checkGroup(iterHV.structDown,iterNR + '_D', this.sharingConfig.structStatus, iterHV, iterS, groupMap, groups2update);
                if (fieldDetails != null) iterDetails.add(fieldDetails);
            }

            iterS.put(this.statusConfig.statusDate,startTS);
            iterS.put(this.statusConfig.statusOK, iterDetails.isEmpty());
            if (!iterDetails.isEmpty()) {
                sfpegDebug_UTL.finest('Requesting Structure reevalyation', iterS);
                iterS.put(this.sharingConfig.structStatus, true);
            }
            iterS.put(this.statusConfig.statusDetails,String.join(iterDetails,'\n'));
            sfpegDebug_UTL.finest('Structure updated', iterS);
        }
        sfpegDebug_UTL.debug('All structures processed --> #Groups to update',groups2update.size());
        
        // Updating
        update structureMap.values();
        sfpegDebug_UTL.debug('Structures updated');
        if (!groups2update.isEmpty()) {
            sfpegDebug_UTL.debug('Updating Groups',groups2update);
            update groups2update;
            sfpegDebug_UTL.debug('Groups updated');
        }

        // Process logging and Requeueing
        sfpegDebug_UTL.finest('#Structures processed',structureMap.size());
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
            return new sfpegSharingGroupControl_UTL(lastStructureID, this.sharingConfig, this.groupFields, this.memberFields, this.statusConfig);
        }
    }

    private String checkGroup(final String groupField, final String groupName, final String statusField, final sfpegMultiSharingGroup_UTL.SharingHierarchy sharingDesc, SObject structure, final Map<ID,Group> groupMap, List<Group> groups2update) {
        sfpegDebug_UTL.fine('START with structure', structure.Id);
        sfpegDebug_UTL.fine('for group name', groupName);

        String groupId = (String)structure.get(groupField);
        if (String.isBlank(groupId)) {
            if ((Boolean)structure.get(statusField)) {
                sfpegDebug_UTL.fine('END OK / No group set, Init pending');
                return null;
            }
            sfpegDebug_UTL.warn('END KO / No group set, Init missing');
            return 'Group not init: ' + groupField;
        }
        sfpegDebug_UTL.fine('Analysing group ID ',groupId);

        if (groupMap.containsKey(groupId)) {
            Group groupRcd = groupMap.get(groupId);
            sfpegDebug_UTL.fine('Group found with name',groupRcd?.Name);
            groupMap.remove(groupId);
            if (groupRcd.Name == groupName) {
                sfpegDebug_UTL.fine('END OK / Group found with correct name');
                return null;
            }
            groupRcd.Name = groupName;
            groups2update.add(groupRcd);
            sfpegDebug_UTL.warn('END KO / Group found with incorrect name');
            return 'Group with incorrect name: ' + groupId + ' for ' + groupField;
        }
        sfpegDebug_UTL.warn('END KO / Group not found or with duplicate use');
        structure.put(groupField,null);
        return 'Invalid Group ID set: ' + groupId + ' for ' + groupField;
    }

    private String getNameRoot(final sfpegMultiSharingGroup_UTL.SharingHierarchy sharingDesc, SObject structure) {
        sfpegDebug_UTL.fine('START for hierarchy',sharingDesc);

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
        sfpegDebug_UTL.fine('END with NameRoot initialized', nameRoot);
        return nameRoot;
    }
}