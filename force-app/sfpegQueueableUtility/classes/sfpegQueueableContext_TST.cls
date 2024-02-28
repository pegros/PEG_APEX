/***
* @description  Test class for the sfpegQueueableContext_UTL class
* @author       P-E GROS
* @date         Feb 2024
* @see sfpegQueueableContext_UTL
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
public with sharing class sfpegQueueableContext_TST {

    // Testing Base Accessor Methods
    @isTest
	public static void checkBaseAccessors() {
        sfpegDebug_UTL.debug('START');

        sfpegQueueableContext_SVC testContext = new sfpegQueueableContext_SVC('TestProcess',0,System.now());
        sfpegDebug_UTL.debug('Context init',testContext);

        Assert.areEqual(0,testContext.size(),'Default context size should be 0');

        testContext.registerOK('testOK');
        testContext.registerOK('testKO');
        testContext.registerKO('testKO');

        Assert.areEqual(2,testContext.size(),'Context size should be 2 with 1 OK and 1 KO records registered');
    }
    
    // Testing execution registration 
    @isTest
	public static void checkRegistration() {
        sfpegDebug_UTL.debug('START');

        sfpegQueueableContext_SVC testContext = new sfpegQueueableContext_SVC('TestProcess',0,System.now());
        sfpegDebug_UTL.debug('Context init',testContext);

        List<sfpegQueueableLog__c> rcdList = new List<sfpegQueueableLog__c>();
        rcdList.add(new sfpegQueueableLog__c(Name = 'TEST #1'));
        rcdList.add(new sfpegQueueableLog__c(Name = 'TEST #2'));
        sfpegDebug_UTL.debug('Record List init',rcdList);

        Database.SaveResult[] rcdInserts = database.insert(rcdList, false);
        sfpegDebug_UTL.debug('Records inserted',rcdInserts);

        testContext.analyseResults(rcdInserts);
        sfpegDebug_UTL.debug('Records insered',rcdInserts);
        Assert.areEqual(2,testContext.size(),'Context size should be 2 after 2 inserts');

        testContext.logExecution('TEST Context');
        sfpegDebug_UTL.debug('Execution registered');

        testContext.logExecutionAbort('TEST Abort');
        sfpegDebug_UTL.debug('Abortion registered');

        sfpegDebug_UTL.debug('END');
    }
}