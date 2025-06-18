/***
* @description  Test class for sfpegDebug_UTL
* @author       P-E GROS
* @date         Jan 2023
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
public with sharing class sfpegDebug_UTL_TST {

    /***
    * @description  Test all logging methods with different log levels
    ***/
    @isTest
    public static void testAllLogLevels() {
        // Test with default log level (should be 4 in test context)
        System.assertEquals(4, sfpegDebug_UTL.MAX_LOG_LEVEL, 'Default log level in test context should be 4');
        
        // Test all log methods
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.error('error', 'with details');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn', new StringException('with details'));
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.info('info', new Account(Name = 'newAccount'));
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug', new List<String>{'debug #1','LAST'});
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine', 'with details');
        sfpegDebug_UTL.finer('debug finer');
        sfpegDebug_UTL.finer('debug finer', 'with details');
        sfpegDebug_UTL.finest('debug finest');
        sfpegDebug_UTL.finest('debug finest', 'with details');
    }
    
    /***
    * @description  Test log level filtering
    ***/
    @isTest
    public static void testLogLevelFiltering() {
        // Test with log level 3 (INFO)
        sfpegDebug_UTL.MAX_LOG_LEVEL = 3;
        System.assertEquals(3, sfpegDebug_UTL.MAX_LOG_LEVEL, 'Log level should be set to 3');
        
        // Test all log methods - only ERROR, WARN, and INFO should be logged
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.info('info','LAST');
        sfpegDebug_UTL.debug('debug'); // Should not be logged
        sfpegDebug_UTL.fine('debug fine'); // Should not be logged
        sfpegDebug_UTL.finer('debug finer'); // Should not be logged
        sfpegDebug_UTL.finest('debug finest'); // Should not be logged
    }
    
    /***
    * @description  Test log level filtering with higher level
    ***/
    @isTest
    public static void testLogLevelFilteringHigh() {
        // Test with log level 5 (FINE)
        sfpegDebug_UTL.MAX_LOG_LEVEL = 5;
        System.assertEquals(5, sfpegDebug_UTL.MAX_LOG_LEVEL, 'Log level should be set to 5');
        
        // Test all log methods - all levels up to FINE should be logged
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn','with details');
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug','with details');
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine','LAST');
        sfpegDebug_UTL.finer('debug finer'); // Should not be logged
        sfpegDebug_UTL.finest('debug finest'); // Should not be logged
    }
    
    /***
    * @description  Test log level filtering with highest level
    ***/
    @isTest
    public static void testLogLevelFilteringHighest() {
        // Test with log level 8 (all levels)
        sfpegDebug_UTL.MAX_LOG_LEVEL = 8;
        System.assertEquals(8, sfpegDebug_UTL.MAX_LOG_LEVEL, 'Log level should be set to 8');
        
        // Test all log methods - all levels should be logged
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn','with details');
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug','with details');
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine','with details');
        sfpegDebug_UTL.finer('debug finer');
        sfpegDebug_UTL.finest('debug finest');
        sfpegDebug_UTL.finest('debug finest','LAST');
    }
    
    /***
    * @description  Test log level filtering with no logging
    ***/
    @isTest
    public static void testLogLevelFilteringNone() {
        // Test with log level 0 (no logging)
        sfpegDebug_UTL.MAX_LOG_LEVEL = 0;
        System.assertEquals(0, sfpegDebug_UTL.MAX_LOG_LEVEL, 'Log level should be set to 0');
        
        // Test all log methods - none should be logged
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn','with details');
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug','with details');
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine','with details');
        sfpegDebug_UTL.finer('debug finer');
        sfpegDebug_UTL.finest('debug finest');
    }
}