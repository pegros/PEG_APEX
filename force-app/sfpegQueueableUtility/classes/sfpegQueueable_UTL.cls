/***
* @description  Generic service class for asynchronous operations, providing
*				various methods to launch, monitor... Queueable Apex processes.
*               It provides a way to manage singleton queueable process handling
*               (i.e. control that max.1 queueable process of a class run at any time)
*               and features to easily log and aggregate queueable execution statistics.
* @author       P-E GROS
* @date         May 2023
* @see PEG_APEX package (https://github.com/pegros/PEG_APEX)
*
* Legal Notice
*
* MIT License
*
* Copyright (c) 2023 pegros
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

public with sharing class sfpegQueueable_UTL {

	/***
	* @description  Configuration constant setting the number of minutes
	*               for the aggregation of each Log record.
	***/
	@testVisible
	private static Integer LOG_WINDOW = (sfpegQueueableSetting__c.getInstance()?.LogWindow__c == null ? 10 : Integer.valueOf(sfpegQueueableSetting__c.getInstance()?.LogWindow__c));

	/***
	* @description  Configuration constant setting the number of times
	*               the upsert of a log record is retried.
	***/
	@testVisible
	private static Integer MAX_RETRIES = (sfpegQueueableSetting__c.getInstance()?.MaxRetries__c == null ? 10 :  Integer.valueOf(sfpegQueueableSetting__c.getInstance()?.MaxRetries__c));


    //############################################
    //######### QUEUE EXECUTION CONTROL ##########
    //############################################
    
    /***
    * @description	Static method to check if a Queuable process is currently
    *				running and launch it if not already running/queued.
    * @param		qClassName	Name of the Queuable Apex class to check/launch
    * @return		ID of the currently queued job (possibly just created)
    * @exception	None special.
    ***/ 
    public static ID checkLaunch(final String qClassName) {
        sfpegDebug_UTL.debug('START for class',qClassName);
        
       	List<AsyncApexJob> apexJobs =
            [	SELECT Id, Status, JobType FROM AsyncApexJob 
				WHERE JobType = 'Queueable'
					AND Status IN ('Queued','Preparing','Processing')
					AND ApexClass.Name = :qClassName
				LIMIT 1];
        sfpegDebug_UTL.fine('apexJobs retrieved',apexJobs);
        
        ID jobId;
        if (apexJobs.size() == 0) {
            sfpegDebug_UTL.debug('launching new queueable');
            Type qClass = Type.forName(qClassName);   
            sfpegDebug_UTL.finest('of type',qClass);
            if (qClass == null) {
                sfpegDebug_UTL.error('Queueable class not found!',qClassName);
                Exception error = new System.NullPointerException();
                error.setMessage(qClassName + ' Queueable class not found!');
                throw error;
            }
            else if(!Test.isRunningTest()){
           		jobId = System.enqueueJob((Queueable)(qClass.newInstance()));
            }
        }
        else {
            jobId = apexJobs[0].Id;
        }
        
		sfpegDebug_UTL.debug('END with jobID',jobId);
        return jobId;
    }

    
    //############################################
    //########## QUEUE LOG REGISTRATION ##########
    //############################################

    /***
    * @description	Static method to register the results of a Queuable process
    *				execution, in terms of record processed and failures.
    *				This method should be called last within the Queueable
    *				execute method to properly evaluate CPU and callout measurements.
    *				QueueableLog record is locked by this method until transaction end.
    * @param		qClassName	Name of the Queuable Apex class executed
    * @param		rcdNbr		Number of records processed in the Queueable execution (OK + failed)
    * @param		failedRcdNbr	Number of records with failure in the Queueable execution
    * @param		message		Message to be appended (error logs, iteration stops...)
    * @param		context		Context data to be stored for reuse by next executions (typically when
    *							queuable process is relaunched after interruption).
    * @param		waitTime	WaitTime measured by current execution (in milliseconds),
    *							typically computed via the getTimeDelta() method.
    * @exception	DmlException raised if the log cannot be upserted after a MAX_RETRIES
    *							number of retries.
    ***/ 
    public static void logExecution(final String qClassName, final Integer rcdNbr, final Integer failedRcdNbr, final String message, final String context, final Integer waitTime) {
        sfpegDebug_UTL.fine('START for class',qClassName);
        
        sfpegQueueableLog__c currentLog = getLogData(qClassName, rcdNbr, failedRcdNbr, message, context, waitTime);
        sfpegDebug_UTL.finest('currentLog init');
        
        registerLogData(currentLog,0);
        sfpegDebug_UTL.fine('END');
    }

    /***
    * @description	logExecution method override with only rcdNbr registration.
    ***/
	public static void logExecution(final String qClassName, final Integer rcdNbr) {
        logExecution(qClassName,rcdNbr,0,'','',0);
    }
    
    /***
    * @description	logExecution method override with only rcdNbr, failedRcdNbr and message registration.
    ***/
 	public static void logExecution(final String qClassName, final Integer rcdNbr, final Integer failedRcdNbr, final String message) {
        logExecution(qClassName,rcdNbr,failedRcdNbr,message,'',0);
    }

    /***
    * @description	logExecution method override with only rcdNbr and waitTime registration.
    ***/
    public static void logExecution(final String qClassName, final Integer rcdNbr, final Integer waitTime) {
        logExecution(qClassName,rcdNbr,0,'','',waitTime);
    }

    /***
    * @description	logExecution method override with only rcdNbr, failedRcdNbr and waitTime registration.
    ***/
    public static void logExecution(final String qClassName, final Integer rcdNbr, final Integer failedRcdNbr, final Integer waitTime) {
        logExecution(qClassName,rcdNbr,failedRcdNbr,'','',waitTime);
    }
 
    /***
    * @description	Alternate version to the standard logExecution method to simply
    *				register a prior log initialized via the getLogData() method.
    *				Its main purpose is to generate the log of a Queueable execution
    *				(via the getLogData() method) but actually register it in a later 
    *				chained Queeuable execution (typically to handle 'MixedDML' constraints).
    * @param		log		sfpegQueueableLog__c record fully initialized (e.g. via the getLogData() method)
    * @exception	DmlException raised if the log cannot be upserted after a MAX_RETRIES
    *						number of retries.
    ***/
    public static void logPriorExecution(final sfpegQueueableLog__c log) {
        sfpegDebug_UTL.fine('START for log',log?.Name);
        registerLogData(log,0);
        sfpegDebug_UTL.fine('END');
    }

    
    //#############################################
    //############## UTILITY METHODS ##############
    //#############################################

    /***
    * @description	Static method to fetch the last Context stored on the most recent
    *				QueueableLog for a given Queuable process.
    * @param		qClassName	Name of the Queuable Apex class
    * @return		String Value of the most recent of the currently queued job (possibly just created)
    * @exception	None special.
    ***/ 
    public static String getLastContext(final String qClassName) {
        sfpegDebug_UTL.fine('START for class',qClassName);

        List<sfpegQueueableLog__c> lastLog = [select LastContext__c
                                         from sfpegQueueableLog__c
                                         where ProcessName__c = :qClassName
                                         order by CreatedDate desc limit 1];
        sfpegDebug_UTL.finest('lastLog fetched',lastLog);
        
        String contextValue = '';
        if ((lastLog != null) && (lastLog.size() > 0)) {
            contextValue = (lastLog[0]).LastContext__c;
            if (contextValue == null) contextValue = '';
        }

        sfpegDebug_UTL.fine('END with context',contextValue);		
        return contextValue;
	}

    /***
    * @description	Static utility method to compute the time difference (in milliseconds)
    *				between two timestamps. 
    *				Usually used to compute the waitTime of a queuable process, i.e. the difference
    *				between class instanciation and execute() method start timestamps.
    * @param		startTS	First start timestamp
    * @param		endTS	Last end timestamp
    * @return		Time difference in milliseconds
    * @exception	None special
    ***/
    public static Integer getTimeDelta(final DateTime startTS, final DateTime endTS){
        return (Integer) (endTS.getTime() - startTS.getTime());
    }

    /***
    * @description	Method to upsert the current Log record of a Queueable process with
    *				data from one of its execution.
    *				It looks for the sfpegQueueableLog__c with same name in the database and
    *				if not found tries to insert it, otherwise updates it (by merging
    *				the existing record with the new, via the mergeLogData() method).
    *				sfpegQueueableLog__c are fetched in FOR UPDATE mode to ensure only one
    *				Queueable (of the same process) updates the current log record at a time.
    *				In case of failure, it retries the operation a MAX_RETRY_NBR number
    *				of times (e.g. to cope with parallel inserts on new records for
    *				Queueable processes of same class executing in parallel).
    * @param		qClassName	Name of the Queuable Apex class
    * @param		iteration	Retry iteration number (should be set at 0 by default)
    * @return		String Value of the most recent of the currently queued job (possibly just created)
    * @exception	None special.
    ***/ 
    private static void registerLogData(final sfpegQueueableLog__c newLog, final Integer iteration) {
        sfpegDebug_UTL.finest('START for log',newLog?.Name);		
        sfpegDebug_UTL.finest('Processing iteration',iteration);		
        
        try {
        	List<sfpegQueueableLog__c>  currentLogs =
            	[	SELECT	Name, ExternalID__c, Period__c, ProcessName__c,
             				CPUTime__c, WaitTime__c, CalloutNbr__c,
							JobEmptyNbr__c, JobFailNbr__c, JobNbr__c, 
							RcdFailNbr__c, RcdNbr__c,
             				Message__c, LastContext__c
					FROM sfpegQueueableLog__c  WHERE Name = :newLog.Name	LIMIT 1 FOR UPDATE];
            sfpegDebug_UTL.finest('Current Log retrieved',currentLogs);		

            if (currentLogs.size() == 0) {
                sfpegDebug_UTL.finest('Inserting new Log');		
                insert newLog;
            }
            else {
                sfpegDebug_UTL.finest('Merging existing Log');
                mergeLogData(currentLogs[0],newLog);
                sfpegDebug_UTL.finest('Updating existing Log');
                update currentLogs[0];
            }
            sfpegDebug_UTL.finest('END / Log Upserted');
        }
        catch (Exception e) {
            if (iteration < MAX_RETRIES) {
                sfpegDebug_UTL.warn('END KO / retrying',e.getMessage());
				registerLogData(newLog, iteration + 1);
            } 
			else {
                sfpegDebug_UTL.error('END KO / Persisting failure',e.getMessage());
                throw new DmlException(e.getMessage());
			}
        }
	}
    
    /***
    * @description	Utility method to merge a sfpegQueueableLog__c record data with
    *				the results of a Queuable process execution.
    *				It increment/updates the following fields on the current record
    *				with values from the new record: CPUTime, WaitTime, CalloutNbr,
    *				JobNbr, JobEmptyNbr, JobFailNbr, Message, LastContext.
    *				Message may be truncated if resulting value is too long.
    * @param		currentlog	Current log record to be updated (updated by the method)
    * @param		newlog		New log record with data corresponding to the new execution
    *							(usually coming from the getLogData() method)
    * @exception	None special
    ***/    
    private static void mergeLogData(sfpegQueueableLog__c currentlog, final sfpegQueueableLog__c newlog) {
        sfpegDebug_UTL.finest('START with log', newlog?.Name);
        
        currentlog.CPUTime__c 		+= newlog.CPUTime__c;
		currentlog.CalloutNbr__c	+= newlog.CalloutNbr__c;           
        currentlog.JobEmptyNbr__c	+= newlog.JobEmptyNbr__c;
        currentlog.JobFailNbr__c	+= newlog.JobFailNbr__c;
        currentlog.JobNbr__c		+= newlog.JobNbr__c;        
        currentlog.RcdNbr__c		+= newlog.RcdNbr__c;
		currentlog.RcdFailNbr__c	+= newlog.RcdFailNbr__c;
        if (!String.isEmpty(newlog.Message__c)) {
        	currentlog.Message__c	= (String.isEmpty(currentlog.Message__c) ? '' : currentlog.Message__c + '<br/>')
									+ newlog.Message__c;
			if (currentlog.Message__c.length() > 125000)
                currentlog.Message__c = currentlog.Message__c.left(125000);
        }
        if (!String.isEmpty(newlog.LastContext__c)) currentlog.LastContext__c = newlog.LastContext__c;
        currentlog.WaitTime__c		+= newlog.WaitTime__c;
        
        sfpegDebug_UTL.finest('END');
    }
    
    /***
    * @description	Utility method to init a sfpegQueueableLog__c record data with
    *				the results of a Queuable process execution.
    *				It sets the following fields: CPUTime, WaitTime, CalloutNbr,
    *				JobNbr, JobEmptyNbr, JobFailNbr, Message, LastContext.
    *				Message may be truncated if resulting value is too long.
    *				This method is usually called by the standard logExecution()
    *				method but can be also called directly by the Queueable 
    *				execute method to get log data to be actually registered
    *				at a later execution via the logPriorExecution() method
    *				(typically because of 'MixedDML' issues).
    * @param		qClassName	Name of the Queuable Apex class executed.
    * @param		rcdNbr		Number of records processed in the Queueable execution (OK + failed)
    * @param		failedRcdNbr	Number of records with failure in the Queueable execution
    * @param		message		Message to be appended (error logs, iteration stops...)
    * @param		context		Context at the end of the Queueable execution (context not updated
    *							if empty).
    * @param		waitTime	Wait Time (in milliseconds) of the Queueable execution.
    * @exception	None special
    ***/    
    public static sfpegQueueableLog__c getLogData(final String qClassName, final Integer rcdNbr, final Integer failedRcdNbr, final String message, final String context, final Integer waitTime) {
        sfpegDebug_UTL.finest('START for class',qClassName);
        
        // LogName init
        DateTime currentTS = System.now();
        sfpegDebug_UTL.finest('Current time fetched',currentTS);
        Integer minuteSlot = ((Integer)((currentTS.minute() / LOG_WINDOW))) * LOG_WINDOW;
        sfpegDebug_UTL.finest('minuteSlot generated',minuteSlot);
        DateTime logTS = DateTime.newInstance(currentTS.year(),currentTS.month(),currentTS.day(),
                                              currentTS.hour(),minuteSlot, 0);
        sfpegDebug_UTL.finest('logTS init',logTS);
        String logName = qClassName + '-' + logTS.format('yyyy-MM-dd-HH-mm');
        sfpegDebug_UTL.finest('logName init',logName);
        
        // LogName init        
        sfpegQueueableLog__c newLog = new sfpegQueueableLog__c(
                Name = logName,
                ExternalID__c = logName,
                Period__c = logTS,
                ProcessName__c = qClassName);
        sfpegDebug_UTL.finest('newLog init',newLog);
            
        newLog.CPUTime__c 		= Limits.getCpuTime();
		newLog.CalloutNbr__c	= Limits.getCallouts();  
		newLog.WaitTime__c 		= waitTime;

        newLog.JobEmptyNbr__c	= (rcdNbr == 0 ? 1 : 0);
        newLog.JobFailNbr__c	= (failedRcdNbr > 0 ? 1 : 0);
        newLog.JobNbr__c		= 1;        
        
        newLog.RcdNbr__c		= rcdNbr;
		newLog.RcdFailNbr__c	= failedRcdNbr;
        sfpegDebug_UTL.finest('newLog stats update',newLog);
        
        if (!String.isEmpty(message)) {
        	newLog.Message__c = currentTS.format('HH:mm') + ' - ' + message;
			if (newLog.Message__c.length() > 125000)
                newLog.Message__c = newLog.Message__c.left(125000);
        }
        sfpegDebug_UTL.finest('newLog msg updated',newLog);        
        if (!String.isEmpty(context)) newLog.LastContext__c = context;

        sfpegDebug_UTL.finest('END with log',newLog);
        return newLog;
    }

}