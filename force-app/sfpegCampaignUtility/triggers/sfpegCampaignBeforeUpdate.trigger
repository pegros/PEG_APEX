/***
* @description  Before Update trigger on the Campaign object
*               to propagate counts and budgets in the campaign hierarchy
*               based on the Campaign record type. 
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

trigger sfpegCampaignBeforeUpdate on Campaign (before insert, before update) { //NOPMD Naming convention
    sfpegDebug_UTL.info('START with #items',Trigger.size);
    
    if (system.isBatch() || system.isFuture() || System.isQueueable()) {sfpegDebug_UTL.info('END (bypassed trigger mode)');return;}
    if (sfpegCampaign_UTL.SETTING?.BypassTriggerCampaign__c) {sfpegDebug_UTL.warn('END (global trigger bypass)');return;}
    if (sfpegCampaign_UTL.SETTING?.BypassLogicHierarchyPropag__c) {sfpegDebug_UTL.warn('END (campaign hierarchy propagation bypass)');return;}
        
    sfpegCampaign_UTL.doHierarchyPropagation(Trigger.new);

    sfpegDebug_UTL.info('END');
}