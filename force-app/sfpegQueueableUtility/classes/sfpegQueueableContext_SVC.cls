/***
* @description  Service class enabling to manage an execution context for
*               a queueable process and easily generate a log at the end
*               leveraging the sfpegQueueable_UTL utility class.
* @author       P-E GROS
* @date         Feb 2024
* @see          sfpegQueueable_UTL
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

@SuppressWarnings('PMD.ClassNamingConventions')
public with sharing class sfpegQueueableContext_SVC  {

    //################################################################################################
    // STATIC VARIABLES
    //################################################################################################

    /***
    * @description  Max. number of Affectation IDs for detailed logging of failures
    *               It remains public to let Queuable processes override this default value
    *               before executing the logExecution() method.
    ***/
    public static Integer MAX_LOG_IDS = 5;


    //################################################################################################
    // INSTANCE VARIABLES
    //################################################################################################
    
    /***
    * @description  Name of the process for queueable logging purposes
    ***/
    private String processName;

    /***
    * @description  Name of the operation for queueable logging purposes.
    *               It is kept public to let the queueable process update it while processing.
    ***/
    public String operationName;
    
    /***
    * @description  This variable registers the iteration number of a queueable process,
    *               starting at one. Just for information in the queueable logs.
    ***/     
    private Integer iteration = 1;

    /***
    * @description  This variable contains the time spent by the instance waiting in the queue
    *               (i.e. between context creation and provided creationTS).
    ***/     
    private Integer waitTime;

    /***
    * @description  This variable tracks the identification of the records successfully processed
    *               by the queueable instance (usually record IDs).
    ***/     
    private Set<String> recordsOK = new Set<String>();

    /***
    * @description  This variable tracks the identification of the records unsuccessfully processed
    *               by the queueable instance (usually record IDs).
    ***/     
    private Set<String> recordsKO = new Set<String>();
    

    //################################################################################################
    // INITIALIZATION
    //################################################################################################
    
    /***
    * @description  Public constructor used when starting the Queueable process.
    ***/
    public sfpegQueueableContext_SVC(final String processName, final Integer iteration, final DateTime creationTS) {
        sfpegDebug_UTL.debug('START context for',processName);
        
        this.waitTime = sfpegQueueable_UTL.getTimeDelta(creationTS, System.Now());
        sfpegDebug_UTL.fine('WaitTime evaluated',this.waitTime);

        this.processName = processName;
        this.iteration = iteration;
        sfpegDebug_UTL.fine('iteration processed',this.iteration);

        sfpegDebug_UTL.debug('END');
    }


    //################################################################################################
    // PUBLIC METHODS
    //################################################################################################

    /***
	* @description  Public method providing the number of records processed
    *               OK or KO in the context
    ***/
	public Integer size() {
        return this.recordsOK.size() + this.recordsKO.size();
	}

    /***
	* @description  Public method registering a set of items as OK in the Context
    *               and removing them from the KO ones if needed.
    ***/
	public void registerOK(final Set<String> items) {
        this.recordsOK.addAll(items);
        this.recordsKO.removeAll(items);
    }

    /***
	* @description  Public method registering an item as OK in the Context
    *               and removing it from the KO ones if needed.
    ***/
	public void registerOK(final String item) {
        this.recordsOK.add(item);
        this.recordsKO.remove(item);
    }

    /***
	* @description  Public method registering a set of items as KO in the Context
    *               and removing them from the OK ones if needed.
    ***/
	public void registerKO(final Set<String> items) {
        this.recordsOK.removeAll(items);
        this.recordsKO.addAll(items);
    }

    /***
	* @description  Public method registering an item as KO in the Context
    *               and removing it from the OK ones if needed.
    ***/
	public void registerKO(final String item) {
        this.recordsOK.remove(item);
        this.recordsKO.add(item);
    }

    /***
	* @description  Public method registering an item as KO in the Context
    *               and removing from the OK ones if needed.
    ***/
	public void analyseResults(final Database.SaveResult[] dmlResults) {
        sfpegDebug_UTL.fine('START with #results',dmlResults.size());
        for(Database.SaveResult iter : dmlResults) {
            if (iter.isSuccess()) {
                sfpegDebug_UTL.finest('Registering record ID as OK',iter.getId());
                registerOK((String)(iter.getId()));
            }
            else {
                sfpegDebug_UTL.finest('Registering record ID as KO',iter.getId());
                sfpegDebug_UTL.finest('Error details',iter.getErrors());
                registerKO((String)(Iter.getId()));
            }
        }
    }

    /***
	* @description  Public method invoked at the end of a Queueable process execution
    *               to log data about the process with a specific operation name
    ***/
    public void logExecution(final string operationName, final string contextData) {
        sfpegDebug_UTL.fine('START with operation',operationName);
        
        String logMessage = (String.isNotBlank(operationName) ? operationName : (String.isNotBlank(this.operationName) ? this.operationName : this.processName))
                            + ' #' + this.iteration + ': OK for ' +  this.recordsOK.size();
        Integer koNbr = this.recordsKO.size();
        logMessage += ' and KO for ' + koNbr + ' records';

        if (koNbr > 0) {
            sfpegDebug_UTL.finest('Registering Failed record IDs',koNbr);
            sfpegDebug_UTL.finest('Source Failed record IDs',this.recordsKO);
            List<String> idList = new List<String>(this.recordsKO);
            sfpegDebug_UTL.finest('Failed record IDs',idList);
            while (idList.size() > MAX_LOG_IDS) {
                idList.remove(MAX_LOG_IDS);
            }
            sfpegDebug_UTL.finest('Failed record IDs filtered',idList);
            logMessage += '\nFailed for IDs ' + String.join(idList, ',') + (koNbr > MAX_LOG_IDS ? '...' : '');
        }
        sfpegDebug_UTL.finest('logMessage init',logMessage);

        sfpegQueueable_UTL.logExecution(    this.processName,this.recordsOK.size() + this.recordsKO.size(),this.recordsKO.size(),
                                            logMessage,contextData,this.waitTime);
        sfpegDebug_UTL.fine('END');
    }

    /***
	* @description  Public method invoked at the end of a Queueable process execution
    *               to log data about the process.
    ***/
    public void logExecutionEnd(final string contextData) {
        sfpegDebug_UTL.fine('START at iteration',this.iteration);
        sfpegQueueable_UTL.logExecution(    this.processName,0,0,
                                            'END at #' + this.iteration,
                                            contextData,this.waitTime);
        //logExecution(null,contextData);
        sfpegDebug_UTL.fine('END');
    }

    /***
	* @description  Public method invoked at the end of a Queueable process execution
    *               to log an aborted execution of the process.
    ***/
    public void logExecutionAbort(final string message, final string contextData) {
        sfpegDebug_UTL.fine('START',message);
        sfpegQueueable_UTL.logExecution(    this.processName,0,0,
                                            message,contextData,this.waitTime);
        sfpegDebug_UTL.fine('END');
    }

    /***
	* @description  Public method invoked at the end of a Queueable process execution
    *               to log an aborted execution of the process (for compatibility purposes)
    ***/
    public void logExecutionAbort(final string message) {
        logExecutionAbort(message,null);
    }
}