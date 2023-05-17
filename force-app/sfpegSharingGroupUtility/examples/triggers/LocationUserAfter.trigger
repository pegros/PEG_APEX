/***
* @description	Trigger for the LocationUser__c custom Object triggering all After logics:
*               Sharing Group review
* @author		P-E GROS
* @date			May 2023
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

trigger LocationUserAfter on LocationUser__c (After insert, After update, After delete) {
    sfpegDebug_UTL.info('START with #items',Trigger.size);

    // Trigger Bypass
    if ( (System.isBatch()) || (System.isFuture()) || (System.isQueueable()) ){
        sfpegDebug_UTL.info('END / Logic bypassed'); 
        return;
    }

    // Trigger logic
    if (Trigger.isInsert) {
        sfpegDebug_UTL.debug('Triggering Sharing Group Membership Init Logic');
        LocationUser_DMN.reviewMemberships(Trigger.new);
    }
    else if (Trigger.isUpdate) {
        sfpegDebug_UTL.debug('Triggering Sharing Group Membership Update Logic');
        LocationUser_DMN.reviewMemberships(Trigger.new,Trigger.oldMap);
    }
    else {
        sfpegDebug_UTL.debug('Triggering Sharing Group Membership Removal Logic');
        LocationUser_DMN.reviewMemberships(Trigger.old);
    }

	sfpegDebug_UTL.debug('END');
}