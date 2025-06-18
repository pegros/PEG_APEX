/***
* @description  Utility Class for the management of public groups associated to a
*               structure records and memberships records.
*               It is a generalization of the sfpegMultiSharingGroup_UTL class
*               to support optional upward and downward group hierarchies and
*               allow for membership in different Objects (instead of one).
* @author       P-E GROS
* @date         Apr 2024
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

public with sharing class sfpegGroupManagement_UTL  {  // NOPMD bypass naming convention

    //################################################################################################
    // STATIC CONSTANTS
    //################################################################################################

    /***
    * @description  Static constant used to check Group Member of type User (for Structure Members).
    ***/
    private final static String PREFIX_USER = User.sobjecttype.getDescribe().getKeyPrefix();
    
    /***
    * @description  Static constant used to check Group Member of type Public Group (for Structure hierarchy).
    ***/
    private final static String PREFIX_GROUP = Group.sobjecttype.getDescribe().getKeyPrefix();

    /***
    * @description  Static constant containing the label of the operation logged when handling group deletions
    ***/
    private final static String OPE_DELETE = 'DELETE';

    /***
    * @description  Static constant containing the label of the operation logged when handling group creations 
    ***/
    private final static String OPE_CREATE = 'CREATE';

    /***
    * @description  Static constant containing the label of the operation logged when handling membership control 
    ***/
    private final static String OPE_UPDATE = 'UPDATE';

    //################################################################################################
    // CONFIGURATION SUB-CLASSES
    //################################################################################################

    /***
    * @description  Specific Subclass to manage main configuration parameters of the Group Management process
    *               This information is provided by the Queueable process triggering the process.
    ***/ 
    public class GlobalConfiguration {
        // Processing configuration
        public String       className;                  // Name of the queueable process (dependent on configuration provided) for logs
        public Integer      maxCreate       = 200;      // Max. number of records processed at each iteration (when creating public groups).
        public Integer      maxUpdate       = 50;       // Max. number of records processed at each iteration (when updating public group memberships).
        public Integer      maxDelete       = 200;      // Max. number of records processed at each iteration (when deleting public groups).
    
        // Structure processing configuration
        public String       structObject;               // Hierarchical Structure Object API Name
        public String       structKey;                  // API Name of the Structure External ID Field used for Public Group Naming
        public String       structStatus;               // API Name of the Structure Boolean field indicating the Structures to process 
        public String       structTS;                   // API Name of the Structure DateTime field storing the last evaluation for a Structure
        public String       structMsg;                  // API Name of the Structure String field storing some info about the last evaluation for a Structure
        public boolean      useRT           = false;    // Flag to use Structure RecordType Names in Public Group Names

        // Hierarchy Group configuration
        public String       structParent;               // API Name of the Structure Relation to access Data of the Parent Structure
        public String       structParentId;             // API Name of the Structure lookup Field containing the ID of the Parent Structure
        public String       structChildren;             // API Name of the Structure Relation to access Data of the Children Structures
        
        // Group management configuration
        public Map<String,GroupConfiguration> groupConfigs; // Map of individual Group management configurations
    }

    /***
    * @description  Specific Subclass to manage configuration parameters of each Group set/hierarchy processed
    ***/ 
    public class GroupConfiguration {
        // Group Naming  configuration
        public String       prefix          = '';       // Prefix used for Public Group Names of this group set/hierarchy
        public String       suffix          = '';       // Suffix used for Public Group Names of this group set/hierarchy

        // Local Group configuration
        public String       structLocal;                // API Name of the Structure String field storing the Local Public Group ID
        public String       localSuffix     = '_L';     // Suffix used for Local Public Group Names of this group set/hierarchy
        public List<String> structMbrIDs;               // List of API Names of Structure fields storing member IDs (Group or User) for Local Group Membership
        public String       mbrObject;                  // Member Object API Name for Local Group Membership
        public String       mbrActive;                  // API Name of the Member Boolean field indicating if the Member record is active 
        public String       mbrStruct;                  // API Name of the Member lookup field identifying the related Structure
        public List<String> mbrIDs;                     // List of API Names of Member fields storing member IDs (Group or User) for Local Group Membership

        // Hierarchy Group configuration
        public String       structUp;                   // API Name of the Structure String field (optional) storing the Upwards Public Group ID
        public String       upSuffix        = '_U';     // Suffix used for Upwards Public Group Names of this group set/hierarchy
        public String       structDown;                 // API Name of the Structure String field (optional) storing the Downwards Public Group ID
        public String       downSuffix      = '_D';     // Suffix used for Downwards Public Group Names of this group set/hierarchy
    }

    /***
    * @description  Specific Subclass to store technical parameters for the execution of the Group Management process
    *               This information is derived from the configuration provided by the Queueable process at the first execution.
    ***/ 
    private class ProcessConfiguration {
        public Set<String>              localGroups;        // Set of Local Public Group identification fields on the Structure object
        public Set<String>              upGroups;           // Set of Upwards Public Group identification fields on the Structure object
        public Set<String>              downGroups;         // Set of Downwards Public Group identification fields on the Structure object
        public Set<String>              structFields;       // Set of member fields on the Structure object
        public Map<String,Set<String>>  mbrFieldMap;        // Map per Member Object of the set of member identification fields on each member Object
        public Map<String,Set<String>>  mbrStatusMap;       // Map per Member Object of the set of member status fields on each member Object
        public Map<String,String>       mbrStructMap;       // Map per Member Object of the Structure lookup fields on each member Object
        public String                   registerQuery;      // SOQL query template to control the Structure records before registering their status changes (when in 2 step process)
        public String                   deleteQuery;        // SOQL query template to identify deleted Structure records for which public groups should be deleted
        public String                   createQuery;        // SOQL query template to identify Structure records for which public groups should be created
        public String                   updateQuery;        // SOQL query template to identify Structure records for which public group members and memberships should be controlled
        public Map<String,String>       mbrQueryMap;        // Map per Member Object of the SOQL query templates to fetch members for each Structure record to review
        public Integer                  maxUpdate;          // Override of the Max. number of records processed at each iteration (when updating public group memberships).
    }


    //################################################################################################
    // CONFIGURATION VARIABLES
    //################################################################################################

    /***
    * @description  Configuration of the Group Management execution process
    ***/
    @testVisible
    private GlobalConfiguration globalConfig;

    /***
    * @description  Technical context of the Group Management execution process (evaluated at 1st execution)
    ***/
    @testVisible
    private ProcessConfiguration processConfig;


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
    * @description  This variable contains the actual operation executed when in a 
    *               2 step process
    ***/     
    private String operation;

    /***
    * @description  This variable enables to filter the Structure updates
    *               or not when executing the last step of a 2 step process
    *               (because of mixed DML constraints).
    ***/     
    private Boolean doFilter = true;

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
    * @description  Map of Struture records processed by the Queuable instance.
    *               When provided at creation, this map contains the Map of processed
    *               Structures to be updated (structStatus flag and structTS
    *               timestamp) in the last step of a 2 step process (because of mixed DML constraints).
    *               Otherwise, it contains details about the Structures fetched and processes
    *               by an iteration (e.g. with public group fields, parent and children data...)
    *               depending on the operation executed.
    ***/
    @testVisible
    private Map<ID,SObject> structureMap; 

    /***
    * @description  Map per member object of all member records related to the processed Structures
    *               group by Structure ID.
    *               Used only when checking group members and memberships.
    ***/
    private Map<String,Map<ID,List<SObject>>> memberMap;

    /***
    * @description  Map per Group type (local, upwards...) of Map per Group ID of the
    *               Sets of their GroupMembers.
    *               5 types are available : 'local', 'up' and 'down' for processed Structures,
    *               'parentDown' for their related parents and 'childUp' for their related children.
    *               Used only when checking group memberships.
    ***/
    private Map<String,Map<ID,Set<GroupMember>>> groupMap;

    /***
    * @description  During the processing of Structures, this Map collects all the missing
    *               Public Group Members to be added.
    *               GroupMembers are indexed by "GroupId-UserOrGroupId" key (to ensure new
    *               members are created only once).
    *               Used only when checking group memberships.
    ***/    
    private Map<String,GroupMember> gm2add = new Map<String,GroupMember>();

    /***
    * @description  During the processing of Structures, this Set collects all the 
    *               Public Group Members to be removed.
    *               Used only when checking group memberships.
    ***/ 
    private Set<ID> gm2remove = new Set<ID>();

    /***
    * @description  During the processing of Structures, this Set tracks the Structure
    *               ID of any Public Group Members added / removed.
    *               Removed group members are identified by their ID, while added ones
    *               are by "GroupId-UserOrGroupId" key.
    *               Used to register add/remove failures on processed Structures.
    *               Used only when checking group memberships.
    ***/ 
    private Map<String,ID> structure4gm = new Map<String,ID>();


    //################################################################################################
    // CONSTRUCTORS
    //################################################################################################

    /***
    * @description	Standard public constructor used to launch the Group Management process,
    *               used by the Queueable process providing the configuration.
    *               It basically stores the provided config in the groupConfig variable and
    *               initializes the processingConfig variable out of it.
    * @exception    NullPointerException Raised when there is a missing parameter in the provided configuration.
    ***/
    public sfpegGroupManagement_UTL(final GlobalConfiguration globalConfig) {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.fine('START for first iteration');
        this.creationTS = System.now();

        if (globalConfig == null) {
            sfpegDebug_UTL.error('END KO / Missing config');
            Exception error = new System.NullPointerException();
            error.setMessage('Provided Configuration is null');
            throw error;
        }
        else if ((globalConfig.groupConfigs == null) || (globalConfig.groupConfigs.isEmpty())) {
            sfpegDebug_UTL.error('END KO / Missing group configuration',globalConfig);
            Exception error = new System.NullPointerException();
            error.setMessage('Provided Configuration misses groupConfigs property');
            throw error;
        }
        else if (String.isBlank(globalConfig.className)) {
            sfpegDebug_UTL.error('END KO / Missing className in the configuration',globalConfig);
            Exception error = new System.NullPointerException();
            error.setMessage('Provided Configuration misses className property');
            throw error;
        }

        this.globalConfig = globalConfig;
        sfpegDebug_UTL.finer('Group Config registered',this.globalConfig);

        this.processConfig = new ProcessConfiguration();
        this.processConfig.localGroups = new Set<String>();
        this.processConfig.upGroups = new Set<String>();
        this.processConfig.downGroups = new Set<String>();
        this.processConfig.structFields = new Set<String>();
        this.processConfig.mbrFieldMap = new Map<String,Set<String>>();
        this.processConfig.mbrStatusMap = new Map<String,Set<String>>();
        this.processConfig.mbrStructMap = new Map<String,String>();
        this.processConfig.mbrQueryMap = new Map<String,String>();
        sfpegDebug_UTL.finest('Procesing Config initialized',this.processConfig);

        for (GroupConfiguration iterConfig : this.globalConfig.groupConfigs.values()) {
            sfpegDebug_UTL.finest('Analysing group set/hierarchy',iterConfig);
            
            // Processing Group ID fields
            if (String.isNotBlank(iterConfig.structLocal) ) {
                sfpegDebug_UTL.finest('Registering Local Group ID field',iterConfig.structLocal);
                this.processConfig.localGroups.add(iterConfig.structLocal);
            }
            else {
                sfpegDebug_UTL.error('END KO / Missing local group ID property in Group configuration',iterConfig);
                Exception error = new System.NullPointerException();
                error.setMessage('Provided GroupConfiguration property misses local group field name');
                throw error;
            }

            if (String.isNotBlank(iterConfig.structUp) ) {
                sfpegDebug_UTL.finest('Registering Upwards Group ID field',iterConfig.structUp);
                this.processConfig.upGroups.add(iterConfig.structUp);
            }
            else {
                sfpegDebug_UTL.finest('No Upwards Group ID field provided');
            }

            if (String.isNotBlank(iterConfig.structDown) ) {
                sfpegDebug_UTL.finest('Registering Downwards Group ID field',iterConfig.structDown);
                this.processConfig.downGroups.add(iterConfig.structDown);
            }
            else {
                sfpegDebug_UTL.finest('No Downwards Group ID field provided');
            }

            // Processing Structure Members
            if ((iterConfig.structMbrIDs != null) && (!iterConfig.structMbrIDs.isEmpty())) {
                sfpegDebug_UTL.finest('Registering Structure members ID field',iterConfig.structMbrIDs);
                this.processConfig.structFields.addAll(iterConfig.structMbrIDs);
            }
            else {
                sfpegDebug_UTL.finest('No Structure member ID fields to register');
            }
            
            //  Processing Member objects
            if (String.isNotBlank(iterConfig.mbrObject)) {
                if (!this.processConfig.mbrFieldMap.containsKey(iterConfig.mbrObject)) {
                    sfpegDebug_UTL.finest('Registering member Object',iterConfig.mbrObject);
                    this.processConfig.mbrFieldMap.put(iterConfig.mbrObject,new Set<String>());
                    this.processConfig.mbrStatusMap.put(iterConfig.mbrObject,new Set<String>());
                    this.processConfig.mbrStructMap.put(iterConfig.mbrObject,iterConfig.mbrStruct);
                }
                else {
                    sfpegDebug_UTL.finest('Member Object already registered',iterConfig.mbrObject);
                }

                //  Processing Member fields
                if (String.isNotBlank(iterConfig.mbrActive)) {
                    sfpegDebug_UTL.finest('Registering member active field',iterConfig.mbrActive);
                    this.processConfig.mbrStatusMap.get(iterConfig.mbrObject).add(iterConfig.mbrActive);
                }
                else {
                    sfpegDebug_UTL.finest('No Member active field to register');
                }
                if ((iterConfig.mbrIDs != null) && (!iterConfig.mbrIDs.isEmpty())) {
                    sfpegDebug_UTL.finest('Registering member ID fields',iterConfig.mbrIDs);
                    this.processConfig.mbrFieldMap.get(iterConfig.mbrObject).addAll(iterConfig.mbrIDs);
                }
                else {
                    sfpegDebug_UTL.finest('No Member ID fields to register');
                }
            }
            else {
                sfpegDebug_UTL.finest('no Member Object to register');
            }
        }
  
        // Initializing SOQL Query Templates
        this.processConfig.registerQuery = 'SELECT ' + this.globalConfig.structStatus
                                        + ' FROM ' + this.globalConfig.structObject
                                        + ' WHERE Id in :structureIds AND SystemModStamp > :timestamp';
        sfpegDebug_UTL.finest('Registration Query init',this.processConfig.registerQuery);

        this.processConfig.deleteQuery = 'SELECT SystemModStamp,' + this.globalConfig.structKey + ','
                                                + String.join(this.processConfig.localGroups,',')
                                                + (this.processConfig.upGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.upGroups,','))
                                                + (this.processConfig.downGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.downGroups,','))
                                        + ' FROM ' + this.globalConfig.structObject
                                        //+ ' WHERE IsDeleted = true' + (this.deletionTS == null ? '' : ' and systemModStamp > :timeStamp')
                                        + ' WHERE IsDeleted = true AND SystemModStamp >= :timeStamp AND ((SystemModStamp > :timeStamp) OR (Id > :lastRecordId))'
                                        + ' ORDER BY SystemModStamp ASC, Id ASC LIMIT :maxDelete ALL ROWS';      
        sfpegDebug_UTL.finest('Deletion Query init',this.processConfig.deleteQuery);

        this.processConfig.createQuery = (this.globalConfig.useRT ? 'SELECT Name,RecordTypeId,' : 'SELECT Name,') + this.globalConfig.structKey + ','
                                                + String.join(this.processConfig.localGroups,',')
                                                + (this.processConfig.upGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.upGroups,','))
                                                + (this.processConfig.downGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.downGroups,','))
                                        + ' FROM ' + this.globalConfig.structObject
                                        + ' WHERE (' + String.join(this.processConfig.localGroups,' = null OR ') + ' = null '
                                                + (this.processConfig.upGroups.isEmpty() ? '' : ' OR ' + String.join(this.processConfig.upGroups,' = null OR ') + ' = null ')
                                                + (this.processConfig.downGroups.isEmpty() ? '' : ' OR ' + String.join(this.processConfig.downGroups,' = null OR ') + ' = null ')
                                                + ') AND ' + this.globalConfig.structStatus + ' = true LIMIT :maxCreate';              
        sfpegDebug_UTL.finest('Creation Query init',this.processConfig.createQuery);

        String parentSeparator = ',' + this.globalConfig.structParent + '.';
        this.processConfig.updateQuery = 'SELECT Name,' + this.globalConfig.structKey + ',' + this.globalConfig.structStatus + ','
                                                + String.join(this.processConfig.localGroups,',')
                                                + (this.processConfig.upGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.upGroups,','))
                                                + (this.processConfig.downGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.downGroups,','))
                                                + (this.processConfig.structFields.isEmpty() ? '' : ',' + String.join(this.processConfig.structFields,','))                        
                                            + ',' + this.globalConfig.structParent + '.Id,' + this.globalConfig.structParent + '.Name,' + this.globalConfig.structParent + '.' + this.globalConfig.structStatus + ','
                                                + this.globalConfig.structParent + '.' + String.join(this.processConfig.localGroups,parentSeparator)
                                                + (this.processConfig.upGroups.isEmpty() ? '' : ',' + this.globalConfig.structParent + '.' + String.join(this.processConfig.upGroups,parentSeparator))
                                                + (this.processConfig.downGroups.isEmpty() ? '' : ',' + this.globalConfig.structParent + '.' + String.join(this.processConfig.downGroups,parentSeparator))
                                            + ', (SELECT Name,' + this.globalConfig.structKey + ',' + this.globalConfig.structStatus + ','
                                                + String.join(this.processConfig.localGroups,',')
                                                + (this.processConfig.upGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.upGroups,','))
                                                + (this.processConfig.downGroups.isEmpty() ? '' : ',' + String.join(this.processConfig.downGroups,','))
                                                + ' FROM ' + this.globalConfig.structChildren + ')'
                                            + ' FROM ' + this.globalConfig.structObject
                                            + ' WHERE ' + this.globalConfig.structStatus + ' = true'
                                            + ' ORDER BY SystemModstamp asc LIMIT :maxUpdate';
        sfpegDebug_UTL.finest('Update Query init',this.processConfig.updateQuery);

        if (this.processConfig.mbrFieldMap.isEmpty()) {
            sfpegDebug_UTL.finest('No member query to init');
        }
        else {
            sfpegDebug_UTL.finest('Initializing #Member queries',this.processConfig.mbrFieldMap.size());
            for (String iterMbrObj : this.processConfig.mbrFieldMap.keySet()) {
                sfpegDebug_UTL.finest('Processing member Object',iterMbrObj);
                String iterMbrQuery = 'SELECT Name,Id,'
                                        + this.processConfig.mbrStructMap.get(iterMbrObj) + ','
                                        + String.join(this.processConfig.mbrFieldMap.get(iterMbrObj),',')
                                        + (this.processConfig.mbrStatusMap.get(iterMbrObj).isEmpty() ? '' : ',' + String.join(this.processConfig.mbrStatusMap.get(iterMbrObj),','))
                                    + ' FROM ' + iterMbrObj
                                    + ' WHERE (' + this.processConfig.mbrStructMap.get(iterMbrObj) + ' IN :structureIds )'
                                        + (this.processConfig.mbrStatusMap.get(iterMbrObj).isEmpty() ? '' : ' AND (' + String.join(this.processConfig.mbrStatusMap.get(iterMbrObj),' = true OR ') + ' = true)')
                                    + ' ORDER BY ' + this.processConfig.mbrStructMap.get(iterMbrObj);
                //@TODO review case where both with / without status filter is available on member object
                sfpegDebug_UTL.finest('Member Query template init',iterMbrQuery);
                this.processConfig.mbrQueryMap.put(iterMbrObj,iterMbrQuery);
            }
            sfpegDebug_UTL.finest('Member Query template Map built with #Items',this.processConfig.mbrQueryMap.size());
        }
        sfpegDebug_UTL.fine('END for first iteration');
    }

    
    /***
    * @description  Private Constructor used internally by the Management process to
    *               requeue itself when there are still elements to process.
    ***/
    @TestVisible
    private sfpegGroupManagement_UTL(final GlobalConfiguration globalConfig, final ProcessConfiguration processConfig, final Integer iteration, final dateTime deletionTS, final ID lastRecordId) {  // NOPMD bypass long parameter list
        sfpegDebug_UTL.fine('START for new iteration', iteration);
        sfpegDebug_UTL.finer('with deletionTS', deletionTS);
        sfpegDebug_UTL.finer('and lastRecordId', lastRecordId);
        this.creationTS     = System.now();
        this.globalConfig   = globalConfig;
        this.processConfig  = processConfig;
        this.iteration      = iteration;
        this.deletionTS     = deletionTS;
        this.lastRecordId   = lastRecordId;
        sfpegDebug_UTL.fine('END for new iteration', iteration);
    }


    /***
    * @description  Private Constructor used internally by the Management process to
    *               requeue itself to complete in the last step of a 2 step process
    *               (because of mixed DML constraints).
    *               This constructor is meant to pass the execContext and the
    *               list of processed Structure records with their structStatus
    *               field updated for upsert.
    ***/
    @TestVisible
    private sfpegGroupManagement_UTL(final GlobalConfiguration globalConfig, final ProcessConfiguration processConfig, final Integer iteration, final dateTime deletionTS, final ID lastRecordId, final sfpegQueueableContext_SVC execContext, final Map<ID,SObject> structureMap, final Boolean doFilter) {  // NOPMD bypass long parameter list 
        sfpegDebug_UTL.fine('START for 2nd step of iteration',iteration);
        sfpegDebug_UTL.finer('with deletionTS', deletionTS);
        sfpegDebug_UTL.finer('with lastRecordId', lastRecordId);
        sfpegDebug_UTL.finer('with execContext', execContext);
        sfpegDebug_UTL.finer('and #records', structureMap?.size());
        this.creationTS     = System.now();
        this.globalConfig   = globalConfig;
        this.processConfig  = processConfig;
        this.iteration      = iteration;
        this.deletionTS     = deletionTS;
        this.lastRecordId   = lastRecordId;
        this.execContext    = execContext;
        this.structureMap   = structureMap;
        this.doFilter       = doFilter;
        sfpegDebug_UTL.fine('END for 2nd step of iteration',iteration);
    }


    //################################################################################################
    // MAIN EXECUTION LOGIC
    //################################################################################################
    
    /***
    * @description  Main execute method of the Group Management process.
    *               It basically looks for Structure records requiring Public Groups
    *               reevaluation via the structStatus flag (see configuration).
    *               It then checks local, upwards and downwards existence, members
    *               and memberships via dedicated utility methods.
    *               It also manages the requeuing of the process if 
    *               there are still possible Structure records to process.
    *               In order to cope with "MixedDML" constraint, the logic processed
    *               may be split in 2 steps, i.e. a first execution on Setup objects
    *               (Groups & Group Members) followed by a second execution on standard
    *               objects to log the execution Context and upsert the structStatus
    *               field of the processed Structure records.
    *               In case of system limit exception, the process reduces the maxXXX
    *               properties and requests a new execution, until the 1 minimum is reached
    *               for all of them. For other exceptions, it directly stops.
    * @return       sfpegGroupManagement_UTL Group Management operation to be executed
    *               in a new enqueued process (null if end of processing reached)
    * @exception    None special (all catched and logged).
    ***/     
    public sfpegGroupManagement_UTL execute(){  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.info('START for iteration',this.iteration);
        sfpegDebug_UTL.finest('Current globalConfig',this.globalConfig);
        sfpegDebug_UTL.finest('Current groupConfigs',this.globalConfig?.groupConfigs);

        // Controlling finalization of 2 step Group management process
        if (this.execContext != null) {
            sfpegDebug_UTL.debug('Finalizing previous execution with context',this.execContext);
            doRegistrations();
            sfpegDebug_UTL.info('END / Previous execution finalized');
            return new sfpegGroupManagement_UTL(this.globalconfig,this.processConfig,this.iteration + 1, this.deletionTS, this.lastRecordId);
        }
        else {
            this.execContext = new sfpegQueueableContext_SVC(this.globalConfig.className,this.iteration, this.creationTS);
            sfpegDebug_UTL.finer('New context init',this.execContext);

            // Check if we're within the allowed ratio of DailyAsyncApexExecutions
            if (!sfpegQueueable_UTL.isWithinExecutionRatio()) {
                execContext.logExecutionAbort('STOP: Daily queueable limit reached');
                sfpegDebug_UTL.warn('END / Queueable limit reached');
                return null;
            }

            String lastContext = sfpegQueueable_UTL.getLastContext(this.globalConfig.className);
            sfpegDebug_UTL.finer('LastContext fetched',lastContext);
            if (String.isNotEmpty(lastContext)) {
                parseContext(lastContext);
            }

            try {
                // Controlling Public Groups to delete (2 steps)
                if (processGroups2Delete()) {
                    sfpegDebug_UTL.info('END / Public Groups deleted for deleted Structures');
                    //return new sfpegGroupManagement_UTL(this.globalconfig,this.processConfig,this.iteration + 1, this.deletionTS, this.lastRecordId);
                    return new sfpegGroupManagement_UTL(this.globalconfig, this.processConfig, this.iteration, this.deletionTS, this.lastRecordId, this.execContext, null, false);
                }

                // Controlling Public Groups to create (1 step)
                else if (processMissingGroups()) {
                    sfpegDebug_UTL.info('END / New Public Groups created and registered on Structures');
                    return new sfpegGroupManagement_UTL(this.globalconfig,this.processConfig,this.iteration + 1, this.deletionTS, this.lastRecordId);
                }

                // Processing Public Group Membership control (2 steps)
                else if (doMembershipControl()) {
                    sfpegDebug_UTL.debug('Structure Groups need Memberships control');
                    fetchMemberships();
                    sfpegDebug_UTL.debug('Memberships fetched');
                    Map<ID,SObject> updateMap = controlMembership();
                    sfpegDebug_UTL.info('END  / Structure Group Memberships updated - Requesting finalization step');
                    return new sfpegGroupManagement_UTL(this.globalconfig, this.processConfig, this.iteration, this.deletionTS, this.lastRecordId, this.execContext, updateMap, true);
                }

                // Handling Process termination 
                else {
                    execContext.logExecutionEnd(stringifyContext());
                    sfpegDebug_UTL.info('END  / Terminating the process');
                    return null;
                }
            }
            catch (System.LimitException e) {
                Boolean minReached = ((this.globalconfig.maxCreate == 1) && (this.globalconfig.maxUpdate == 1) && (this.globalconfig.maxDelete == 1));
                if (minReached) {
                    execContext.logExecutionAbort('LIMIT ERROR: ' + e.getMessage(),stringifyContext());
                    sfpegDebug_UTL.error('END  / Ending process upon Limit Exception',e.getMessage());
                    return null;
                }
                else {
                    this.globalconfig.maxCreate = Math.max(1,Math.round(this.globalconfig.maxCreate * .75));
                    this.globalconfig.maxUpdate = Math.max(1,Math.round(this.globalconfig.maxUpdate * .75));
                    this.globalconfig.maxDelete = Math.max(1,Math.round(this.globalconfig.maxDelete * .75));
                    execContext.logExecutionAbort('REQUEUE with max C/U/D: ' + this.globalconfig.maxCreate + '/' + this.globalconfig.maxUpdate + '/' + this.globalconfig.maxDelete, stringifyContext());
                    sfpegDebug_UTL.error('END  / Requeuing reduced process because of system limit',e.getMessage());
                    return new sfpegGroupManagement_UTL(this.globalconfig,this.processConfig,this.iteration + 1, this.deletionTS, this.lastRecordId);
                }
            }
            catch (Exception e){
                execContext.logExecutionAbort('ERROR: ' + e.getMessage(), stringifyContext());
                sfpegDebug_UTL.error('END  / Ending process upon Exception',e);
                return null;
            }
        }
    }

    /***
    * @description	Utility method to finalize a 2 step process (registering queueable log record as well
    *               as updating Structure record status if needed), when first step has been executed
    *               in Setup domain (i.e. when prior execution has added/removed Group Members).
    *               For Group Member reeevaluations, a Structure map is provided for status update.
    *               For Group deletion (which may generate GroupMember deletions thus Setup DMLs),
    *               no structure map is provided (strures being indeed already deleted).
    * @param		waitTime	Wait time observed
    * @exception	None special (all catched and logged).
    ***/
    @TestVisible
    private void doRegistrations(){  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.fine('START');

        if ((this.structureMap == null) || (this.structureMap.isEmpty())) {
            sfpegDebug_UTL.fine('Handling only log registration');
        }
        else {
            sfpegDebug_UTL.fine('Handling status update for #items',this.structureMap.size());
            
            // Upserting the Structure (after filtering of Structure modified while waiting)
            if (this.doFilter) {
                sfpegDebug_UTL.fine('Filtering Structure list with #items',this.structureMap.size());

                // Preparation
                sfpegDebug_UTL.finest('Using registration Query',this.processConfig.registerQuery); 
                Map<String, Object> queryParams = new Map<String, Object>{
                    'structureIds'  => this.structureMap.keySet(),
                    'timestamp'     => this.creationTS};
                sfpegDebug_UTL.finest('Query Params init',queryParams);
            
                // Structure Fetch
                Map<ID,SObject> updatedStructMap = new Map<ID,SObject>(Database.queryWithBinds(this.processConfig.registerQuery,queryParams,AccessLevel.SYSTEM_MODE));
                sfpegDebug_UTL.fine('Modified Structures fetched with #items ',updatedStructMap.size());
                sfpegDebug_UTL.finest('Modified Structures fetched ',updatedStructMap);

                // Structure Analysis
                if (updatedStructMap.size() > 0) {
                    sfpegDebug_UTL.finest('Filtering Structures for status change');
                    for (SObject iter : this.structureMap.values()) {
                        if (updatedStructMap.containsKey(iter.Id)) {
                            sfpegDebug_UTL.finest('Keeping original status for structure',iter.Id);
                            iter.put(this.globalConfig.structStatus, true);
                        }
                    }
                    sfpegDebug_UTL.finest('Structures for status change filtered');
                }
                else {
                    sfpegDebug_UTL.fine('No structure to filter for status change');
                }
            }
            else {
                sfpegDebug_UTL.fine('No structure filtering for status change configured');
            }

            Database.SaveResult[] updateResults = database.update(this.structureMap.values(),false);
            sfpegDebug_UTL.finest('Structures updated');
        }

        // Execution logging
        this.execContext.logExecution(null,stringifyContext());

        sfpegDebug_UTL.fine('END');
        return;
    }

    /***
    * @description	Utility method to parse the context fetched from a prior Queueable log record
    *               and init the deletionTS and lastRecordId parameters.
    *               Reverse method from stringifyContext()
    ***/
    @TestVisible
    private void parseContext(final String contextString) {
        sfpegDebug_UTL.finer('START with',contextString);

        if (String.isBlank(contextString)) {
            sfpegDebug_UTL.finer('END  No context provided');
        }
        else {
            List<String> contextParts = contextString.split('###');
            if (String.isNotBlank(contextParts[0])) {
                this.deletionTS =  Datetime.valueOfGMT(contextParts[0]);
                sfpegDebug_UTL.finer('deletionTS init',this.deletionTS);
            }
            if ((contextParts.size() > 1) && (String.isNotBlank(contextParts[1]))) {
                this.lastRecordId =  contextParts[1];
                sfpegDebug_UTL.finer('lastRecordId init',this.lastRecordId);
            }
            sfpegDebug_UTL.finer('END / Context init');
        }
    }

    /***
    * @description	Utility method to stringify the context to be stored on the Queueable log record
    *               from the current deletionTS and lastRecordId parameters.
    *               Reverse method from parseContext().
    ***/
    @TestVisible
    private String stringifyContext() {
        sfpegDebug_UTL.finer('START with deletionTS',this.deletionTS);
        sfpegDebug_UTL.finer('END with lastRecordId',this.lastRecordId);
        return (this.deletionTS == null ? '' : this.deletionTS.formatGmt('yyyy-MM-dd HH:mm:ss') + (String.isBlank(this.lastRecordId) ? '' : '###' + this.lastRecordId));
    }


    //################################################################################################
    // GROUP MANAGEMENT LOGIC
    //################################################################################################

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
    private Boolean processGroups2Delete(){  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.fine('START');
        this.execContext.operationName = OPE_DELETE;

        // Query Preparation
        sfpegDebug_UTL.finest('Using delete Query',this.processConfig.deleteQuery); 
        Map<String, Object> queryParams = new Map<String, Object>{
            'maxDelete'     => this.globalConfig.maxDelete,
            'timestamp'     => this.deletionTS,
            'lastRecordId'  => this.lastRecordId};
        sfpegDebug_UTL.finest('Query Params init',queryParams);

        // Structure fetch
        this.structureMap = new Map<ID,SObject>(Database.queryWithBinds(this.processConfig.deleteQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.finer('#Deleted Structures fetched',this.structureMap.size());

        if (this.structureMap.size() == 0) {
            this.deletionTS = this.creationTS;
            this.lastRecordId = null;
            sfpegDebug_UTL.fine('END / No Public Group to delete for any Structure');
            return false;
        }

        // Structure analysis
        Map<ID,ID> grpIDs2delete = new Map<ID,ID>(); // Map per Group ID of the related Structure ID
        for (SObject iter : this.structureMap.values()) {
            sfpegDebug_UTL.finest('Removing Groups for Structure',iter.get(this.globalConfig.structKey));
            for (String iterGrp : this.processConfig.localGroups) {
                ID iterGrpId = (ID)iter.get(iterGrp);
                if (iterGrpId != null) {
                    grpIDs2delete.put(iterGrpId,iter.Id);
                }
            }
            for (String iterGrp : this.processConfig.upGroups) {
                ID iterGrpId = (ID)iter.get(iterGrp);
                if (iterGrpId != null) {
                    grpIDs2delete.put(iterGrpId,iter.Id);
                }
            }
            for (String iterGrp : this.processConfig.downGroups) {
                ID iterGrpId = (ID)iter.get(iterGrp);
                if (iterGrpId != null) {
                    grpIDs2delete.put(iterGrpId,iter.Id);
                }
            }
            this.deletionTS = (DateTime)iter.get('SystemModStamp'); // to track last one
            this.lastRecordId = (ID)iter.get('Id');
        }
        sfpegDebug_UTL.finer('#Groups to delete identified',grpIDs2delete.size());

        // Logic Execution
        Set<ID> grpIDs = (Set<ID>) grpIDs2delete.keySet();
        Database.DeleteResult[] deleteResults = database.delete(new List<ID>(grpIDs),false);     
        
        // Execution logging
        //this.execContext.registerOK((Set<String>)(this.structureMap.keySet()));
        for (ID iter : this.structureMap.keySet()) {this.execContext.registerOK((String)iter);}
        for(Database.DeleteResult iter : deleteResults) {
            if (!iter.isSuccess()) {
                ID iterStructID = grpIDs2delete.get(iter.getId());
                sfpegDebug_UTL.finest('Registering structure ID as KO',iterStructID);
                sfpegDebug_UTL.finest('Error details',iter.getErrors());
                this.execContext.registerKO((String)(iterStructID));
            }
        }
        //execContext.logExecution(null,stringifyContext());

        sfpegDebug_UTL.fine('END / Public Groups deleted for deleted #Structures',this.structureMap.size());
        return true;
    }

    /***
    * @description  Method to check if all Structures have related Public Groups
    *               created and registered (local, upwards and or downwards).
    *               If any Structure has missing Public Groups, they are automatically
    *               created and registered in their group idntification fields.
    *               It basically enables to handle the creation of new Structures.
    *               This method should be systematically called before executing
    *               the membership evaluation logic.
    * @return       Boolean	Returns true if Structures with missing Public Groups have been
    *               found, in which case, group membership logic should be bypassed.
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private Boolean processMissingGroups() {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.fine('START');
        this.execContext.operationName = OPE_CREATE;

        // Query Preparation
        sfpegDebug_UTL.finest('Using create Query',this.processConfig.createQuery); 
        Map<String, Object> queryParams = new Map<String, Object>{
            'maxCreate'     => this.globalConfig.maxCreate};
        sfpegDebug_UTL.finest('Query Params init',queryParams);

        // Structure Fetch
        this.structureMap = new Map<ID,SObject>(Database.queryWithBinds(this.processConfig.createQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.finer('#Structures with missing Groups fetched',this.structureMap.size());

        if (this.structureMap.size() == 0) {
            sfpegDebug_UTL.fine('END / Public Group OK declared for all Structures');
            return false;
        }

        // Structure Analysis
        Map<Id,Schema.RecordTypeInfo> recordTypeMap;
        if (this.globalConfig.useRT) {
            sfpegDebug_UTL.finest('Group Naming with RT');
            recordTypeMap = ((SObject)Type.forName('Schema.' + this.globalConfig.structObject).newInstance()).getSObjectType().getDescribe().getRecordTypeInfosById();
        }

        Map<String,Map<String,Group>> groupMap = new Map<String,Map<String,Group>>();
        List<Group> groups2add = new List<Group>();
        for (SObject iter : this.structureMap.values()) {
            sfpegDebug_UTL.finest('Adding Groups for Structure', iter);
            String iterKey = (String) iter.get(this.globalConfig.structKey);
            sfpegDebug_UTL.finest('Structure Key fetched',iterKey);

            Map<String,Group> iterGroupMap = new Map<String,Group>();
            groupMap.put(iterKey,iterGroupMap);
            for (GroupConfiguration iterConfig : this.globalConfig.groupConfigs.values()) {
                sfpegDebug_UTL.finest('Processing config', iterConfig.suffix);

                String nameRoot = (String.isNotBlank(iterConfig.prefix) ? iterConfig.prefix + '_' : '');
                if ((this.globalConfig.useRT) && (String.isNotBlank((String)iter.get('RecordTypeId')))) {
                    sfpegDebug_UTL.finest('Structure RecordType ID fetched', iter.get('RecordTypeId'));
                    nameRoot += recordTypeMap.get((String)iter.get('RecordTypeId')).getDeveloperName() + '_' + iterKey;
                }
                else {
                    sfpegDebug_UTL.finest('No Structure RecordType ID');
                    nameRoot += iterKey;
                }
                nameRoot += (String.isNotBlank(iterConfig.suffix) ? '_' + iterConfig.suffix : '');
                sfpegDebug_UTL.finest('NameRoot initialized', nameRoot);

                // Local Group Init
                sfpegDebug_UTL.finest('Checking Local Group',iterConfig.structLocal);
                if (iter.get(iterConfig.structLocal) == null) {
                    Group newGrp = new Group(Name = nameRoot + iterConfig.localSuffix);
                    sfpegDebug_UTL.finest('Adding Local Group', newGrp);
                    iterGroupMap.put(iterConfig.structLocal,newGrp);
                    groups2add.add(newGrp);
                }
                else {
                    sfpegDebug_UTL.finest('Local Group already exists', iter.get(iterConfig.structLocal));
                }

                // Upwards Group Init
                if (String.isNotBlank(iterConfig.structUp)) {
                    sfpegDebug_UTL.finest('Checking Upwards Group',iterConfig.structUp);
                    if (iter.get(iterConfig.structUp) == null) {
                        Group newGrp = new Group(Name = nameRoot + iterConfig.upSuffix);
                        sfpegDebug_UTL.finest('Adding Upwards Group', newGrp);
                        iterGroupMap.put(iterConfig.structUp,newGrp);
                        groups2add.add(newGrp);
                    }
                    else {
                        sfpegDebug_UTL.finest('Upwards Group already exists', iter.get(iterConfig.structUp));
                    }
                }
                else {
                    sfpegDebug_UTL.finest('No Upwards Group to manage');
                }

                // Downwards Group Init
                if (String.isNotBlank(iterConfig.structDown)) {
                    sfpegDebug_UTL.finest('Checking Downwards Group',iterConfig.structDown);

                    if (iter.get(iterConfig.structDown) == null) {
                        Group newGrp = new Group(Name = nameRoot + iterConfig.downSuffix);
                        sfpegDebug_UTL.finest('Adding Downwards Group', newGrp);
                        iterGroupMap.put(iterConfig.structDown,newGrp);
                        groups2add.add(newGrp);
                    }
                    else {
                        sfpegDebug_UTL.finest('Downwards Group already exists', iter.get(iterConfig.structDown));
                    }
                }
                else {
                    sfpegDebug_UTL.finest('No Downwards Group to manage');
                }
            }
        }
        sfpegDebug_UTL.finer('#Groups to add',groups2add.size());
        sfpegDebug_UTL.finer('#Structures to update',groupMap.size());

        // Logic Execution
        Database.SaveResult[] insertResults = database.insert(groups2add,false);
        sfpegDebug_UTL.finer('New Public Groups inserted');

        Set<String> koStructures = new Set<String>();
        DateTime currentTS = System.now();
        for (SObject iter : this.structureMap.values()) {
            String iterKey = (String)iter.get(this.globalConfig.structKey);
            sfpegDebug_UTL.finest('Registering group IDs on Structure',iterKey);
            
            Map<String,Group> iterGroupMap = groupMap.get(iterKey);
            for (String iterGroup : iterGroupMap.keySet()) {
                String iterGroupId = (String) (iterGroupMap.get(iterGroup).Id);
                if (String.isNotBlank(iterGroupId)) {
                    sfpegDebug_UTL.finest('Setting Group ID field',iterGroup);
                    sfpegDebug_UTL.finest('with value',iterGroupId);
                    iter.put(iterGroup,iterGroupId);
                }
                else {
                    sfpegDebug_UTL.warn('Missing Group ID value for field',iterGroup);
                    sfpegDebug_UTL.warn('on structure',iter.Id);
                    koStructures.add((String)(iter.Id));
                }
            }
            if (koStructures.contains((String)(iter.Id))) {
                iter.put(this.globalConfig.structMsg,'Group creation failed');
                iter.put(this.globalConfig.structStatus,false);
                iter.put(this.globalConfig.structTS,currentTS);
            }
            else {
                iter.put(this.globalConfig.structMsg,'Group creation succeeded');
            }
        }
        sfpegDebug_UTL.finer('Public Group IDs registered on Structures');
        sfpegDebug_UTL.finer('#Structures with missing Group ID',koStructures.size());
        sfpegDebug_UTL.finest('Structures with missing Group ID',koStructures);

        Database.SaveResult[] updateResults = database.update(this.structureMap.values(),false);
        sfpegDebug_UTL.finest('Structures updated with Group IDs');

        // Execution logging
        execContext.analyseResults(updateResults);
        execContext.registerKO(koStructures);
        execContext.logExecution(null,stringifyContext());

        sfpegDebug_UTL.fine('END / New Public Group IDs registered on #Structures',this.structureMap.size());
        return true;
    }

    /***
    * @description  Method checking for the availability of Structure records for
    *               Public Group Membership control process (i.e. with statusFlag 
    *               set to true).
    *               If any structure available, both structureMap and memberMap
    *               variables are initialized for later processing with all
    *               Structures (including related parents and children) and related Members.
    *               It assumes that all Structures have their Public Groups initialized.
    * @return       Boolean	Indicates whether there are Structures for which
    *               Public Groups should be reevaluated (true if any).
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private Boolean doMembershipControl() {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.fine('START');
        this.execContext.operationName = OPE_UPDATE;

        // Preparation
        sfpegDebug_UTL.finest('Using update Query',this.processConfig.updateQuery); 
        Map<String, Object> queryParams = new Map<String, Object>{
            'maxUpdate'     => this.globalConfig.maxUpdate};
        sfpegDebug_UTL.finest('Query Params init',queryParams);

        // Checking Structures with membership to process
        this.structureMap = new Map<ID,SObject>(Database.queryWithBinds(this.processConfig.updateQuery,queryParams,AccessLevel.SYSTEM_MODE));
        sfpegDebug_UTL.finer('#Structures fetched for group control',this.structureMap.size());
        if (this.structureMap.size() == 0) {
            sfpegDebug_UTL.fine('END / Nothing to process');
            return false;
        }

        // Fetching Structure related Members
        this.memberMap = new Map<String,Map<ID,List<SObject>>>();
        Map<String, Object> mbrQueryParams = new Map<String, Object>{
            'structureIds' => this.structureMap.keySet()};
        
        for (String iterMbrObj : this.processConfig.mbrQueryMap.keySet()) {
            sfpegDebug_UTL.finer('Fetching members on object',iterMbrObj);
            sfpegDebug_UTL.finest('Using member Query',this.processConfig.mbrQueryMap.get(iterMbrObj)); 

            List<SObject> iterMembers = Database.queryWithBinds(this.processConfig.mbrQueryMap.get(iterMbrObj),mbrQueryParams,AccessLevel.SYSTEM_MODE); // NOPMD bypass operations in loops as number of iterations is limited
            sfpegDebug_UTL.finer('#Members fetched',iterMembers.size());

            Map<ID,List<SObject>> iterMbrMap = new Map<ID,List<SObject>>();
            String iterLookup = this.processConfig.mbrStructMap.get(iterMbrObj);
            for (SObject iterMbr : iterMembers) {
                ID iterMbrStruct = (ID) iterMbr.get(iterLookup);
                if (!iterMbrMap.containsKey(iterMbrStruct)) {iterMbrMap.put(iterMbrStruct,new List<SObject>());}
                iterMbrMap.get(iterMbrStruct).add(iterMbr);
            }
            sfpegDebug_UTL.finer('Members split over #Structures',iterMbrMap.size());
            this.memberMap.put(iterMbrObj,iterMbrMap);
        }
        sfpegDebug_UTL.fine('#Member Objects processed',this.memberMap.size());

        sfpegDebug_UTL.fine('END / #Structures to process',this.structureMap.size());
        return true;
    }

    /***
    * @description  Membership data fetch and initialization for Group control
    *               It parses processed Structures and their parents / children
    *               to identify Group IDs to check and fetches their GroupMembers.
    *               It fetches all members for local, up and down groups of
    *               processed Structures, but only down groups for parents
    *               and up groups for children.
    *               For parent and children members, only those applicable
    *               to the up / down groups of the processed Structures are fetched
    *               (to prevent too many rows from being fetched).
    *               It assumes that the structureMap has been propserly initialized
    *               via the doMembershipControl() method and initializes the groupMap
    *               variable with the results of its GroupMember fetches.
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private void fetchMemberships() {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.fine('START');
        this.execContext.operationName = 'UPDATE';

        // Extracting Group IDs
        sfpegDebug_UTL.finest('Processing Structures / Fetching Groups');
        this.groupMap = new Map<String,Map<ID,Set<GroupMember>>>{
            'local' => new Map<ID,Set<GroupMember>>(),
            'up' => new Map<ID,Set<GroupMember>>(),
            'down' => new Map<ID,Set<GroupMember>>(),
            'parentDown' => new Map<ID,Set<GroupMember>>(),
            'childUp' => new Map<ID,Set<GroupMember>>()
        };

        for (SObject iter : this.structureMap.values()) {
            sfpegDebug_UTL.finest('Fetching Groups for Structure ',iter.get('Name'));
            sfpegDebug_UTL.finest('Structure data ',iter);
            sfpegDebug_UTL.finest('Structure parent ',iter.getSobject(this.globalConfig.structParent));
            sfpegDebug_UTL.finest('Structure children ',iter.getSobjects(this.globalConfig.structChildren));
            
            // Registering Group IDs for Current Structure
            Map<ID,Set<GroupMember>> groupSet = this.groupMap.get('local');
            for (String iterGroup : this.processConfig.localGroups) {
                groupSet.put((String)iter.get(iterGroup),new Set<GroupMember>());
            }
            groupSet = this.groupMap.get('up');
            for (String iterGroup : this.processConfig.upGroups) {
                groupSet.put((String)iter.get(iterGroup),new Set<GroupMember>());
            }
            groupSet = this.groupMap.get('down');
            for (String iterGroup : this.processConfig.downGroups) {
                groupSet.put((String)iter.get(iterGroup),new Set<GroupMember>());
            }
            sfpegDebug_UTL.finest('Structure Group IDs registered');
    
            // Registering Group IDs for Parent Structures
            if ( iter.getSobject(this.globalConfig.structParent) != null)  {
                SObject iterParent = (SObject) iter.getSobject(this.globalConfig.structParent);
                sfpegDebug_UTL.finest('Registering Group IDs for parent Structure',iterParent);
                groupSet = this.groupMap.get('parentDown');
                for (String iterGroup : this.processConfig.downGroups) {
                    groupSet.put((String)iterParent.get(iterGroup),new Set<GroupMember>());
                }
            }
            else {
                sfpegDebug_UTL.finest('No parent Structure to process');
            }

            // Registering Group IDs for Children Structures
            if (iter.getSobjects(this.globalConfig.structChildren) != null) {
                sfpegDebug_UTL.finest('Processing children Structures');
                List<SObject> iterChildren = (List<SObject>) iter.getSobjects(this.globalConfig.structChildren);
                sfpegDebug_UTL.finest('#Structure Children provided',iterChildren.size());

                for (SObject iterChild : iterChildren) {
                    sfpegDebug_UTL.finest('Registering Group IDs for child Structure',iterChild);
                    groupSet = this.groupMap.get('childUp');
                    for (String iterGroup : this.processConfig.upGroups) {
                        groupSet.put((String)iterChild.get(iterGroup),new Set<GroupMember>());
                    }
                }
            }
            else {
                sfpegDebug_UTL.finest('No Children Structures to process');
            }
        }
        sfpegDebug_UTL.fine('Group ID Map initialized');
        for (String iter : this.groupMap.keySet()) {
            sfpegDebug_UTL.finest('Group Type processed',iter);
            sfpegDebug_UTL.finest('#Group IDs identified',this.groupMap.get(iter).size());
        }

        // Fetching Group Members
        Map<ID,Set<GroupMember>> groupMbrs = this.groupMap.get('local');
        for (GroupMember iter : [SELECT UserOrGroupId, GroupId FROM GroupMember WHERE GroupId IN :groupMbrs.keySet() WITH SYSTEM_MODE]) {
            groupMbrs.get(iter.GroupId).add(iter);
        }
        sfpegDebug_UTL.fine('Group Members registered for #Local Groups',groupMbrs.size());

        groupMbrs = this.groupMap.get('upwards');
        if (groupMbrs != null) {
            for (GroupMember iter : [SELECT UserOrGroupId, GroupId FROM GroupMember WHERE GroupId IN :groupMbrs.keySet() WITH SYSTEM_MODE]) {
                groupMbrs.get(iter.GroupId).add(iter);
            }
            sfpegDebug_UTL.fine('Group Members registered for #Upwards Groups',groupMbrs.size());
        }
        else {
            sfpegDebug_UTL.fine('No Upwards Groups to fetch');
        }

        groupMbrs = this.groupMap.get('downwards');
        if (groupMbrs != null) {
            for (GroupMember iter : [SELECT UserOrGroupId, GroupId FROM GroupMember WHERE GroupId IN :groupMbrs.keySet() WITH SYSTEM_MODE]) {
                groupMbrs.get(iter.GroupId).add(iter);
            }
            sfpegDebug_UTL.fine('Group Members registered for #Downwards Groups',groupMbrs.size());
        }
        else {
            sfpegDebug_UTL.fine('No Downwards Groups to fetch');
        }

        groupMbrs = this.groupMap.get('parentDown');
        Set<ID> checkGroups;
        if (groupMbrs != null) {
            checkGroups = this.groupMap.get('down').keySet();
            for (GroupMember iter : [SELECT UserOrGroupId, GroupId FROM GroupMember WHERE (GroupId IN :groupMbrs.keySet()) AND (UserOrGroupId IN :checkGroups)  WITH SYSTEM_MODE]) {
                groupMbrs.get(iter.GroupId).add(iter);
            }
            sfpegDebug_UTL.fine('Group Members registered for #Parent Downwards Groups',groupMbrs.size());
        }
        else {
            sfpegDebug_UTL.fine('No Parent Downwards Groups to fetch');
        }

        groupMbrs = this.groupMap.get('childUp');
        if (groupMbrs != null) {
            checkGroups = this.groupMap.get('up').keySet();
            for (GroupMember iter : [SELECT UserOrGroupId, GroupId FROM GroupMember WHERE (GroupId IN :groupMbrs.keySet()) AND (UserOrGroupId IN :checkGroups)  WITH SYSTEM_MODE]) {
                groupMbrs.get(iter.GroupId).add(iter);
            }
            sfpegDebug_UTL.fine('Group Members registered for #Child Upwards Groups',groupMbrs.size());
        }
        else {
            sfpegDebug_UTL.fine('No Child Upwards Groups to fetch');
        }

        sfpegDebug_UTL.fine('END');
    }

    /***
    * @description  Method to check the GroupMembers required for the processed Structures.
    *               It assumes that context has been properly initialized via the 
    *               doMembershipControl() and fetchMemberships() methods.
    *               It basically checks for each processed Structure the
    *               members of each local, up and down groups as well as the
    *               memberships of up and down groups respectively in their
    *               child up and parent down groups.
    *               It adds/removes GroupMembers when needed and returns
    *               the map of processed structures with structStatus, structTS
    *               and structMsg updated. 
    * @exception    None special (all catched and logged).
    ***/
    @TestVisible
    private Map<ID,SObject> controlMembership() {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.fine('START with #Structures',this.structureMap.size());

        Map<ID,SObject> struct4update = new Map<ID,SObject>();
        DateTime currentTS = System.now();
        //System.Type structureObject = Type.forName('Schema.' + this.globalConfig.structObject);
        Schema.SObjectType structureObject = ((SObject)Type.forName('Schema.' + this.globalConfig.structObject).newInstance()).getSObjectType();
        //recordTypeMap = ((SObject)Type.forName('Schema.' + this.globalConfig.structObject).newInstance()).getSObjectType().getDescribe().getRecordTypeInfosById();
        sfpegDebug_UTL.finest('Structure SObject Type fetched', structureObject);

        // Executing the controls on all fetched Structures.
        for (SObject iter : this.structureMap.values()) {
            sfpegDebug_UTL.finest('Processing Structure',iter.Id);

            for (GroupConfiguration iterConfig : this.globalConfig.groupConfigs.values()) {
                sfpegDebug_UTL.finest('Checking Local Group',iterConfig.structLocal);
                checkLocalGroup(iter,iterConfig);

                if (String.isNotBlank(iterConfig.structUp)) {
                    sfpegDebug_UTL.finest('Checking Up Group',iterConfig.structUp);
                    checkUpGroup(iter,iterConfig);
                }
                
                if (String.isNotBlank(iterConfig.structDown)) {
                    sfpegDebug_UTL.finest('Checking Down Group',iterConfig.structDown);
                    checkDownGroup(iter,iterConfig);
                }
            }

            // Registering Structure as processed.
            //SObject iterUpdate = structureObject.newInstance();
            SObject iterUpdate = structureObject.newSObject((ID)iter.get('Id'));
            //iterUpdate.put('Id',(ID)iter.get('Id'));
            iterUpdate.put(this.globalConfig.structStatus, false);
            iterUpdate.put(this.globalConfig.structTS, currentTS);
            iterUpdate.put(this.globalConfig.structMsg, 'Member checked');
            struct4update.put((ID)iter.get('Id'), iterUpdate);
        }
        sfpegDebug_UTL.fine('All #Structures processed',struct4update.size());

        // Updating the database (Setup GroupMember Object)
        Database.SaveResult[] insertResults = database.insert(this.gm2add.values(),false);
        sfpegDebug_UTL.fine('#New Group Memberships added',this.gm2add.size());
        Database.DeleteResult[] deleteResults = database.delete(new List<ID>(this.gm2remove),false);        
        sfpegDebug_UTL.fine('#Old Group Memberships removed',this.gm2remove.size());

        // Execution logging
        //this.execContext.registerOK((Set<String>)(this.structureMap.keySet()));
        for (ID iter : this.structureMap.keySet()) {this.execContext.registerOK((String)iter);}
        for(Integer index = 0; index < insertResults.size(); index++) {
            if (!insertResults[index].isSuccess()) {
                GroupMember iterGM = (this.gm2add.values()).get(index);
                sfpegDebug_UTL.finest('Registering GM as KO',iterGM);
                ID iterStructID = this.structure4gm.get(iterGM.GroupId + '-' + iterGM.UserOrGroupId);
                sfpegDebug_UTL.finest('for Structure',iterStructID);
                sfpegDebug_UTL.finest('Error details',insertResults[index].getErrors());
                this.execContext.registerKO((String)(iterStructID));
                struct4update.get(iterStructID).put(this.globalConfig.structMsg, 'Member insertion failed');
            }
        }
        for(Database.DeleteResult iter : deleteResults) {
            if (!iter.isSuccess()) {
                ID iterStructID = this.structure4gm.get((String)iter.getId());
                sfpegDebug_UTL.finest('Registering structure ID as KO',iterStructID);
                sfpegDebug_UTL.finest('Error details',iter.getErrors());
                this.execContext.registerKO((String)(iterStructID));
                struct4update.get(iterStructID).put(this.globalConfig.structMsg, 'Member deletion failed');
            }
        }

        sfpegDebug_UTL.fine('END');
        return struct4update;
    }

    /***
    * @description  Method to check/update the members of the Local Public Group
    *               of the Structures.
    *               Each local Group should contain only GroupMembers (of User or Group
    *               type) corresponding to the Structure (via structMbrIDs) and/or its 
    *               related Member object records (via mbrIDs) as defined in the provided
    *               Configuration.
    *               The gm2add, gm2remove, structure4gm global variables are directly
    *               updated depending on the GroupMembers to add/remove.
    * @exception	None special (all catched and logged).
    ***/
    @TestVisible
    private void checkLocalGroup(final SObject structure, final GroupConfiguration config) {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.finer('START for structure',structure.get('Id'));
        sfpegDebug_UTL.finest('and group',config.structLocal);

        // Fetching current situation
        ID groupId = (ID) structure.get(config.structLocal);
        sfpegDebug_UTL.finest('Local Group ID fetched',groupId);

        Set<GroupMember> currentGMs = this.groupMap.get('local').get(groupId);
        sfpegDebug_UTL.finer('#Current Group Members fetched',currentGMs.size());

        // Determining reference situation
        Set<ID> refGMs = new Set<ID>();
        if ((config.structMbrIDs != null) && (!config.structMbrIDs.isEmpty())) {
            for (String iterField : config.structMbrIDs) {
                sfpegDebug_UTL.finest('Processing Structure member field',iterField);
                ID iterMbrID = (ID) structure.get(iterField);
                if (String.isNotBlank((String)iterMbrID)) {
                    sfpegDebug_UTL.finest('Registering member ID',iterMbrID);
                    refGMs.add(iterMbrID);
                }
            }
        }
        if ((config.mbrIDs != null) && (!config.mbrIDs.isEmpty())) {
            sfpegDebug_UTL.finest('Processing Member Object',config.mbrObject);
            List<SObject> mbrRecords = this.memberMap.get(config.mbrObject).get((ID)structure.get('Id'));

            if ((mbrRecords == null) || (mbrRecords.isEmpty())) {
                sfpegDebug_UTL.finest('No Member to register');
            }
            else {
                sfpegDebug_UTL.finest('Analysing #Members',mbrRecords.size());
                Boolean noFilter = String.isBlank(config.mbrActive);
                sfpegDebug_UTL.finest('Is filtering deactivated?',noFilter);

                for (SObject iterMbr : mbrRecords) {
                    if (noFilter || ((Boolean)iterMbr.get(config.mbrActive))) {
                        sfpegDebug_UTL.finest('Registering member',iterMbr.get('Id'));
                        for (String iterField : config.mbrIDs) {
                            sfpegDebug_UTL.finest('Processing member field',iterField);
                            ID iterMbrID = (ID) iterMbr.get(iterField);
                            if (String.isNotBlank((String)iterMbrID)) {
                                sfpegDebug_UTL.finest('Registering member ID',iterMbrID);
                                refGMs.add(iterMbrID);
                            }
                        }
                    }
                    else {
                        sfpegDebug_UTL.finest('Ignoring member',iterMbr.get('Id'));
                    }
                }
                sfpegDebug_UTL.finest('All Members processed');
            }
        }
        sfpegDebug_UTL.finer('#Reference Group Members determined',refGMs.size());

        // Comparing Situations
        for (GroupMember iterMbr : currentGMs) {
            if (refGMs.contains(iterMbr.UserOrGroupId)) {
                sfpegDebug_UTL.finer('Reference GM present',iterMbr.UserOrGroupId);
                refGMs.remove(iterMbr.UserOrGroupId);
            }
            else {
                sfpegDebug_UTL.finer('Current GM to remove',iterMbr.UserOrGroupId);
                this.gm2remove.add(iterMbr.Id);
                this.structure4gm.put((String)iterMbr.Id,(ID)structure.get('Id'));
            }
        }
        sfpegDebug_UTL.finer('Current GMs analysed, with #ref GMs to add',refGMs.size());
        for (ID iterMbr : refGMs) {
            sfpegDebug_UTL.finest('Registering missing GM',iterMbr);                
            this.gm2add.put(groupId + '-' + iterMbr,new GroupMember(GroupId = groupId,UserOrGroupId = iterMbr));
            this.structure4gm.put(groupId + '-' + iterMbr,(ID)structure.get('Id'));
        }
        sfpegDebug_UTL.finer('END');
    }


    /***
    * @description  Method to check/update the members and memberships of the Upwards Public Group
    *               of the Structures.
    *               Each upwards Group should contain only GroupMembers of Group type
    *               corresponding to the local group of the structure and the upwards group
    *               of its parent (if any). 
    *               Each upwards Group should be member of all upwards Groups of the structure
    *               children (if any).
    *               The gm2add, gm2remove, structure4gm global variables are directly
    *               updated depending on the GroupMembers to add/remove.
    * @exception	None special (all catched and logged).
    ***/
    @TestVisible
    private void checkUpGroup(final SObject structure, final GroupConfiguration config) {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.finer('START for structure',structure.get('Id'));
        sfpegDebug_UTL.finest('and group',config.structUp);

        // Fetching current situation
        ID groupId = (ID) structure.get(config.structUp);
        sfpegDebug_UTL.finest('Upwards Group ID fetched',groupId);

        Set<GroupMember> currentGMs = this.groupMap.get('up').get(groupId);
        sfpegDebug_UTL.finer('#Current Group Members fetched',currentGMs.size());

        // Determining reference situation
        Set<ID> refGMs = new Set<ID>();
        ID localGroupId = (ID) structure.get(config.structLocal);
        sfpegDebug_UTL.finest('Registering Local Group ID',localGroupId);
        refGMs.add(localGroupId);

        if (structure.getSobject(this.globalConfig.structParent) != null)  {
            SObject iterParent = (SObject) structure.getSobject(this.globalConfig.structParent);
            ID parentGroupId = (ID) iterParent.get(config.structUp);
            sfpegDebug_UTL.finest('Registering Parent Upwards Group IDs',parentGroupId);
            refGMs.add(parentGroupId);
        }
        else {
            sfpegDebug_UTL.finest('No parent Group to register');
        }

        // Comparing situations
        for (GroupMember iterMbr : currentGMs) {
            if (refGMs.contains(iterMbr.UserOrGroupId)) {
                sfpegDebug_UTL.finer('Reference GM present',iterMbr.UserOrGroupId);
                refGMs.remove(iterMbr.UserOrGroupId);
            }
            else {
                sfpegDebug_UTL.finer('Current GM to remove',iterMbr.UserOrGroupId);
                this.gm2remove.add(iterMbr.Id);
                this.structure4gm.put((String)iterMbr.Id,(ID)structure.get('Id'));
            }
        }
        sfpegDebug_UTL.finer('Current GMs analysed, with #ref GMs to add',refGMs.size());
        for (ID iterMbr : refGMs) {
            sfpegDebug_UTL.finest('Registering missing GM',iterMbr);                
            this.gm2add.put(groupId + '-' + iterMbr,new GroupMember(GroupId = groupId,UserOrGroupId = iterMbr));
            this.structure4gm.put(groupId + '-' + iterMbr,(ID)structure.get('Id'));
        }

        // Checking Group memberships
        if (structure.getSobjects(this.globalConfig.structChildren) != null) {
            sfpegDebug_UTL.finest('Analysing children Group memberships');
        
            List<SObject> children = (List<SObject>) structure.getSobjects(this.globalConfig.structChildren);
            sfpegDebug_UTL.finest('#Structure Children to process',children.size());

            for (SObject iterChild : children) {
                sfpegDebug_UTL.finest('Analysing child structure',iterChild.get('Id'));
                ID iterChildGroupId = (ID) iterChild.get(config.structUp);
                sfpegDebug_UTL.finest('Checking membership on child group',iterChildGroupId);
                Set<GroupMember> iterChildMbrs = this.groupMap.get('childUp').get(iterChildGroupId);
                Boolean groupFound = false;
                for (GroupMember iterMbr : iterChildMbrs) {
                    if (iterMbr.UserOrGroupId == groupId) {
                        sfpegDebug_UTL.finest('Group already member of child Group',iterMbr.GroupId);
                        iterChildMbrs.remove(iterMbr);
                        groupFound = true;
                        break;
                    }
                }
                if (!groupFound) {
                    sfpegDebug_UTL.finest('Group missing in child Group',iterChildGroupId);
                    this.gm2add.put(iterChildGroupId + '-' + groupId,new GroupMember(GroupId = iterChildGroupId,UserOrGroupId = groupId));
                    this.structure4gm.put(iterChildGroupId + '-' + groupId,(ID)structure.get('Id'));
                }
            }
        }
        else {
            sfpegDebug_UTL.finest('No child Group membership to check');
        }

        sfpegDebug_UTL.finer('END');
    }


    /***
    * @description  Method to check/update the members and memberships of the Downwards Public Group
    *               of the Structures.
    *               Each downwards Group should contain only GroupMembers of Group type
    *               corresponding to the local group of the structure and the downwards groups
    *               of its children (if any). 
    *               Each downwards Group should be member of the downwards Group of the structure
    *               parent (if any).
    *               The gm2add, gm2remove, structure4gm global variables are directly
    *               updated depending on the GroupMembers to add/remove.
    * @exception	None special (all catched and logged).
    ***/
    @TestVisible
    private void checkDownGroup(final SObject structure, final GroupConfiguration config) {  // NOPMD bypass cognitive complexity
        sfpegDebug_UTL.finer('START for structure',structure.get('Id'));
        sfpegDebug_UTL.finest('and group',config.structDown);

        // Fetching current situation
        ID groupId = (ID) structure.get(config.structDown);
        sfpegDebug_UTL.finest('Downwards Group ID fetched',groupId);

        Set<GroupMember> currentGMs = this.groupMap.get('down').get(groupId);
        sfpegDebug_UTL.finer('#Current Group Members fetched',currentGMs.size());

        // Determining reference situation
        Set<ID> refGMs = new Set<ID>();
        ID localGroupId = (ID) structure.get(config.structLocal);
        sfpegDebug_UTL.finest('Registering Local Group ID',localGroupId);
        refGMs.add(localGroupId);

        if (structure.getSobjects(this.globalConfig.structChildren) != null) {
            sfpegDebug_UTL.finest('Registering children Groups');
        
            List<SObject> children = (List<SObject>) structure.getSobjects(this.globalConfig.structChildren);
            sfpegDebug_UTL.finest('#Structure Children to process',children.size());

            for (SObject iterChild : children) {
                sfpegDebug_UTL.finest('Analysing child structure',iterChild.get('Id'));
                ID iterChildGroupId = (ID) iterChild.get(config.structDown);
                sfpegDebug_UTL.finest('Registering Downwards Group ID',iterChildGroupId);
                refGMs.add(iterChildGroupId);
            }
        }
        else {
            sfpegDebug_UTL.finest('No child Group to register');
        }

        // Comparing situations
        for (GroupMember iterMbr : currentGMs) {
            if (refGMs.contains(iterMbr.UserOrGroupId)) {
                sfpegDebug_UTL.finer('Reference GM present',iterMbr.UserOrGroupId);
                refGMs.remove(iterMbr.UserOrGroupId);
            }
            else {
                sfpegDebug_UTL.finer('Current GM to remove',iterMbr.UserOrGroupId);
                this.gm2remove.add(iterMbr.Id);
                this.structure4gm.put((String)iterMbr.Id,(ID)structure.get('Id'));
            }
        }
        sfpegDebug_UTL.finer('Current GMs analysed, with #ref GMs to add',refGMs.size());
        for (ID iterMbr : refGMs) {
            sfpegDebug_UTL.finest('Registering missing GM',iterMbr);                
            this.gm2add.put(groupId + '-' + iterMbr,new GroupMember(GroupId = groupId,UserOrGroupId = iterMbr));
            this.structure4gm.put(groupId + '-' + iterMbr,(ID)structure.get('Id'));
        }

        // Checking Group memberships
        if (structure.getSobject(this.globalConfig.structParent) != null)  {
            sfpegDebug_UTL.finest('Analysing parent structure');
            SObject iterParent = (SObject) structure.getSobject(this.globalConfig.structParent);
            ID parentGroupId = (ID) iterParent.get(config.structDown);
            sfpegDebug_UTL.finest('Checking membership on parent group',parentGroupId);
            Set<GroupMember> parentMbrs = this.groupMap.get('parentDown').get(parentGroupId);
            Boolean groupFound = false;
            for (GroupMember iterMbr : parentMbrs) {
                if (iterMbr.UserOrGroupId == groupId) {
                    sfpegDebug_UTL.finest('Group already member of parent Group',iterMbr.GroupId);
                    parentMbrs.remove(iterMbr);
                    groupFound = true;
                    break;
                }
            }
            if (!groupFound) {
                sfpegDebug_UTL.finest('Group missing in parent Group',parentGroupId);
                this.gm2add.put(parentGroupId + '-' + groupId,new GroupMember(GroupId = parentGroupId,UserOrGroupId = groupId));
                this.structure4gm.put(parentGroupId + '-' + groupId,(ID)structure.get('Id'));
            }
        }
        else {
            sfpegDebug_UTL.finest('No parent Group membership to check');
        }
    }
}