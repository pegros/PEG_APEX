/***
* @description  Utility Class for the management of public groups associated to a
*               hierarchy of structure records and user structure memberships records.
*               It behaves exactly as the sfpegSharingGroup_UTL class but enables
*               to manage multiple public group hierarchies for a same structure
*               hierarchy but with different set of user memebers (e.g. all members vs
*               only managers).
* @author       P-E GROS
* @date         Jan 2024
* @see sfpegSharingGroup_UTL
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

public with sharing class sfpegMultiSharingGroup_UTL  {

    //#########################################
    //########## STATIC CONSTANTS #############
    //#########################################

    /***
    * @description  Static constant used to check Group Member of type User (for Structure Members).
    ***/
    private final static String PREFIX_USER = User.sobjecttype.getDescribe().getKeyPrefix();
    
    /***
    * @description  Static constant used to check Group Member of type Public Group (for Structure hierarchy).
    ***/
    private final static String PREFIX_GROUP = Group.sobjecttype.getDescribe().getKeyPrefix();


    //##############################################
    //########### CONFIGURATION CLASSES ############
    //##############################################

    /***
    * @description  Specific Subclasses to manage configuration parameters of the Queueable process
    ***/ 
    public class SharingConfiguration {
        public String   className;                                  // Name of the queueable process (dependent on configuration provided) for logs
        public boolean  useRT           = false;                    // Flag to use Structure RecordType Names in Public Group Names
        public Integer  maxIter         = 5;                        // Max. Number of iterations with no record to process before stopping Queueable
        public Integer  maxIDs          = 5;                        // Max. number of ID fields logged per job iteration in the execution log.
        public Integer  maxCreate       = 200;                      // Max. number of records processed at each iteration (when creating public groups).
        public Integer  maxUpdate       = 50;                       // Max. number of records processed at each iteration (when updating public group memberships).
        public Integer  maxDelete       = 200;                      // Max. number of records processed at each iteration (when deleting public groups).
    
        public String   structObject    = 'Location';               // Hierarchical Structure Object API Name
        public String   structExtID     = 'ExternalId__c';          // API Name of the Structure External ID Field used for Public Group Naming
        public String   structParent    = 'ParentLocation';         // API Name of the Structure Relation to access Data of the Parent Structure
        public String   structChildren  = 'ChildLocations';         // API Name of the Structure Relation to access Data of the Children Structures
        public String   structMembers   = 'LocationUsers__r';       // API Name of the Structure Relation to access Data of the Structure Member Users
        public String   mbrObject       = 'LocationUsers__c';       // Structure User Member Object API Name
        public String   mbrUser         = 'User__c';                // API Name of the User Member Lookup field providing the User ID for a Structure Member
        public String   structStatus    = 'SharingToEval__c';       // API Name of the Structure Boolean field indicating the Structures to process 
        public String   structTS        = 'SharingLastEval__c';     // API Name of the Structure DateTime field storin the last evaluation fo a Structure
    
        public Map<String,SharingHierarchy> hierarchies;            // Map of individual Hierarchy Sharing configurations
    }

    /***
    * @description  Specific Subclass to manage configuration parameters of the Queueable process
    ***/ 
    public class SharingHierarchy {
        public String   prefix          = '';                       // Prefix used for Public Group Names of this sharing hierarchy
        public String   suffix          = '';                       // Suffix used for Public Group Names of this sharing hierarchy
        public String   structLocal     = 'SharingLocal__c';        // API Name of the Structure String field storing the Local Public Group ID
        public String   structUp        = 'SharingUp__c';           // API Name of the Structure String field storing the Upwards Public Group ID
        public String   structDown      = 'SharingDown__c';         // API Name of the Structure String field storing the Downwards Public Group ID
        public String   structMbr       = '';                       // API Name of the Structure Member field storing a Public Group ID for Group Membership
        public String   mbrActive       = 'IsActive__c';            // API Name of the User Member Boolean field indicating if the User Membership is active 
    }


    //##################################################
    //############ CONFIGURATION VARIABLES #############
    //##################################################

    /***
    * @description  Configuration of the Queueable execution process
    ***/
    private SharingConfiguration config;

    /***
    * @description  Set of Public Group identification fields on the Structure object
    ***/
    private Set<String> groupFields;

    /***
    * @description  Set of active membership fields on the Membership object
    ***/
    private Set<String> memberFields;


    //##############################################
    //############ ITERATION VARIABLES #############
    //##############################################

    /***
    * @description  Current iteration of the process. Remains at 0 while 
    *               there are still Structures to process.
    ***/
    private Integer iteration = 0;

    /***
    * @description  If initialized, this record contains the result of a
    *               prior Structure processing, meant to be simply upserted
    *               in the next execution (due to MixedDML constraint).
    ***/       
    private sfpegQueueableLog__c	logRecord = null;

    /***
    * @description  This variable enables to filter the Structure updates
    *               or not when registering a prior Queuable execution.
    ***/     
    private Boolean doFilter = true;

    /***
    * @description  If initialized, this map contains the list of processed
    *               Structures to be updated (structStatus flag and
    *               structTS timestamp in configuration) in the next execution
    *               (due to MixedDML constraint).
    ***/     
    private Map<ID,SObject> structureMap = null;

    /***
    * @description  This variable registers the dateTime at which the queuable
    *               job was created. It enables to track wait time and check
    *               if new modifications have been done on processed Structures
    *               before upserting them.
    ***/     
    private DateTime creationTS;
  
    /***
    * @description  This variable contains the dateTime of the last
    *               passed through the lastContext stored on the QueueableLog record.
    *               When processing Structure deletions, only records
    *               deleted after this datetime are considered.
    ***/     
    private DateTime deletionTS = null;


    //#########################################
    //##### PROCESS EXECUTION VARIABLES #######
    //#########################################

    /***
    * @description  List of Struture records processed by the Queuable instance.
    *               When initialized it contains details about the parent and
    *               children Structures, especially the _L, _U & _D public groups.
    ***/
    private List<SObject> structureList = new List<SObject>(); 

    /***
    * @description  Set of Member IDs per type of Public Group (per API field name on structure), per processed Structure ID.
    ***/
    private Map<ID,Map<String,Set<ID>>> structureGroupSetMap = new Map<ID,Map<String,Set<ID>>>(); 

    /***
    * @description  Once initialized, this map contains the Name and all members
    *               of any Public Group mentioned in the Structures (core, parent and child).
    ***/
    private Map<Id,Group> groupMap = new Map<Id,Group>();

    /***
    * @description  Once initialized, this map contains detaills of all Group memberships (Group Names and ID)
    *               of all Public Groups mentioned in the Structures (core, parent and child).
    ***/
    private Map<Id,List<GroupMember>> membershipMap = new Map<Id,List<GroupMember>>();

    /***
    * @description  During the processing of Structures, this Map collects all the missing
    *               Public Group Members to be added.
    *               GroupMembers are indexed by "GroupId-UserOrGroupId" key (to ensure new
    *               members are created only once).
    ***/    
    private Map<String,GroupMember> gm2add = new Map<String,GroupMember>();

    /***
    * @description  During the processing of Structures, this Set collects all the 
    *               Public Group Members to be removed.
    ***/ 
    private Set<ID> gm2remove = new Set<ID>();


    //#########################################
    //############ CONSTRUCTORS ###############
    //#########################################

    /***
    * @description	Standard public constructor used to launch the Queueable process.
    ***/
    public sfpegMultiSharingGroup_UTL(final SharingConfiguration config) {
        sfpegDebug_UTL.debug('START standard init');
        this.creationTS = System.now();
        this.iteration = 0;

        if (config == null) {
            sfpegDebug_UTL.error('END KO / Missing config');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided SharingConfiguration parameter is null');
            throw error;
        }
        else if ((config.hierarchies == null) || (config.hierarchies.isEmpty())) {
            sfpegDebug_UTL.error('END KO / Missing config hierarchy');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided SharingConfiguration parameter is missing hierarchy map property');
            throw error;
        }
        this.config = config;
        this.groupFields = new Set<String>(); 
        this.memberFields = new Set<String>();
        for (SharingHierarchy iter : this.config.hierarchies.values()) {
            sfpegDebug_UTL.finest('Analysing hierarchy ',iter);
            if (String.isNotBlank(iter.structLocal) && String.isNotBlank(iter.structUp) && String.isNotBlank(iter.structDown)) {
                this.groupFields.add(iter.structLocal);
                this.groupFields.add(iter.structUp);
                this.groupFields.add(iter.structDown);
            }
            else {
                sfpegDebug_UTL.error('END KO / Missing group ID property in hierarchy configuration');
                Exception error = new System.NullPointerException();
                error.setMessage('Provided SharingConfiguration hierarchy parameter misses group field configuration');
                throw error;
            }
            if (String.isNotBlank(iter.structMbr)) {
                this.groupFields.add(iter.structMbr);
            }
            if (String.isNotBlank(iter.mbrActive)) {
                this.memberFields.add(iter.mbrActive);
            }
            else if (String.isBlank(iter.structMbr)) {
                sfpegDebug_UTL.error('END KO / Missing active membership property in hierarchy configuration');
                Exception error = new System.NullPointerException();
                error.setMessage('Provided SharingConfiguration hierarchy parameter misses active membership field configuration');
                throw error;
            }
        }

        sfpegDebug_UTL.debug('END standard init');
    }

    
    /***
    * @description  Private Constructor used internally by the Queueable process to
    *               requeue itself when there are still elements to process.
    ***/
    @TestVisible
    private sfpegMultiSharingGroup_UTL(final dateTime deletionTS, final SharingConfiguration config, final Set<String> groupFields, final Set<String> memberFields) {
        sfpegDebug_UTL.debug('START for requeuing');
        this.creationTS = System.now();
        this.deletionTS = deletionTS;
        this.config = config;
        this.groupFields = groupFields;
        this.memberFields = memberFields;
        this.iteration = 0;
        sfpegDebug_UTL.debug('END for requeuing');
    }

    /***
    * @description  Private Constructor used to register the results of a prior
    *               Structure processing and handle the MixedDML constraint.
    *               This constructor is meant to pass the corresponding
    *               updated sfpegQueueableLog__c record and the list of processed
    *               Structure records with their STRUCTURE_STATUS field
    *               updated.
    *               The execution of a Queueable process initialised
    *               this way only executes 2 upserts on this input.
    ***/
    @TestVisible
    private sfpegMultiSharingGroup_UTL(sfpegQueueableLog__c logRecord, final Map<ID,SObject> structureMap, final Boolean doFilter, final dateTime deletionTS, final SharingConfiguration config, final Set<String> groupFields, final Set<String> memberFields) {
        sfpegDebug_UTL.debug('START for log record registration',logRecord);
        this.creationTS = System.now();
        this.deletionTS = deletionTS;
        this.logRecord = logRecord;
        this.doFilter = doFilter;        
        this.structureMap = structureMap;
        this.config = config;
        this.groupFields = groupFields;
        this.memberFields = memberFields;
        sfpegDebug_UTL.debug('END for log record registration');
    }


    /***
    * @description  Private Constructor used internally by the Queueable process to
    *               reenqueue itself when there is nothing to process.
    *               The queuable process should stop when reaching
    *               iteration MAX_UPDATE_NBR. 
    ***/
    @TestVisible
    private sfpegMultiSharingGroup_UTL(integer iter, dateTime deletionTS, final SharingConfiguration config, final Set<String> groupFields, final Set<String> memberFields) {
        sfpegDebug_UTL.debug('START for iteration',iter);
        this.creationTS = System.now();
        this.deletionTS = deletionTS;
        this.iteration = iter;
        this.config = config;
        this.groupFields = groupFields;
        this.memberFields = memberFields;
        sfpegDebug_UTL.debug('END for iteration');
    }


    //##########################################
    //########### EXECUTION LOGIC ##############
    //##########################################
    
    /***
    * @description  Main execute method of the Queuable process.
    *               It basically looks for Structure records requiring Public Groups membership
    *               reevaluation via the structStatus flag (see configuration).
    *               It then checks local, upward and downward members and memberships
    *               via dedicated utility methods.
    *               It also manages the requeuing of the process if 
    *               there are still Structure records to process and iterates
    *               a maxIter (see configuration) number of times if there is none.
    *               In order to cope with "MixedDML" constraint, the logic processed
    *               may be split in a first execution on Setup objects (Groups & Group Members)
    *               followed by a second execution on standard objects to upsert the
    *               corresponding sfpegQueueableLog__c record and upsert the structStatus
    *               field of the processed Structure records.
    * @return       sfpegSharingGroup_UTL Next execution context to be executed in new enqueued process
    *               (null if end of processing reached)
    * @exception    None special (all catched and logged).
    ***/     
    public sfpegMultiSharingGroup_UTL execute(){
        sfpegDebug_UTL.info('START for iteration',this.iteration);
        sfpegDebug_UTL.fine('Current configuration',this.config);
        sfpegDebug_UTL.fine('Current hierarchies',this.config?.hierarchies);
        sfpegDebug_UTL.fine('Current groupFields',this.groupFields);
        sfpegDebug_UTL.fine('Current memberFields',this.memberFields);

        DateTime startTS = System.Now();
        Integer waitTime = sfpegQueueable_UTL.getTimeDelta(this.creationTS,startTS);
        sfpegDebug_UTL.fine('WaitTime evaluated',waitTime);

        String lastContext = sfpegQueueable_UTL.getLastContext(this.config.className);
        sfpegDebug_UTL.fine('LastContext fetched',lastContext);
        if (String.isNotEmpty(lastContext)) {
            this.deletionTS = Datetime.valueOfGMT(lastContext);
        }

        // Controlling prior execution Logging case
        if (this.logRecord != null) {
            sfpegDebug_UTL.debug('Registering prior execution');
            doRegistrations(waitTime);
            sfpegDebug_UTL.info('END / Prior execution registered');
            return new sfpegMultiSharingGroup_UTL(this.deletionTS,this.config,this.groupFields,this.memberFields);
        }

        // Controlling Public Groups to delete
        else if (processGroups2Delete()) {
            sfpegDebug_UTL.debug('Public Groups deleted for deleted Structures');
            String logMessage = 'Groups deleted for ' + this.structureMap.size() + ' Structure(s)';
            if (this.structureMap.size() < this.config.maxIDs) logMessage += ': ' + String.join(new List<ID>(this.structureMap.keySet()),',');          
            sfpegQueueable_UTL.logExecution(    this.config.className,this.structureMap.size(),0,
                                   	            logMessage,
                                  	            this.deletionTS.formatGmt('yyyy-MM-dd HH:mm:ss'),
                                  	            waitTime);
            sfpegDebug_UTL.info('END / Public Groups deleted for deleted Structures');
            return new sfpegMultiSharingGroup_UTL(this.deletionTS,this.config,this.groupFields,this.memberFields);
        }

        // Controlling Public Groups to create
        else if (processMissingGroups()) {
            sfpegDebug_UTL.debug('New Public Groups created and registered');            
            String logMessage = 'Groups created for ' + this.structureMap.size() + ' Structure(s)';
            if (this.structureMap.size() < this.config.maxIDs) logMessage += ': ' + String.join(new List<ID>(this.structureMap.keySet()),',');   
            sfpegQueueable_UTL.logExecution(    this.config.className,this.structureMap.size(),0,
                                                logMessage,
                                                this.deletionTS.formatGmt('yyyy-MM-dd HH:mm:ss'),
                                                waitTime);
            sfpegDebug_UTL.info('END / New Public Groups created and registered on Structures');
            return new sfpegMultiSharingGroup_UTL(this.deletionTS,this.config,this.groupFields,this.memberFields);
        }

        // Processing Public Group Membership control
        else if (doMembershipControl()) {
            sfpegDebug_UTL.debug('New Public Groups created and need registration');
            processMemberControl();
            sfpegDebug_UTL.debug('Structure Group Memberships controlled');

            String logMessage = 'Groups updated for ' + this.structureMap.size() + ' Structure(s)';
            if (this.structureMap.size() < this.config.maxIDs) logMessage += ': ' + String.join(new List<ID>(this.structureMap.keySet()),',');          
            // Handling first requeuing (to register Log & BranchUnit flag updates)
            sfpegQueueableLog__c currentLog = sfpegQueueable_UTL.getLogData(this.config.className,this.structureMap.size(),0,
                                                                    logMessage,
                                                                    this.deletionTS.formatGmt('yyyy-MM-dd HH:mm:ss'),
                                                                    waitTime);
            sfpegDebug_UTL.fine('CurrentLog fetched',currentLog);
            sfpegDebug_UTL.info('END  / Triggering Structure Status update');
            return new sfpegMultiSharingGroup_UTL(currentLog,this.structureMap,true,this.deletionTS,this.config,this.groupFields,this.memberFields);
        }

        // Handling empty iterations 
        // Direct Queue logging possible as no Setup DML executed
        else {
            sfpegDebug_UTL.debug('Nothing to do');
            if (this.iteration >= this.config.maxIter) {
                sfpegQueueable_UTL.logExecution(    this.config.className,0,0,'STOP',
                                                    this.deletionTS.formatGmt('yyyy-MM-dd HH:mm:ss'),
                                                    waitTime);
                sfpegDebug_UTL.info('Last iteration reached');
                return null;
            }
            else {
            	sfpegQueueable_UTL.logExecution(    this.config.className,0,0,'',
                                                    this.deletionTS.formatGmt('yyyy-MM-dd HH:mm:ss'),
                                                    waitTime);
                sfpegDebug_UTL.info('END / Triggering new iteration');
                return new sfpegMultiSharingGroup_UTL(this.iteration + 1,this.deletionTS, this.config,this.groupFields,this.memberFields);
            }
        }
    }

    /***
    * @description	Utility method to register a prior process execution (log record as well as
    *               Structure record updates), not previously done due to Mixed DML constraint
    *               (i.e. when prior execution has added/removed Group Members)
    * @param		waitTime	Wait time observed
    * @exception	None special (all catched and logged).
    ***/
    @TestVisible
    private void doRegistrations(Integer waitTime){
        sfpegDebug_UTL.debug('START with wait time',waitTime);

        // Upserting the Log Record
        sfpegQueueable_UTL.logPriorExecution(this.logRecord);
        sfpegDebug_UTL.fine('Log record upserted');

        // Upserting the Structure (after filtering of Structure modified while waiting)
        if (this.doFilter) {
            sfpegDebug_UTL.fine('Filtering Structure list');

            // Preparation
            String registerQuery = 'SELECT ' + this.config.structStatus + ' FROM ' + this.config.structObject + ' WHERE Id in :structureIds AND SystemModStamp > = :timestamp';
            sfpegDebug_UTL.fine('Structure Query template built',registerQuery);

            Map<String, Object> queryParams = new Map<String, Object>{
                'structureIds'  => this.structureMap.keySet(),
                'timestamp'     => this.creationTS};
            sfpegDebug_UTL.fine('Query Params init',queryParams);
            
            // Structure Fetch
            Map<ID,SObject> newStructureStates = new Map<ID,SObject>(Database.queryWithBinds(registerQuery,queryParams,AccessLevel.SYSTEM_MODE));
            sfpegDebug_UTL.fine('State of upserted Structures refetched with #items ' + newStructureStates.size());

            // Structure Analysis
            if (newStructureStates.size() > 0) {
                List<SObject> structures2update = new List<SObject>();
                for (SObject iter : this.structureMap.values()) {
                    if (!newStructureStates.containsKey(iter.Id)) structures2update.add(iter);
                }
                sfpegDebug_UTL.finest('Structures to upsert filtered with #items',structures2update.size());
                upsert structures2update;
                sfpegDebug_UTL.fine('Structure list upserted after filtering');
            }
            else {
                upsert this.structureMap.values();
                sfpegDebug_UTL.fine('Structure list upserted with no filtering required');
            }
        }
        else {
            upsert this.structureMap.values();
            sfpegDebug_UTL.fine('Structure list upserted without filtering');
        }        

        sfpegQueueable_UTL.logExecution(    this.config.className,0,0,null,
                                            this.deletionTS.formatGmt('yyyy-MM-dd HH:mm:ss'),
                                            waitTime);
        sfpegDebug_UTL.debug('END after current execution registration');
        return;
    }

    //##########################################
    //######## GROUP MANAGEMENT LOGIC ##########
    //##########################################

    /***
    * @description  Method to retrieve all recently deleted BranchUnits and delete
    *               the corresponding Local (L), Upward (U) and Downward (D) groups.
    *               This method should be systematically called before executing
    *               the Group creation logic.
    *               It relies on systemModeStamp of the last deleted BranchUnit processed
    *               to fetch the BranchUnits to process, information stored in the
    *               context field of the QueueableLog to handle execution interruptions.
    * @return       Boolean	Returns true if BUs with Public Groups to delete have been
    *               found, in which case, other group management logic should be bypassed.
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private Boolean processGroups2Delete(){
        sfpegDebug_UTL.debug('START');

        // Preparation
        String deleteQuery = 'SELECT SystemModStamp,' + this.config.structExtID + ',' + String.join(this.groupFields,',') + ' FROM ' + this.config.structObject + ' WHERE IsDeleted = true'
                            + (this.deletionTS == null ? '' : ' and systemModStamp > :timeStamp') + ' ORDER BY SystemModStamp asc LIMIT :maxDelete ALL ROWS';                    
        sfpegDebug_UTL.fine('Structure Query template built',deleteQuery);

        Map<String, Object> queryParams = new Map<String, Object>{
            'maxDelete'     => this.config.maxDelete,
            'timestamp'     => this.deletionTS};
        sfpegDebug_UTL.fine('Query Params init',queryParams);

        // Structure fetch
        this.structureMap = new Map<ID,SObject>(Database.queryWithBinds(deleteQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.fine('#Deleted Structures fetched',this.structureMap.size());

        if (this.structureMap.size() == 0) {
            this.deletionTS = this.creationTS;
            sfpegDebug_UTL.debug('END / No Public Group to delete for any Structure');
            return false;
        }

        // Structure analysis
        Set<ID> grpIDs2delete = new Set<ID>();
        for (SObject iter : this.structureMap.values()) {
            sfpegDebug_UTL.fine('Removing Groups for Structure',iter.get(this.config.structExtID));
            for (String iterF : this.groupFields) {
                ID iterV = (ID)iter.get(iterF);
                if (iterV != null) {
                    grpIDs2delete.add(iterV);
                }
            }
            this.deletionTS = (DateTime)iter.get('SystemModStamp'); // to track last one
        }
        sfpegDebug_UTL.debug('#Groups to delete identified',grpIDs2delete.size());

        // Logic Execution
        Database.DeleteResult[] deleteResults = database.delete(new List<ID>(grpIDs2delete),false);        
        // @TODO : Analyse results and register errors

        sfpegDebug_UTL.debug('END / Public Groups deleted for deleted Structures');
        return true;
    }

    /***
    * @description  Method to check if all BranchUnits have related Public Groups
    *               created and registered (Local "_L", Upward "_M" & Downward "_D").
    *               If any BranchUnit has missing Public Groups, they are automatically
    *               created and registered in their Sharing..._c fields.
    *               It basically enables to handle the creation of new BranchUnits.
    *               This method should be systematically called before executing
    *               the membership evaluation logic.
    * @return       Boolean	Returns true if BUs with missing Public Groups have been
    *               found, in which case, group membership logic should be bypassed.
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private Boolean processMissingGroups(){
        sfpegDebug_UTL.debug('processMissingGroups: START');

        // Preparation
        String createQuery = (this.config.useRT ? 'SELECT Name,RecordTypeId,' : 'SELECT Name,') + this.config.structExtID + ',' + String.join(this.groupFields,',')
                            + ' FROM ' + this.config.structObject
                            + ' WHERE (' + String.join(this.groupFields,' = null OR ') + ' = null) AND ' + this.config.structStatus + ' = true LIMIT :maxCreate';              
        sfpegDebug_UTL.fine('Structure Query template built',createQuery);

        Map<String, Object> queryParams = new Map<String, Object>{
            'maxCreate'     => this.config.maxCreate};
        sfpegDebug_UTL.fine('Query Params init',queryParams);

        // Structure Fetch
        this.structureMap = new Map<ID,SObject>(Database.queryWithBinds(createQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.fine('#Structures with missing Groups fetched',this.structureMap.size());

        if (this.structureMap.size() == 0) {
            sfpegDebug_UTL.debug('END / Public Group OK declared for all Structures');
            return false;
        }

        // Structure Analysis
        Map<Id,Schema.RecordTypeInfo> recordTypeMap;
        if (this.config.useRT) {
            sfpegDebug_UTL.debug('Group Naming with RT');
            //recordTypeMap = Schema.getGlobalDescribe().get(this.config.structObject).getDescribe().getRecordTypeInfosById();
            //Change reversed because generating issue with standard Location object
            recordTypeMap = ((SObject)Type.forName('Schema.' + this.config.structObject).newInstance()).getSObjectType().getDescribe().getRecordTypeInfosById();
        }

        Map<String,Map<String,Group>> groupMap = new Map<String,Map<String,Group>>();
        List<Group> groups2add = new List<Group>();
        for (SObject iter : this.structureMap.values()) {
            sfpegDebug_UTL.fine('Adding Groups for Structure', iter);
            String iterExtId = (String) iter.get(this.config.structExtID);
            sfpegDebug_UTL.finest('Structure External ID fetched',iterExtId);

            Map<String,Group> iterGroupMap = new Map<String,Group>();
            groupMap.put(iterExtId,iterGroupMap);
            for (SharingHierarchy iterH : this.config.hierarchies.values()) {
                sfpegDebug_UTL.finest('Processing hierarchy', iterH);

                String nameRoot = (String.isNotBlank(iterH.prefix) ? iterH.prefix + '_' : '');
                if ((this.config.useRT) && (String.isNotBlank((String)iter.get('RecordTypeId')))) {
                    sfpegDebug_UTL.finest('Structure RecordType ID fetched', iter.get('RecordTypeId'));
                    nameRoot += recordTypeMap.get((String)iter.get('RecordTypeId')).getDeveloperName() + '_' + iterExtId;
                }
                else {
                    sfpegDebug_UTL.finest('No Structure RecordType ID');
                    nameRoot += '_' + iterExtId;
                }
                nameRoot += (String.isNotBlank(iterH.suffix) ? '_' + iterH.suffix : '');
                sfpegDebug_UTL.finest('NameRoot initialized', nameRoot);

                if (iter.get(iterH.structLocal) == null) {
                    Group newGrp = new Group(Name = nameRoot + '_L');
                    sfpegDebug_UTL.fine('Adding Local Group', newGrp);
                    iterGroupMap.put(iterH.structLocal,newGrp);
                    groups2add.add(newGrp);
                }
                else {
                    sfpegDebug_UTL.finest('Local Group already exists', iter.get(iterH.structLocal));
                }
                if (iter.get(iterH.structUp) == null) {
                    Group newGrp = new Group(Name = nameRoot + '_U');
                    sfpegDebug_UTL.fine('Adding Upward Group', newGrp);
                    iterGroupMap.put(iterH.structUp,newGrp);
                    groups2add.add(newGrp);
                }
                else {
                    sfpegDebug_UTL.finest('Upward Group already exists', iter.get(iterH.structUp));
                }
                if (iter.get(iterH.structDown) == null) {
                    Group newGrp = new Group(Name = nameRoot + '_D');
                    sfpegDebug_UTL.fine('Adding Downward Group', newGrp);
                    iterGroupMap.put(iterH.structDown,newGrp);
                    groups2add.add(newGrp);
                }
                else {
                    sfpegDebug_UTL.finest('Downward Group already exists', iter.get(iterH.structDown));
                }
            }
        }
        sfpegDebug_UTL.debug('#Groups to add',groups2add.size());
        sfpegDebug_UTL.debug('#Structure to update',groupMap.size());

        // Logic Execution
        insert groups2add;
        sfpegDebug_UTL.debug('Groups inserted');

        for (SObject iter : this.structureMap.values()) {
            String iterExtId = (String)iter.get(this.config.structExtID);
            sfpegDebug_UTL.fine('Registering group IDs on Structure',iterExtId);

            Map<String,Group> iterGroups = groupMap.get(iterExtId);
            for (String iterF : iterGroups.keySet()) {
                sfpegDebug_UTL.fine('Setting Group ID field',iterF);
                sfpegDebug_UTL.fine('with value',iterGroups.get(iterF).Id);
                iter.put(iterF,iterGroups.get(iterF).Id);
            }
        }
        sfpegDebug_UTL.debug('All Public Group IDs set on Structures');
        upsert this.structureMap.values();

        sfpegDebug_UTL.debug('END / Public Group IDs registered on Structures');
        return true;
    }

    /***
    * @description  Context initialisation method for the Public Group Membership
    *               control process.
    *               It looks for Structures requiring Public Groups membership
    *               reevaluation via the STRUCTURE_STATUS flag
    *               and fetches various information about the related Public Groups
    *               and their members (for parent, main & child Structures).
    *               It assumes that all Structures have their Public Groups initialized.
    * @return       Boolean	Indicates whether there are Structures for which
    *               Public Groups should be reevaluated (true if any).
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private Boolean doMembershipControl() {
        sfpegDebug_UTL.debug('START');
        
        // Preparation
        String tmpParentSeparator = ',' + this.config.structParent + '.';
        String updateQuery = 'SELECT Name,' + this.config.structExtID + ',' + this.config.structStatus + ',' + String.join(this.groupFields,',') + ','
                            + this.config.structParent + '.Id,' + this.config.structParent + '.Name,' + this.config.structParent + '.' + this.config.structStatus + ','
                            + this.config.structParent + '.' + String.join(this.groupFields,tmpParentSeparator) + ','
                            + '(SELECT Name,' + this.config.structExtID + ',' + this.config.structStatus + ',' + String.join(this.groupFields,',') + ' FROM ' + this.config.structChildren + '),'
                            + '(SELECT Name,Id,' + this.config.mbrUser + ',' + String.join(this.memberFields,',') + ' FROM ' + this.config.structMembers + ' WHERE ' + String.join(this.memberFields,' = true OR ') + ' = true)'
                            + ' FROM ' + this.config.structObject + ' WHERE ' + this.config.structStatus + ' = true' + ' ORDER BY SystemModstamp asc LIMIT :maxUpdate';
        sfpegDebug_UTL.fine('Structure Query template built',updateQuery);

        Map<String, Object> queryParams = new Map<String, Object>{
            'maxUpdate'     => this.config.maxUpdate};
        sfpegDebug_UTL.fine('Query Params init',queryParams);

        // Fetching Structures to process
        this.structureList = Database.queryWithBinds(updateQuery,queryParams,AccessLevel.SYSTEM_MODE);
        sfpegDebug_UTL.debug('#Structures fetched',structureList.size());

        if (this.structureList.size() == 0) {
            sfpegDebug_UTL.debug('END / Nothing to process');
            return false;
        }

        // Structure Analysis
        sfpegDebug_UTL.debug('Processing Structures / Fetching Groups');
        Set<ID> groupIds = new Set<ID>();   // Set of all Groups mentioned (at parent, main, children levels)

        For (SObject iter : structureList) {
            sfpegDebug_UTL.fine('fetching Groups for Structure ',iter.get('Name'));
            sfpegDebug_UTL.finest('Structure data ',iter);
            sfpegDebug_UTL.finest('Structure parent data ',iter.getSobject(this.config.structParent));
            sfpegDebug_UTL.finest('Structure member data ',iter.getSobjects(this.config.structMembers));
            sfpegDebug_UTL.finest('Structure children data ',iter.getSobjects(this.config.structChildren));
            
            // Registering IDs of L, M & D Groups for Current Structure
            for (String iterG : this.groupFields) {
                groupIds.add((String)iter.get(iterG));
            }
            sfpegDebug_UTL.finest('#Group IDs now registered ', groupIds.size());
    
            // Registering IDs of L, U & D Groups for Parent Structures
            if ( iter.getSobject(this.config.structParent) != null)  {
                SObject iterParent = (SObject) iter.getSobject(this.config.structParent);
                sfpegDebug_UTL.finest('Processing parent Structure',iterParent);
                for (String iterG : this.groupFields) {
                    groupIds.add((String)iterParent.get(iterG));
                }
            }
            else {
                sfpegDebug_UTL.finest('No parent Structure to process');
            }
            sfpegDebug_UTL.finest('#Group IDs now registered ', groupIds.size());

            // Preparing GroupSetMap for the structure
            Map<String,Set<ID>> iterGroupMap = new Map<String,Set<ID>>();
            this.structureGroupSetMap.put(iter.Id,iterGroupMap);

            // Registering Up, Down and Local Groups and IDs of Groups for Local Group
            for (SharingHierarchy iterHV : this.config.hierarchies.values()) {
                Set<ID> localGroupSet = new Set<ID>(); 
                iterGroupMap.put(iterHV.structLocal,localGroupSet);
                Set<ID> upGroupSet = new Set<ID>(); 
                iterGroupMap.put(iterHV.structUp,upGroupSet);
                Set<ID> downGroupSet = new Set<ID>(); 
                iterGroupMap.put(iterHV.structDown,downGroupSet);

                if (String.isNotBlank(iterHV.structMbr)) {
                    localGroupSet.add((ID) iter.get(iterHV.structMbr));
                }
            }

            // Registering IDs of Users for Local Group
            if (iter.getSobjects(this.config.structMembers) != null) {
                sfpegDebug_UTL.finest('Processing Structure Members');

                List<SObject> iterMembers = (List<SObject>) iter.getSobjects(this.config.structMembers);
                sfpegDebug_UTL.finest('#Structure Members provided',iterMembers.size());

                for (SObject iterMember : iterMembers) {
                    sfpegDebug_UTL.finest('Processing Member',iterMember);

                    for (String iterH : this.config.hierarchies.keySet()) {
                        SharingHierarchy iterHV = this.config.hierarchies.get(iterH);

                        if (String.isNotBlank((String)iterMember.get(this.config.mbrUser))) {
                            if ((Boolean)iterMember.get(iterHV.mbrActive)) {
                                sfpegDebug_UTL.finest('Registering Member User for hierarchy',iterH);
                                (iterGroupMap.get(iterHV.structLocal)).add((String)iterMember.get(this.config.mbrUser));
                            }
                            else {
                                sfpegDebug_UTL.finest('Member User not eligible for hierarchy',iterH);
                            }
                        }
                        else {
                            sfpegDebug_UTL.warn('No User ID on member',iterMember);
                        }
                    }
                }
            }
            else {
                sfpegDebug_UTL.finest('No Member Users to process');
            }

            // Registering IDs of Up & Down Groups for Children Structures
            if (iter.getSobjects(this.config.structChildren) != null) {
                sfpegDebug_UTL.finest('Processing children Structures');
                List<SObject> iterChildren = (List<SObject>) iter.getSobjects(this.config.structChildren);
                sfpegDebug_UTL.finest('#Structure Children provided',iterChildren.size());

                for (SObject iterChild : iterChildren) {
                    sfpegDebug_UTL.finest('Processing child Structure',iterChild);
                    for (SharingHierarchy iterHV : this.config.hierarchies.values()) {
                        groupIds.add((String)iterChild.get(iterHV.structLocal));
                        groupIds.add((String)iterChild.get(iterHV.structUp));
                        groupIds.add((String)iterChild.get(iterHV.structDown));
                        (iterGroupMap.get(iterHV.structUp)).add((String)iterChild.get(iterHV.structUp));
                        (iterGroupMap.get(iterHV.structDown)).add((String)iterChild.get(iterHV.structDown));
                    }
                }
            }
            else {
                sfpegDebug_UTL.finest('No Children Structures to process');
            }
        }
        sfpegDebug_UTL.fine('Public Groups extracted with #IDs', groupIds.size());
        sfpegDebug_UTL.fine('Public Groups extracted for #Structures', this.structureGroupSetMap.size());

        this.groupMap = new Map<Id,Group>([
            SELECT Name, (SELECT UserOrGroupId FROM GroupMembers)
            FROM Group
            WHERE Id in :groupIds]);
        sfpegDebug_UTL.fine('#Public Groups descriptions fetched',this.groupMap.size());


        // Executing Logic
        for (GroupMember iter : [SELECT GroupId, Group.Name, UserOrGroupId FROM GroupMember WHERE UserOrGroupId in :groupIds]) {
            List<GroupMember> membershipList = this.membershipMap.get(iter.UserOrGroupId);
            if (membershipList == null) {
                sfpegDebug_UTL.finest('Registering membership for new Public Group with ID',iter.UserOrGroupId);
                membershipList = new List<GroupMember>();
                this.membershipMap.put(iter.UserOrGroupId,membershipList);
            }
            membershipList.add(iter);
        }
        sfpegDebug_UTL.fine('Public Groups memberships fetched for #IDs',this.membershipMap.size());

        sfpegDebug_UTL.debug('END');
        return true;
    }

    /***
    * @description  Context initialisation method for the Public Group Membership
    *               control process.
    *               It looks for Structures requiring Public Groups membership
    *               reevaluation via the STRUCTURE_STATUS flag
    *               and fetches various information about the related Public Groups
    *               and their members (for parent, main & child Structures).
    *               It assumes that all Structures have their Public Groups initialized.
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private void processMemberControl() {
        sfpegDebug_UTL.debug('START');

        // Executing the controls on all fetched Structures.
        this.structureMap = new Map<ID,SObject>();
        Schema.sObjectType structureObject = this.structureList[0].getSObjectType();
        sfpegDebug_UTL.debug('Structure SObject Type fetched', structureObject);
        for (SObject iter : this.structureList) {
            sfpegDebug_UTL.fine('Processing Structure',iter);

            for (SharingHierarchy iterHV : this.config.hierarchies.values()) {
                sfpegDebug_UTL.finest('Processing Hierarchy',iterHV);

                // Controlling Local (_L) Public Group.
                checkLGroupMembers(iter,iterHV);
                checkLGroupMemberships(iter,iterHV);

                // Controlling Upward (_U) Public Group.
                checkUGroupMembers(iter,iterHV);
                checkUGroupMemberships(iter,iterHV);

                // Controlling Downward (_D) Public Group.
                checkDGroupMembers(iter,iterHV);
                checkDGroupMemberships(iter,iterHV);

            }

            // Registering Structure as processed.
            SObject iterUpdate = structureObject.newSObject((ID)iter.get('Id'));
            iterUpdate.put(this.config.structStatus, false);
            iterUpdate.put(this.config.structTS, System.now());
            this.structureMap.put((ID)iter.get('Id'), iterUpdate);
        }
        sfpegDebug_UTL.debug('All Structures processed');

        // Updating the database (Setup GroupMember Object)
        Database.SaveResult[] insertResults = database.insert(this.gm2add.values(),false);
        sfpegDebug_UTL.debug('#New Group Memberships added',this.gm2add.size());
        Database.DeleteResult[] deleteResults = database.delete(new List<ID>(this.gm2remove),false);        
        sfpegDebug_UTL.debug('#Old Group Memberships removed',this.gm2remove.size());
        // @TODO : analyse results

        sfpegDebug_UTL.debug('END');
    }

    /***
    * @description  Method to check/update the members of the Local (_L) Public Group
    *               of the Structures.
    *               Each "_L" group should contain only User members corresponding
    *               to the User Members of the Structure.
    *               The gm2add and gm2remove global variables are directly updated
    *               depending on the members missing/unexpected.
    * @exception	None special (all catched and logged).
    ***/
    @TestVisible
    private void checkLGroupMembers(SObject structure, SharingHierarchy hierarchy) {
        sfpegDebug_UTL.fine('START for structure',structure);
        sfpegDebug_UTL.finest('and hierarchy',hierarchy);

        Group lGroupDesc = this.groupMap.get((String)structure.get(hierarchy.structLocal));
        sfpegDebug_UTL.finest('Local Group fetched',lGroupDesc);
        Set<ID> localMbrs = (this.structureGroupSetMap.get((String)structure.get('Id'))).get(hierarchy.structLocal);
        sfpegDebug_UTL.finest('Local Members fetched',localMbrs);

        Set<Id> lMembers = new Set<Id>();
        if (lGroupDesc.GroupMembers != null) {
            sfpegDebug_UTL.finest('Checking Local Group Members');
            for (GroupMember iterL : lGroupDesc.GroupMembers) {
                string iterPrefix = ((String)(iterL.UserOrGroupId)).left(3);
                if ((iterPrefix == PREFIX_USER) || (iterPrefix == PREFIX_GROUP)) {
                    if (localMbrs.contains(iterL.UserOrGroupId)) {
                        sfpegDebug_UTL.finest('leaving GM in Local Group',iterL);
                        lMembers.add(iterL.UserOrGroupId);
                    }
                    else {
                        sfpegDebug_UTL.finest('Removing unexpected GM in Local Group',iterL);
                        this.gm2remove.add(iterL.Id);
                    }
                }
                else {
                    // Unsupported Group member
                    sfpegDebug_UTL.finest('Removing unsupported GM type from Local Group',iterL);
                    this.gm2remove.add(iterL.Id);
                }
            }
        }
        else {
            sfpegDebug_UTL.finest('No member in Local Group');                
        }

        // Checking missing members
        for (Id iterId : localMbrs) {
            if (lMembers.contains(iterId)) {
                sfpegDebug_UTL.finest('User GM already in Local Group',iterId);
            }
            else {
                sfpegDebug_UTL.finest('Registering missing GM in Local Group',iterId);                
                this.gm2add.put(structure.get(hierarchy.structLocal) + '-' + iterId,
                               new GroupMember(	GroupId = (ID)structure.get(hierarchy.structLocal),
                                          		UserOrGroupId = iterId));
            }
        }

        sfpegDebug_UTL.fine('END');
    }

    /***
    * @description  Method to check the memberships of the Local (_L) Public Group
    *               of the Structures.
    *               Each "_L" group should only be included in the Upward (_U) and 
    *               Downward (_D) groups of the Structure it belongs to.
    *               The gm2add and gm2remove global variables are directly updated
    *               depending on the members missing/unexpected.
    * @exception	None special (all catched and logged).
    ***/
    @TestVisible
    private void checkLGroupMemberships(final SObject structure, final SharingHierarchy hierarchy) {
        sfpegDebug_UTL.fine('START for structure',structure);
        sfpegDebug_UTL.finest('and hierarchy',hierarchy);

        List<GroupMember> lGroupMbs = this.membershipMap.get((String)structure.get(hierarchy.structLocal));
        sfpegDebug_UTL.finest('Local Group memberships fetched',lGroupMbs);

        Boolean upOK = false;
        Boolean downOK = false;
        if ((lGroupMbs != null) && (lGroupMbs.size() > 0)) {
            sfpegDebug_UTL.finest('Checking Local Group Memberships'); 

            for (GroupMember iterL : lGroupMbs) {
                if (iterL.GroupId == structure.get(hierarchy.structUp)) {
                    sfpegDebug_UTL.finest('Local Group found in Upward Group'); 
                    upOK = true;
                }
                else if (iterL.GroupId == structure.get(hierarchy.structDown)) {
                    sfpegDebug_UTL.finest('Local Group found in Downward Group'); 
                    downOK = true;
                }
                else {
                    sfpegDebug_UTL.finest('Removing unsupported Local Group Membership'); 
                    this.gm2remove.add(iterL.Id);
                }
            }
        }

        // Checking missing members
        if (!upOK) {
            sfpegDebug_UTL.finest('Registering Local Group in Upward Group');                
            this.gm2add.put(structure.get(hierarchy.structUp) + '-' + structure.get(hierarchy.structLocal),
                           new GroupMember(	GroupId = (ID)structure.get(hierarchy.structUp),
                                          	UserOrGroupId = (ID)structure.get(hierarchy.structLocal)));
        }
        if (!downOK) {
            sfpegDebug_UTL.finest('Registering Local Group in Downward Group');                
            this.gm2add.put(structure.get(hierarchy.structDown) + '-' + structure.get(hierarchy.structLocal),
                           new GroupMember(	GroupId = (ID)structure.get(hierarchy.structDown),
                                          	UserOrGroupId = (ID)structure.get(hierarchy.structLocal)));
        }

        sfpegDebug_UTL.fine('END');
    }

    /***
    * @description  Method to check/update the members of the Upward (_U) Public Group
    *               of the Structures.
    *               It checks that the only members are the Local Group (_L) of the
    *               Structure and the Upward Group (_U) of the Parent Structure.
    *               It assumes that Local group (_L ) membership control is done and 
    *               does not add this Group.
    *               The gm2add and gm2remove global variables are directly updated
    *               depending on the members missing/unexpected.
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private void checkUGroupMembers(final SObject structure, final SharingHierarchy hierarchy) {
        sfpegDebug_UTL.fine('START for structure', structure);
        sfpegDebug_UTL.finest('and hierarchy',hierarchy);

        Group mGroupDesc = this.groupMap.get((String)structure.get(hierarchy.structUp));
        sfpegDebug_UTL.finest('Upward Group fetched',mGroupDesc);
        Boolean mUpOK = false;
        if (mGroupDesc.GroupMembers != null) {
            sfpegDebug_UTL.finest('Checking Upward Group Members');
            for (GroupMember iterM : mGroupDesc.GroupMembers) {
                string iterPrefix = ((String)(iterM.UserOrGroupId)).left(3);
                if (iterPrefix == PREFIX_USER) {
                    sfpegDebug_UTL.finest('Removing User GM from Upward Group',iterM);
                    this.gm2remove.add(iterM.Id);
                }
                else if (iterPrefix == PREFIX_GROUP) {
                    if (iterM.UserOrGroupId == structure.get(hierarchy.structLocal)) {
                        sfpegDebug_UTL.finest('Ignoring Local Group GM in Upward Group',iterM);
                    }
                    else if (   (structure.getSObject(this.config.structParent) != null)
                            &&  (iterM.UserOrGroupId == (ID)((SObject)structure.getSObject(this.config.structParent)).get(hierarchy.structUp))) {
                        sfpegDebug_UTL.finest('Ignoring upward parent Group GM in Upward Group',iterM);
                        mUpOK = true;
                    }
                    else {
                        sfpegDebug_UTL.finest('Removing unexpected Group GM in Upward Group',iterM);
                        this.gm2remove.add(iterM.Id);
                    }
                }
                else {
                    // Unsupported Group member
                    sfpegDebug_UTL.finest('Removing unsupported GM type from Upward Group ' + iterM);
                    this.gm2remove.add(iterM.Id);
                }
            }
        }

        // Checking missing members
        if (!mUpOK) {
            if (structure.getSObject(this.config.structParent) != null) {
                sfpegDebug_UTL.finest('Registering upward parent Group in Upward Group');                
                this.gm2add.put(structure.get(hierarchy.structUp) + '-' + ((SObject)structure.getSObject(this.config.structParent)).get(hierarchy.structUp),
                               new GroupMember(	GroupId = (ID)structure.get(hierarchy.structUp),
                                          		UserOrGroupId = (ID)((SObject)structure.getSObject(this.config.structParent)).get(hierarchy.structUp)));
            }
        }

        sfpegDebug_UTL.fine('END');
    }

    /***
    * @description  Method to check the memberships of the Upward (_U) Public Group
    *               of the Structures.
    *               Each "_U" group of a Structure should be included in the Upward
    *               (_U) Groups of all its children BranchUnits. 
    *               The gm2add and gm2remove global variables are directly updated
    *               depending on the members missing/unexpected.
    * @exception    None special (all catched and logged).
    ***/    
    @TestVisible
    private void checkUGroupMemberships(final SObject structure, final SharingHierarchy hierarchy) {
        sfpegDebug_UTL.fine('START for structure',structure);
        sfpegDebug_UTL.finest('and hierarchy',hierarchy);

        List<GroupMember> mGroupMbs = this.membershipMap.get((ID)structure.get(hierarchy.structUp));
        sfpegDebug_UTL.finest('Upward Group memberships fetched',mGroupMbs);
        Set<ID> childUps = (this.structureGroupSetMap.get((String)structure.get('Id'))).get(hierarchy.structUp);
        sfpegDebug_UTL.finest('Children Upward Groups fetched',childUps);

        Set<Id> mChildGroups = new Set<Id>();
        if ((mGroupMbs != null) && (mGroupMbs.size() > 0)) {
            sfpegDebug_UTL.finest('Checking Upward Group memberships');
            for (GroupMember iterM : mGroupMbs) {
                if (childUps.contains(iterM.GroupId)) {
                    sfpegDebug_UTL.finest('Ignoring Upward Group GM in child Upward Group',iterM);
                    mChildGroups.add(iterM.GroupId);
                }
                else {
                    sfpegDebug_UTL.finest('Removing unexpected Upward Group GM',iterM);
                    this.gm2remove.add(iterM.Id);
                }
            }
        }

        // Checking missing members
        for (Id iterId : childUps) {
            if (mChildGroups.contains(iterId)) {
                sfpegDebug_UTL.finest('Upward Group GM alreaddy in child Upward Group',iterId);
            }
            else {
                sfpegDebug_UTL.finest('Registering Upward Group in child Upward Group',iterId);                
                this.gm2add.put(iterId + '-' + structure.get(hierarchy.structUp),
                               new GroupMember(	GroupId = iterId,
                                          		UserOrGroupId = (ID)structure.get(hierarchy.structUp)));
            }
        }

        sfpegDebug_UTL.fine('END');
    }

    /***
    * @description  Method to check/update the members of the Downward (_D) Public Group
    *               of the Structures.
    *               It checks that the only members are the Local Group (_L) of the
    *               Structure and all the Downward Groups (_D) of its children Structures.
    *               It assumes that Local group (_L ) membership control is done and 
    *               does not add this Group.
    *               The gm2add and gm2remove global variables are directly updated
    *               depending on the members missing/unexpected.
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private void checkDGroupMembers(final SObject structure, final SharingHierarchy hierarchy) {
        sfpegDebug_UTL.fine('START for structure', structure);
        sfpegDebug_UTL.finest('and hierarchy',hierarchy);

        Group dGroupDesc = groupMap.get((ID)structure.get(hierarchy.structDown));
        sfpegDebug_UTL.finest('Downward Group fetched', dGroupDesc);
        Set<ID> childDowns = (this.structureGroupSetMap.get((String)structure.get('Id'))).get(hierarchy.structDown);
        sfpegDebug_UTL.finest('Children Downward Groups fetched',childDowns);

        Set<Id> dChildGroups = new Set<Id>();
        if (dGroupDesc.GroupMembers != null) {
            sfpegDebug_UTL.finest('Checking Downward Group Members');
            for (GroupMember iterD : dGroupDesc.GroupMembers) {
                string iterPrefix = ((String)(iterD.UserOrGroupId)).left(3);
                if (iterPrefix == PREFIX_USER) {
                    sfpegDebug_UTL.finest('Removing User GM from Downward Group',iterD);
                    this.gm2remove.add(iterD.Id);
                }
                else if (iterPrefix == PREFIX_GROUP) {
                    if (iterD.UserOrGroupId == structure.get(hierarchy.structLocal)) {
                        sfpegDebug_UTL.finest('Ignoring Local Group GM in Downward Group',iterD);
                    }
                    else if (childDowns.contains(iterD.UserOrGroupId)) {
                        sfpegDebug_UTL.finest('Ignoring child Downward Group GM in Downward Group',iterD);
                        dChildGroups.add(iterD.UserOrGroupId);
                    }
                    else {
                        sfpegDebug_UTL.finest('Removing unexpected Group GM in Downward Group',iterD);
                        this.gm2remove.add(iterD.Id);
                    }
                }
                else {
                    // Unsupported Group member
                    sfpegDebug_UTL.finest('Removing unsupported GM type from Downward Group',iterD);
                    this.gm2remove.add(iterD.Id);
                }
            }
        }

        // Checking missing members
        for (Id iterId : childDowns) {
            if (dChildGroups.contains(iterId)) {
                sfpegDebug_UTL.finest('Child Downward Group GM alreaddy in Downward Group',iterId);
            }
            else {
                sfpegDebug_UTL.finest('Registering Child Downward Group in Downward Group',iterId);                
                this.gm2add.put(structure.get(hierarchy.structDown) + '-' + iterId,
                               new GroupMember(	GroupId = (ID)structure.get(hierarchy.structDown),
                                          		UserOrGroupId = iterId));
            }
        }
        sfpegDebug_UTL.fine('END');
    }

    /***
    * @description  Method to check the memberships of the DownWard (_D) Public Group
    *               of the Structures.
    *               Each "_D" group of a Structure should be included only in the
    *               DownWard (_D) Group of its parent Structure. 
    *               The gm2add and gm2remove global variables are directly updated
    *               depending on the members missing/unexpected.
    * @exception    None special (all catched and logged).
    ***/    
    @TestVisible
    private void checkDGroupMemberships(final SObject structure, final SharingHierarchy hierarchy) {
        sfpegDebug_UTL.fine('START for structure', structure);
        sfpegDebug_UTL.finest('and hierarchy',hierarchy);

        List<GroupMember> dGroupMbs = this.membershipMap.get((ID)structure.get(hierarchy.structDown));
        sfpegDebug_UTL.finest('Downward Group memberships fetched',dGroupMbs);

        Boolean mDownOK = false;
        if ((dGroupMbs != null) && (dGroupMbs.size() > 0)) {
            sfpegDebug_UTL.finest('Checking Downward Group Memberships');
            for (GroupMember iterD : dGroupMbs) {
                if (	(structure.getSObject(this.config.structParent) != null)
                    &&	(iterD.GroupId == (ID)((SObject)structure.getSObject(this.config.structParent)).get(hierarchy.structDown))) {
                    sfpegDebug_UTL.finest('Ignoring Downward Group GM in parent Downward Group',iterD);
                    mDownOK = true;
                }
                else {
                    sfpegDebug_UTL.finest('Removing unexpected Downward Group GM',iterD);
                    this.gm2remove.add(iterD.Id);
                }
            }
        }

        // Checking missing members
        if (!mDownOK) {
            if (structure.getSObject(this.config.structParent) != null) {
                sfpegDebug_UTL.finest('Registering Downward Group in parent Downward Group');                
                this.gm2add.put(((SObject)structure.getSObject(this.config.structParent)).get(hierarchy.structDown) + '-' + structure.get(hierarchy.structDown),
                        		new GroupMember(GroupId = (ID)((SObject)structure.getSObject(this.config.structParent)).get(hierarchy.structDown),
                                                UserOrGroupId = (ID)structure.get(hierarchy.structDown)));
            }
        }

        sfpegDebug_UTL.fine('END');
    }
}