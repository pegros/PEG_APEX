/***
* @description  Simple implementation of the generic sfpegAction_SVC class 
*               (see PEG_LIST package) to stop the execution of all running
*               jobs of an Apex queueable class.
* @author       P-E GROS
* @date         March 2024
* @see          sfpegAction_SVC
* @see PEG_LIST package (https://github.com/pegros/PEG_LIST)
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
public with sharing class sfpegQueueableStop_SVC extends sfpegAction_SVC  {

    /***
  * @description  Standard override of the sfpegAction_SVC execute() method
    *               to execute a checkLaunch() via the sfpegQueueableLaunch_SVC
    *               of the Apex singleton Apex class name provided via the 
    *               CLASS input parameter (method parameter is ignored).
    ***/
    public override Object execute(final Object input, final String method) {
        sfpegDebug_UTL.info('START with input ',input);
        Map<Object,Object> inputMap = (Map<Object,Object>) input;

        String queueableName = (String) inputMap?.get('CLASS');
        sfpegDebug_UTL.debug('queueable name extracted ', queueableName);
        if (String.isBlank(queueableName)) {
            sfpegDebug_UTL.error('END KO / Missing CLASS property in config');
            Exception error = new System.NullPointerException();
            error.setMessage('CLASS property is missing in action input!');
            throw error;
        }

        Integer maxJobs = 100;
        if (inputMap?.containsKey('MAX')) {
            maxJobs = (Integer) inputMap?.get('MAX');
        }
        sfpegDebug_UTL.debug('maxJobs init/extracted ', maxJobs);

        Boolean doContinue = true;
        Integer totalJobs = 0;
        while (doContinue) {
            List<AsyncApexJob> apexJobs = [ SELECT Id, Status, JobType
                                            FROM AsyncApexJob 
                                            WHERE JobType = 'Queueable'
                                            AND Status IN ('Queued','Preparing','Processing')
                                            AND ApexClass.Name = :queueableName
                                            ORDER BY Id asc
                                            LIMIT :maxJobs];
            sfpegDebug_UTL.fine('#apexJobs retrieved',apexJobs.size());

            if (apexJobs.size() == 0) {
                sfpegDebug_UTL.fine('No job to cancel');
                doContinue = false;
            }
            else {
                sfpegDebug_UTL.fine('Cancelling jobs');
                for (AsyncApexJob iter : apexJobs) {
                    sfpegDebug_UTL.fine('Aborting job',iter);
                    try {
                        System.abortJob(iter.id);
                    }
                    catch (Exception e) {
                        sfpegDebug_UTL.warn('Job abortion failed',e);
                    }
                }
                totalJobs += apexJobs.size();
            }
        }

        sfpegDebug_UTL.info('END #Jobs stopped',totalJobs);
        return true;
    }
}