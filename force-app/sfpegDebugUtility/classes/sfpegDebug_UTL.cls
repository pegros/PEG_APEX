/***
* @description  Utility class to optimise and standardise Apex Debug logs
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
public with sharing class sfpegDebug_UTL {

    /***
	* @description  Max logging level allowed for the user, fetched from the applicable 
    *               sfpegDebugSetting__c record (if any available on the Org, O being the default)
    *               Corresponds to the rank of the last logging level allowed (in severity
    *               decreasing order, 0 meaning no log and 7 meaning all logs down to FINEST)
    *               Max level is set to 0 by default, unless when in a test execution context
    *               (in which case it is set to 4).
	***/
    @testVisible
	private static Decimal MAX_LOG_LEVEL = (sfpegDebugSetting__c.getInstance()?.MaxLevel__c == null ? (Test.isRunningTest() ? 4 : 0) : sfpegDebugSetting__c.getInstance().MaxLevel__c);

    /***
    * @description  Log level constants for better readability
    ***/
    @testVisible
    private static final Integer LOG_LEVEL_ERROR = 1;
    @testVisible
    private static final Integer LOG_LEVEL_WARN = 2;
    @testVisible
    private static final Integer LOG_LEVEL_INFO = 3;
    @testVisible
    private static final Integer LOG_LEVEL_DEBUG = 4;
    @testVisible
    private static final Integer LOG_LEVEL_FINE = 5;
    @testVisible
    private static final Integer LOG_LEVEL_FINER = 6;
    @testVisible
    private static final Integer LOG_LEVEL_FINEST = 7;


    //----------------------------------------------------------------------
    // Public logging methods by level
    //----------------------------------------------------------------------

    // ERROR level Logging (max level = 1)
    /***
	* @description  Method to log a message at LoggingLevel.ERROR level
	***/
    public static void error(final String message) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_ERROR) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.ERROR, message, null, new StringException());
    }
    /***
	* @description  Method to log a message at LoggingLevel.ERROR level with a context detail
	***/
    public static void error(final String message, final Object details) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_ERROR) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.ERROR, message, details, new StringException());
    }

    // WARN level logging (max level = 2)
    /***
	* @description  Method to log a message at LoggingLevel.WARN level
	***/
    public static void warn(final String message) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_WARN) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.WARN, message, null, new StringException());
    }
    /***
	* @description  Method to log a message at LoggingLevel.WARN level with a context detail
	***/
    public static void warn(final String message, final Object details) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_WARN) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.WARN, message, details, new StringException());
    }

    // INFO level logging (max level = 3)
    /***
	* @description  Method to log a message at LoggingLevel.INFO level
	***/
    public static void info(final String message) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_INFO) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.INFO, message, null, new StringException());
    }
    /***
	* @description  Method to log a message at LoggingLevel.INFO level with a context detail
	***/
    public static void info(final String message, final Object details) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_INFO) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.INFO, message, details, new StringException());
    }

    // DEBUG level logging (max level = 4)
    /***
	* @description  Method to log a message at LoggingLevel.DEBUG level
	***/
    public static void debug(final String message) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_DEBUG) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.DEBUG, message, null, new StringException());
    }
    /***
	* @description  Method to log a message at LoggingLevel.DEBUG level with a context detail
	***/
    public static void debug(final String message, final Object details) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_DEBUG) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.DEBUG, message, details, new StringException());
    }

    // FINE level logging (max level = 5)
    /***
	* @description  Method to log a message at LoggingLevel.FINE level
	***/
    public static void fine(final String message) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_FINE) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.FINE, message, null, new StringException());
    }
    /***
	* @description  Method to log a message at LoggingLevel.FINE level with a context detail
	***/
    public static void fine(final String message, final Object details) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_FINE) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.FINE, message, details, new StringException());
    }

    // FINER level logging (max level = 6)
    /***
	* @description  Method to log a message at LoggingLevel.FINER level
	***/
    public static void finer(final String message) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_FINER) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.FINER, message, null, new StringException());
    }
    /***
	* @description  Method to log a message at LoggingLevel.FINER level with a context detail
	***/
    public static void finer(final String message, final Object details) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_FINER) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.FINER, message, details, new StringException());
    }

    // FINEST level logging (max level = 7)
    /***
	* @description  Method to log a message at LoggingLevel.FINEST level
	***/
    public static void finest(final String message) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_FINEST) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.FINEST, message, null, new StringException());
    }
    /***
	* @description  Method to log a message at LoggingLevel.FINEST level with a context detail
	***/
    public static void finest(final String message, final Object details) {
        if (MAX_LOG_LEVEL < LOG_LEVEL_FINEST) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.FINEST, message, details, new StringException());
    }

    //----------------------------------------------------------------------
    // Private actual logging utility
    //----------------------------------------------------------------------
    /***
	* @description  Utility method to format the log message with Class and Method names
    *               and issue the actual System.debug() statement.
	***/
    private static void logMessage(final LoggingLevel Level, final String message, final Object details, Exception context) {
        // Extract class and method names from stack trace
        String stackTrace = context.getStackTraceString();
        String[] stackLines = stackTrace.split('\n');
        
        // Default values in case parsing fails
        String className = 'Unknown';
        String methodName = 'Unknown';
        
        // Try to parse the stack trace
        if (stackLines.size() > 1) {
            String callerLine = stackLines[1];
            
            // Extract method name
            if (callerLine.contains(':')) {
                methodName = callerLine.substringBefore(':').substringAfterLast('.');
            }
            
            // Extract class name
            if (callerLine.startsWith('Class.')) {
                callerLine = callerLine.substringAfter('Class.');
            }
            
            if (callerLine.contains('.')) {
                className = callerLine.substringBefore(':').substringBeforeLast('.');
            }
        }
        
        // Format and output the log message
        if (details == null) {
            System.debug(Level, className + '|' + methodName + '|' + message);
        }
        else {
            System.debug(Level, className + '|' + methodName + '|' + message + '|' + details);
        }
    }
}