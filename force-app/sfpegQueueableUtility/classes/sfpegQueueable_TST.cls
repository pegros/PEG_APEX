/***
* @description  Test class for the sfpegQueueable_UTL class
* @author       P-E GROS
* @date         May 2023
* @see sfpegQueueable_UTL
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

@SuppressWarnings('PMD.ClassNamingConventions')
@isTest
public with sharing class sfpegQueueable_TST {

    // Testing Singleton Control 
    @isTest
	public static void checkLaunch() {
        sfpegDebug_UTL.debug('START');
        try {
            sfpegQueueable_UTL.checkLaunch('sfpegQueueable_UTL');
            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid check',e.getMessage());
            Assert.fail('No exception should be raised for valid check');
        }
    }
    
    // Testing utilities 
    @isTest
	public static void getTimeDelta() {
        sfpegDebug_UTL.debug('START');
        try {
            DateTime startTS = System.now();
            DateTime endTS = startTS.addSeconds(2);
            Integer deltaTS = sfpegQueueable_UTL.getTimeDelta(startTS,endTS);
            sfpegDebug_UTL.fine('delta computed',deltaTS);
			Assert.areEqual(2000,deltaTS,'Computed time delta should be 2 seconds, i.e. 2000 ms');
            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid time delta',e.getMessage());
			Assert.fail('No exception should be raised for valid time delta');
        }
    }
    
    // Testing Logging Features 
    @isTest
	public static void getLastContext() {
        sfpegDebug_UTL.debug('START');
        try {
            String context = sfpegQueueable_UTL.getLastContext('sfpegQueueable_UTL');
            sfpegQueueable_UTL.logExecution('sfpegQueueable_UTL', 1);
            context = sfpegQueueable_UTL.getLastContext('sfpegQueueable_UTL');
            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid last context',e.getMessage());
            Assert.fail('No exception should be raised for valid last context');
        }
    }
    
    @isTest
	public static void logPriorExecution() {
        sfpegDebug_UTL.debug('START');
        try {
            sfpegQueueableLog__c log = sfpegQueueable_UTL.getLogData('sfpegQueueable_UTL', 1, 0, 'Test', 'Test', 150);
            sfpegQueueable_UTL.logPriorExecution(log);
            sfpegDebug_UTL.error('Initial log registered');

            String test = 'TEST ';
            for (Integer iter = 0; iter <125000; iter++) test += 'x';
            log = sfpegQueueable_UTL.getLogData('sfpegQueueable_UTL', 1, 0, test, 'Test', 200);
            sfpegQueueable_UTL.logPriorExecution(log);
            sfpegDebug_UTL.error('Revised log registered');

            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid prior log',e.getMessage());
            Assert.fail('No exception should be raised for valid prior log');
        }
    }
    
    @isTest
	public static void logExecution_rcdNbrOnly() {
        sfpegDebug_UTL.debug('START');
        try {
            sfpegQueueable_UTL.logExecution('sfpegQueueable_UTL', 1);
            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid record number',e.getMessage());
            Assert.fail('No exception should be raised for valid record number');
        }
    }
    
    @isTest
	public static void logExecution_rcdNbrFailsMessage() {
        sfpegDebug_UTL.debug('START');
        try {
            sfpegQueueable_UTL.logExecution('sfpegQueueable_UTL', 1, 0, 'test message');
            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid record number and failures',e.getMessage());
            Assert.fail('No exception should be raised for valid record number and failures');
        }
    }
    
    @isTest
	public static void logExecution_rcdNbrWait() {
        sfpegDebug_UTL.debug('START');
        try {
            sfpegQueueable_UTL.logExecution('sfpegQueueable_UTL', 1, 1);
            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid record number and wait time',e.getMessage());
            Assert.fail('No exception should be raised for valid record number and wait time');
        }
    }
    
    @isTest
	public static void logExecution_rcdNbrFailsWait() {
        sfpegDebug_UTL.debug('START');
        try {
            sfpegQueueable_UTL.logExecution('sfpegQueueable_UTL', 1, 0, 1);
            sfpegDebug_UTL.debug('END');
        }
        catch(Exception e) {
            sfpegDebug_UTL.error('Exception raised for valid record number and failures and wait time',e.getMessage());
            Assert.fail('No exception should be raised for valid record number and failures and wait time');
        }
    }
}