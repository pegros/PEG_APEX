/***
* @description  Schedulable class to check and launch queueable processes based on
*               configuration in sfpegQueueableSetting custom setting.
*               It reads the supervisedProcesses field (CSV list of class names) and
*               checks if the current DailyAsyncApexExecutions ratio is lower than
*               the MinRelaunchRatio before launching each process.
* @author       P-E GROS
* @date         April 2025
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

public with sharing class sfpegQueueable_SCH implements Schedulable {
    
    /***
    * @description  Execute method required by the Schedulable interface.
    *               Checks and launches queueable processes based on configuration.
    * @param       context The SchedulableContext object provided by the platform
    ***/
    public void execute(SchedulableContext context) {
        sfpegDebug_UTL.debug('START');
        
        // Get the custom setting
        sfpegQueueableSetting__c settings = sfpegQueueableSetting__c.getInstance();
        if (settings == null) {sfpegDebug_UTL.warn('END KO / No settings found'); return;}
        
        // Check if supervised processes are configured
        if (String.isBlank(settings.SupervisedProcesses__c)) {sfpegDebug_UTL.warn('END KO / No supervised processes configured');return;}
        
        // Check if MinRelanchRatio is configured
        Decimal minRelaunchRatio = settings.MinRelaunchRatio__c;
        if (minRelaunchRatio == null) {sfpegDebug_UTL.warn('END KO / MinRelanchRatio not configured');return;}
        sfpegDebug_UTL.fine('Min relaunch ratio fetched', minRelaunchRatio);
        
        // Get current execution ratio
        System.OrgLimit currentLimit = System.OrgLimits.getMap().get('DailyAsyncApexExecutions');
        Integer currentVal = currentLimit?.getValue();
        Integer maxVal = currentLimit?.getLimit();
        Decimal currentRatio = ((maxVal > 0) ? (currentVal * 100.0 / maxVal) : 0);
        
        sfpegDebug_UTL.fine('Current execution ratio determed', currentRatio);
        
        // Check if current ratio is lower than MinRelaunchRatio
        if (currentRatio >= minRelaunchRatio) {sfpegDebug_UTL.warn('END KO / Current ratio higher than Min Relaunch Ratio',currentRatio);return;}
        
        // Process each class in the CSV list
        List<String> processClasses = settings.SupervisedProcesses__c?.split(',');
        for (String processClass : processClasses) {
            processClass = processClass.trim();
            if (String.isNotBlank(processClass)) {
                sfpegDebug_UTL.fine('Processing class', processClass);
                try {
                    ID jobId = sfpegQueueable_UTL.checkLaunch(processClass);
                    sfpegDebug_UTL.fine('Launched job', jobId);
                }
                catch (Exception e) {
                    sfpegDebug_UTL.error('Error launching process', e);
                }
            }
        }
        
        sfpegDebug_UTL.debug('END');
    }
} 