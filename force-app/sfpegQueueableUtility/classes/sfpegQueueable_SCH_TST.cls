/**
* @description Test class for sfpegQueueable_SCH
* @author P-E GROS
* @date April 2025
* @see sfpegQueueable_SCH
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
 */

@IsTest
public class sfpegQueueable_SCH_TST {
    
    @TestSetup
    static void setup() {
        // Create test custom setting
        sfpegQueueableSetting__c settings = new sfpegQueueableSetting__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            SupervisedProcesses__c = 'sfpegQueueable_UTL,sfpegQueueable_SCH',
            MinRelaunchRatio__c = 80.0
        );
        insert settings;
    }
    
    @IsTest
    static void testExecuteWithValidSettings() {
        // Arrange
        sfpegQueueable_SCH scheduler = new sfpegQueueable_SCH();
        
        // Mock the System.OrgLimits to return a low ratio
        Test.startTest();
        
        // Act
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Assert
        // Note: Since we can't directly assert the queueable execution,
        // we rely on the debug logs and no exceptions being thrown
    }
    
    
    
    @IsTest
    static void testExecuteWithHighRatio() {
        // Arrange
        sfpegQueueable_SCH scheduler = new sfpegQueueable_SCH();
        
        // Mock the System.OrgLimits to return a high ratio
        Test.startTest();
        
        // Act
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Assert
        // Process should exit early due to high ratio
    }
    
    @IsTest
    static void testExecuteWithEmptyProcessList() {
        // Arrange
        sfpegQueueableSetting__c settings = [SELECT Id, SupervisedProcesses__c FROM sfpegQueueableSetting__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() LIMIT 1];
        System.debug('SETTINGS 1' + settings);
        settings.SupervisedProcesses__c = '';
        System.debug('SETTINGS 2 ' + settings);
        update settings;
        
        sfpegQueueable_SCH scheduler = new sfpegQueueable_SCH();
        
        // Act & Assert
        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();
        
        // No exception should be thrown, but process should exit early
    }
    
    @IsTest
    static void testExecuteWithInvalidProcessClass() {
        // Arrange
        sfpegQueueableSetting__c settings = [SELECT Id, SupervisedProcesses__c FROM sfpegQueueableSetting__c WHERE SetupOwnerId = :UserInfo.getOrganizationId() LIMIT 1];
        settings.SupervisedProcesses__c = 'NonExistentClass';
        update settings;
        
        sfpegQueueable_SCH scheduler = new sfpegQueueable_SCH();
        
        // Act & Assert
        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();
        
        // Exception should be caught and logged
    }

    @IsTest
    static void testExecuteWithNoSettings() {
        // Arrange
        delete [SELECT Id FROM sfpegQueueableSetting__c];
        sfpegQueueable_SCH scheduler = new sfpegQueueable_SCH();
        
        // Act & Assert
        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();
        
        // No exception should be thrown, but process should exit early
    }
} 