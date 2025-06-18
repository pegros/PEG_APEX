/***
* @description  Utility Class for the control of the public groups associated to structure
*               and member records, as generated via the sfpegGroupManagement_UTL asynch process.
*               It controls the naming of the public groups and the minimum number
*               of members in the groups.
* @author       P-E GROS
* @date         March 2024
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

public with sharing class sfpegGroupControl_UTL { // NOPMD bypass naming convention

    //####################################################################################################
    // DATA STRUCTURES
    //####################################################################################################

    /***
    * @description  Specific Subclass to manage configuration parameters of the Queueable control process
    ***/ 
    public class ControlConfiguration {
        public String className;        // Name of the queueable process (dependent on configuration provided), for logs
        public String controlScope;     // Custom WHERE clause to add to standard SOQL template to select structures to control (all controlled by default)
        public String statusOK;         // API Name of the Boolean status field on the Structure object
        public String statusDetails;    // API Name of the Text field on the Structure object to provide details about the issues
        public String statusDate;       // API Name of the Timestamp field to track the last status review. 
        public Integer maxIDs = 100;    // Max number of Structure objects analysed at each queueable iteration.
    }


    //####################################################################################################
    // CONFIGURATION VARIABLES
    //####################################################################################################

    /***
    * @description  Status Configuration of the Queueable execution process
    ***/
    @TestVisible
    private ControlConfiguration controlConfig;

    /***
    * @description  Group Configuration of the Queueable execution process
    ***/
    @TestVisible
    private sfpegGroupManagement_UTL.GlobalConfiguration groupConfig;

    /***
    * @description  Set of Public Group identification fields on the Structure object
    ***/
    private Set<String> groupFields;

    /***
    * @description  Query template to fetch structure objects to be controlled
    ***/
    private String structureQuery;


    //################################################################################################
    // ITERATION VARIABLES
    //################################################################################################

    /***
    * @description  Iteration number of a management process, starting at one.
    *               Automatically incremented each time a new set of records is processed.
    ***/     
    private Integer iteration = 1;

    /***
    * @description  This variable contains information about the current process
    *               execution and enables to log information.
    *               It is usually initiated upon execution start but may be passed
    *               from an earlier execution when processing of a batch of record 
    *               is split into 2 steps because of mixed DML constraints.
    ***/
    @testVisible   
    private sfpegQueueableContext_SVC execContext = null;

    /***
    * @description  This variable registers the dateTime at which the queuable
    *               job was created. It enables to track wait time and check
    *               if new modifications have been done on processed Structures
    *               before upserting them.
    ***/     
    private DateTime creationTS;
  
    /***
    * @description  This variable contains the dateTime of the last SystemModStamp
    *               passed through the lastContext stored on the QueueableLog record.
    *               When processing Structure deletions, only records
    *               deleted after this datetime are considered.
    ***/     
    private DateTime deletionTS = null;

    /***
    * @description  This variable contains the recordId of the last record ID
    *               passed through the lastContext stored on the QueueableLog record.
    *               When processing Structure deletions, only deleted records with
    *               with an ID after this value are considered if they have their SystemModStamp
    *               equal to the deletionTS.
    ***/     
    private ID lastRecordId = null;


    //################################################################################################
    // PROCESS EXECUTION VARIABLES
    //################################################################################################

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

    /***
    * @description  Map of the processed Structures
    ***/
    private Map<Id,SObject> structureMap;

    /***
    * @description  Map of Groups related to the processed Structures
    ***/
    private Map<Id,Group> groupMap;

    /***
    * @description  Map per Group ID of the related Structure ID
    ***/
    private Map<Id,Id> groupStructureMap = new Map<Id,Id>();

    /***
    * @description  List of Groups to update
    ***/
    private List<Group> groups2update = new List<Group>();


    //####################################################################################################
    // CONSTRUCTORS
    //####################################################################################################

    /***
    * @description	Standard public constructor used to launch the Queueable process.
    ***/
    public sfpegGroupControl_UTL(final sfpegGroupManagement_UTL.GlobalConfiguration groupConfig, ControlConfiguration controlConfig) { // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.debug('START standard init');
        this.creationTS = System.now();

        if (groupConfig == null) {
            sfpegDebug_UTL.error('END KO / Missing groupConfig');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided Global Group Configuration parameter is null');
            throw error;
        }
        else if ((groupConfig.groupConfigs == null) || (groupConfig.groupConfigs.isEmpty())) {
            sfpegDebug_UTL.error('END KO / Missing controlConfigs in groupConfig');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided detailed Configuration property in Global Group Configuration is missing');
            throw error;
        }
        else if (controlConfig == null) {
            sfpegDebug_UTL.error('END KO / Missing control config');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided Control Configuration parameter is null');
            throw error;
        }

        this.groupConfig = groupConfig;
        sfpegDebug_UTL.finer('groupConfig registered',this.groupConfig);

        this.groupFields = new Set<String>(); 
        for (sfpegGroupManagement_UTL.GroupConfiguration iterConfig : this.groupConfig.groupConfigs.values()) {
            sfpegDebug_UTL.finest('Analysing configuration ',iterConfig.suffix);

            // Processing Group ID fields
            if (String.isNotBlank(iterConfig.structLocal) ) {
                sfpegDebug_UTL.finest('Registering Local Group ID field',iterConfig.structLocal);
                this.groupFields.add(iterConfig.structLocal);
            }
            else {
                sfpegDebug_UTL.error('END KO / Missing local group ID property in Group configuration',iterConfig);
                Exception error = new System.NullPointerException();
                error.setMessage('Provided GroupConfiguration property misses local group field name');
                throw error;
            }

            if (String.isNotBlank(iterConfig.structUp) ) {
                sfpegDebug_UTL.finest('Registering Upwards Group ID field',iterConfig.structUp);
                this.groupFields.add(iterConfig.structUp);
            }
            else {
                sfpegDebug_UTL.finest('No Upwards Group ID field provided');
            }

            if (String.isNotBlank(iterConfig.structDown) ) {
                sfpegDebug_UTL.finest('Registering Downwards Group ID field',iterConfig.structDown);
                this.groupFields.add(iterConfig.structDown);
            }
            else {
                sfpegDebug_UTL.finest('No Downwards Group ID field provided');
            }
        }
        sfpegDebug_UTL.fine('#Group ID fields extracted',this.groupFields.size());
        sfpegDebug_UTL.finer('Group ID fields extracted',this.groupFields);

        this.controlConfig = controlConfig;
        sfpegDebug_UTL.finer('controlConfig registered',this.controlConfig);

        this.structureQuery = (this.groupConfig.useRT ? 'SELECT Name,RecordTypeId,' : 'SELECT Name,')
                            + this.groupConfig.structKey + ',' + this.groupConfig.structStatus + ','
                            + String.join(this.groupFields,',')
                            + ' FROM ' + this.groupConfig.structObject
                            + ' WHERE '
                            + (String.isBlank(this.controlConfig.controlScope) ? '' : this.controlConfig.controlScope + ' AND ')
                            + 'Id > :lastRecordId ORDER BY Id LIMIT :maxIDs'; 
        sfpegDebug_UTL.finer('Structure query template init',this.structureQuery);

        sfpegDebug_UTL.debug('END standard init');
    }

    /***
    * @description  Private Constructor used internally by the Queueable process to
    *               requeue itself when there are still elements to process.
    ***/
    @TestVisible
    private sfpegGroupControl_UTL(final sfpegGroupManagement_UTL.GlobalConfiguration groupConfig, ControlConfiguration controlConfig, final Set<String> groupFields, final String structureQuery, final Integer iteration, final ID lastRecordId) {  // NOPMD bypass long parameter list
        sfpegDebug_UTL.debug('START for requeuing iteration',iteration);
        this.creationTS     = System.now();
        this.groupConfig    = groupConfig;
        this.controlConfig  = controlConfig;
        this.groupFields    = groupFields;
        this.structureQuery = structureQuery;
        this.iteration      = iteration;
        this.lastRecordId   = lastRecordId;
        sfpegDebug_UTL.debug('END for requeuing');
    }


    //####################################################################################################
    // EXECUTION LOGIC
    //####################################################################################################
    
    /***
    * @description  Main execute method of the Queuable process.
    *               It basically looks for Structure records and operates a check
    *               on them before requeuing, passing the Id of the last processed
    *               record to the next iteration.
    * @return       sfpegGroupControl_UTL Next execution context to be executed in new enqueued process
    *               (null if end of processing reached)
    * @exception    None special (all catched and logged).
    ***/     
    public sfpegGroupControl_UTL execute(){  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.info('START iteration',this.iteration);
        sfpegDebug_UTL.fine('Current lastRecordId',this.lastRecordId);
        sfpegDebug_UTL.finest('Current groupConfig',this.groupConfig);
        sfpegDebug_UTL.finest('Current groupConfig details',this.groupConfig?.groupConfigs);
        sfpegDebug_UTL.finest('Current controlConfig',this.controlConfig);
        sfpegDebug_UTL.finest('Current groupFields',this.groupFields);
        sfpegDebug_UTL.finest('Current structureQuery',this.structureQuery);

        this.execContext = new sfpegQueueableContext_SVC(this.controlConfig.className,this.iteration, this.creationTS);
        sfpegDebug_UTL.finer('New context init',this.execContext);

        // Check if we're within the allowed ratio of DailyAsyncApexExecutions
        if (!sfpegQueueable_UTL.isWithinExecutionRatio()) {
            execContext.logExecutionAbort('STOP: Daily queueable limit reached');
            sfpegDebug_UTL.warn('END / Queueable limit reached');
            return null;
        }
        
        if (this.groupConfig.useRT) {
            sfpegDebug_UTL.finest('Group Naming with RT');
            this.recordTypeMap = ((SObject)Type.forName('Schema.' + this.groupConfig.structObject).newInstance()).getSObjectType().getDescribe().getRecordTypeInfosById();
        }

        // Structure Fetch
        Map<String, Object> queryParams = new Map<String, Object>{
            'lastRecordId'  => this.lastRecordId,
            'maxIDs'        => this.controlConfig.maxIDs};
        sfpegDebug_UTL.finest('Query Params init',queryParams);

        this.structureMap = new Map<ID,SObject>(Database.queryWithBinds(this.structureQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.debug('#Structures fetched',this.structureMap.size());
        if (structureMap.size() == 0) {
            execContext.logExecutionEnd(null);
            sfpegDebug_UTL.info('END / All Structures processed');
            return null;
        }

        // Groups identification and fetch
        Set<ID> groupIDs = new Set<ID>();
        for (SObject iter : this.structureMap.values()) {
            for (String iterField : this.groupFields) {
                groupIds.add((ID)iter.get(iterField));
                this.groupStructureMap.put((ID)iter.get(iterField),(ID)iter.Id);
            }
        }
        sfpegDebug_UTL.debug('#Group IDs identified', groupIds.size());
        sfpegDebug_UTL.finest('Groups IDs',groupIds);
        sfpegDebug_UTL.debug('#Group Mapping init', this.groupStructureMap.size());
        sfpegDebug_UTL.finest('Group Mapping init', this.groupStructureMap);

        this.groupMap = new Map<ID,Group>([SELECT Name, DeveloperName FROM Group WHERE Id IN :groupIDs ]);
        sfpegDebug_UTL.debug('#Groups fetched',this.groupMap.size());

        // Structure Analysis
        String lastStructureID = null;
        DateTime startTS = System.now();
        for (SObject iterRecord : structureMap.values()) {
            sfpegDebug_UTL.finer('Analysing structure', iterRecord.Id);
            sfpegDebug_UTL.finer('Structure data fetched', iterRecord);
            this.lastRecordId = iterRecord.Id;

            List<String> iterDetails = new List<String>();
            for (sfpegGroupManagement_UTL.GroupConfiguration iterConfig : this.groupConfig.groupConfigs.values()) {
                sfpegDebug_UTL.finest('Analysing configuration ',iterConfig.suffix);

                String iterNR = getNameRoot(iterConfig,iterRecord);
                sfpegDebug_UTL.finest('Name root init',iterNR);

                String fieldDetails = checkGroup(iterConfig.structLocal,iterNR + iterConfig.localSuffix, iterRecord);
                if (fieldDetails != null) {iterDetails.add(fieldDetails);}

                if (String.isNotBlank(iterConfig.structUp)) {
                    fieldDetails = checkGroup(iterConfig.structUp,iterNR + iterConfig.upSuffix, iterRecord);
                    if (fieldDetails != null) {iterDetails.add(fieldDetails);}
                }

                if (String.isNotBlank(iterConfig.structDown)) {
                    fieldDetails = checkGroup(iterConfig.structDown,iterNR + iterConfig.downSuffix, iterRecord);
                    if (fieldDetails != null) {iterDetails.add(fieldDetails);}
                }
            }

            iterRecord.put(this.controlConfig.statusDate,startTS);
            iterRecord.put(this.controlConfig.statusOK, iterDetails.isEmpty());
            if (!iterDetails.isEmpty()) {
                sfpegDebug_UTL.finest('Requesting Structure reevaluation', iterRecord.Id);
                iterRecord.put(this.groupConfig.structStatus, true);
            }
            iterRecord.put(this.controlConfig.statusDetails,String.join(iterDetails,'\n'));
            sfpegDebug_UTL.finest('Structure updated', iterRecord);
        }
        sfpegDebug_UTL.debug('All structures processed --> #Groups to update',this.groups2update.size());
        sfpegDebug_UTL.debug('Last Record ID processed',this.lastRecordId);
        
        // Updating Group Names
        Set<String> koStructures = new Set<String>();
        if (!this.groups2update.isEmpty()) {
            sfpegDebug_UTL.fine('Updating Groups');
            Database.SaveResult[] groupUpdateResults = database.update(this.groups2update,false);
            sfpegDebug_UTL.finer('Public Groups update executed');

            for(Database.SaveResult iterResult : groupUpdateResults) {
                if (!iterResult.isSuccess()) {
                    sfpegDebug_UTL.finer('Update failed for group',iterResult.getId());
                    ID iterStructID = this.groupStructureMap.get(iterResult.getId());
                    koStructures.add(iterStructID);
                    sfpegDebug_UTL.finest('Structure ID registered as failed',iterStructID);
                    
                    SObject iterStructure = this.structureMap.get(iterStructID);
                    sfpegDebug_UTL.finest('Structure fetched',iterStructure);
                    String iterDetails = (String)(iterStructure.get(this.controlConfig.statusDetails))
                                        + '\n' + iterResult.getErrors();
                    iterStructure.put(this.controlConfig.statusDetails,iterDetails);
                }
            }
            sfpegDebug_UTL.finer('Update results analysed with #Structures KO',koStructures.size());
        }
        else {
            sfpegDebug_UTL.finer('No Public Group update required');
        }
        
        // Updating Structure statuses
        sfpegDebug_UTL.fine('Updating #Structures',this.structureMap.size());
        Database.SaveResult[] structUpdateResults = database.update(this.structureMap.values(),false);
        sfpegDebug_UTL.finer('Structures update executed');

        // Execution logging
        execContext.analyseResults(structUpdateResults);
        execContext.registerKO(koStructures);
        execContext.logExecution('RENAMING',(String)this.lastRecordId);

        // Process Requeueing
        sfpegDebug_UTL.info('END / Triggering new iteration');
        return new sfpegGroupControl_UTL(this.groupConfig, this.controlConfig, this.groupFields, this.structureQuery, this.iteration + 1, this.lastRecordId);
    }


    //####################################################################################################
    // UTILITY METHODS
    //####################################################################################################
    
    /***
    * @description  Private utility method controlling the existence, unicity and naming of a Public Group registered on a Structure
    * @return       String Comment to register on the Structure (null if Status OK)
    ***/  

    private String checkGroup(final String groupField, final String groupName, SObject structure) {
        sfpegDebug_UTL.finer('START with structure', structure.Id);
        sfpegDebug_UTL.finer('for group field', groupField);
        sfpegDebug_UTL.finer('with name', groupName);

        String groupId = (String)structure.get(groupField);
        if (String.isBlank(groupId)) {
            if ((Boolean)structure.get(this.groupConfig.structStatus)) {
                sfpegDebug_UTL.finer('END OK / No group set, Init pending on structure ID',structure.Id);
                return null;
            }
            sfpegDebug_UTL.warn('END KO / No group set, Init missing on structure ID',structure.Id);
            return 'Group not init: ' + groupField;
        }
        sfpegDebug_UTL.finer('Analysing group ID ',groupId);

        if (this.groupMap.containsKey(groupId)) {
            Group groupRcd = groupMap.get(groupId);
            sfpegDebug_UTL.finest('Group found with name',groupRcd?.Name);
            this.groupMap.remove(groupId);
            if (groupRcd?.Name == groupName) {
                sfpegDebug_UTL.finer('END OK / Group found with correct name for ID',groupId);
                return null;
            }
            groupRcd.Name = groupName;
            //groupRcd.DeveloperName = groupName;
            this.groups2update.add(groupRcd);
            sfpegDebug_UTL.warn('END KO / Group found with incorrect name for ID', groupId);
            return 'Group with incorrect name: ' + groupId + ' for ' + groupField;
        }
        sfpegDebug_UTL.warn('END KO / Group not found or with duplicate use on Structure ID',structure.Id);
        structure.put(groupField,null);
        return 'Invalid Group ID set: ' + groupId + ' for ' + groupField;
    }


    /***
    * @description  Private utility method to generate the standard name root of Public Groups related to a Structure
    * @return       String standard name root for Public Groups
    ***/  

    private String getNameRoot(final sfpegGroupManagement_UTL.GroupConfiguration configDesc, SObject structure) {
        sfpegDebug_UTL.finest('START for configuration',configDesc.suffix);

        String externalId = (String) structure.get(this.groupConfig.structKey);
        sfpegDebug_UTL.finest('and Structure External ID',externalId);

        String nameRoot = (String.isNotBlank(configDesc.prefix) ? configDesc.prefix + '_' : '');
        if ((this.recordTypeMap != null) && (String.isNotBlank((String)structure.get('RecordTypeId')))) {
            sfpegDebug_UTL.finest('Structure RecordType ID fetched', structure.get('RecordTypeId'));
            nameRoot += this.recordTypeMap.get((String)structure.get('RecordTypeId')).getDeveloperName() + '_' + externalId;
        }
        else {
            sfpegDebug_UTL.finest('No Structure RecordType ID');
            nameRoot += externalId;
        }

        nameRoot += (String.isNotBlank(configDesc.suffix) ? '_' + configDesc.suffix : '');
        sfpegDebug_UTL.finest('END with NameRoot initialized', nameRoot);
        return nameRoot;
    }
}