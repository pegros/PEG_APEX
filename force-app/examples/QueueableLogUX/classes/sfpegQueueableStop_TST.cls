/***
* @description  Test class for the sfpegQueueableStop_SVC class
* @author       P-E GROS
* @date         March 2024
* @see sfpegQueueableStop_SVC
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
@isTest
public with sharing class sfpegQueueableStop_TST {

    // Testing execution 
    @isTest
    public static void checkExecute() {
        sfpegDebug_UTL.debug('START');

        sfpegQueueableStop_SVC svc = new sfpegQueueableStop_SVC();
        sfpegDebug_UTL.debug('Service init',svc);

        // Case #1 KO - Missing input
        try {
            svc.execute(null,null);
            Assert.fail('sfpegQueueableStop_SVC execution should fail when input is missing');
        }
        catch (Exception e) {
            sfpegDebug_UTL.debug('Exception properly raised',e);
        }

        // Case #2 OK - Proper checklaunch
        Map<Object,Object> inputMap = new Map<Object,Object>();
        inputMap.put('CLASS','sfpegQueueable_UTL');
        sfpegDebug_UTL.debug('Input prepared',inputMap);
        try {
            svc.execute(inputMap,'TEST');
            sfpegDebug_UTL.debug('Stop properly executed');
        }
        catch (Exception e) {
            Assert.fail('sfpegQueueableStop_SVC execution should not fail when input is OK');
        }

        // Case #3 OK - Proper checklaunch with Max overridden
        inputMap.put('MAX',1);
        sfpegDebug_UTL.debug('Input reviewed',inputMap);
        try {
            svc.execute(inputMap,'TEST');
            sfpegDebug_UTL.debug('Stop properly executed with Max override');
        }
        catch (Exception e) {
            Assert.fail('sfpegQueueableStop_SVC execution with Max override should not fail when input is OK');
        }

        sfpegDebug_UTL.debug('END');
    }
}