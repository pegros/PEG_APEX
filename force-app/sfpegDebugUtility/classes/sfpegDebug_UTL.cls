/***
* @description  Utility class to optimise and standardise Apex Debug logs
* @author       P-E GROS
* @date         Jan 2023
* @see PEG_U package (https://github.com/pegros/PEG_APEX)
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

    @testVisible
	private static Decimal MAX_LOG_LEVEL = (sfpegDebugSetting__c.getInstance()?.MaxLevel__c == null ? 0 : sfpegDebugSetting__c.getInstance()?.MaxLevel__c);

    // ERROR level logging (1)
    public static void error(final String message) {
        if (MAX_LOG_LEVEL < 1) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.ERROR,message,null,new StringException());
    }
    public static void error(final String message, final Object details) {
        if (MAX_LOG_LEVEL < 1) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.ERROR,message,details,new StringException());
    }

    // WARN level logging (2)
    public static void warn(final String message) {
        if (MAX_LOG_LEVEL < 2) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.WARN,message,null,new StringException());
    }
    public static void warn(final String message, final Object details) {
        if (MAX_LOG_LEVEL < 2) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.WARN,message,details,new StringException());
    }

    // INFO level logging (3)
    public static void info(final String message) {
        if (MAX_LOG_LEVEL < 3) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.INFO,message,null,new StringException());
    }
    public static void info(final String message, final Object details) {
        if (MAX_LOG_LEVEL < 3) return;
        sfpegDebug_UTL.logMessage(LoggingLevel.INFO,message,details,new StringException());
    }

    // DEBUG level logging (4)
    public static void debug(final String message) {
        if (MAX_LOG_LEVEL < 4) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.DEBUG,message,null,new StringException());
    }
    public static void debug(final String message, final Object details) {
        if (MAX_LOG_LEVEL < 4) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.DEBUG,message,details,new StringException());
    }

    // FINE level logging (5)
    public static void fine(final String message) {
        if (MAX_LOG_LEVEL < 5) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.FINE,message,null,new StringException());
    }
    public static void fine(final String message, final Object details) {
        if (MAX_LOG_LEVEL < 5) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.FINE,message,details,new StringException());
    }

    // FINER level logging (6)
    public static void finer(final String message) {
        if (MAX_LOG_LEVEL < 6) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.FINER,message,null,new StringException());
    }
    public static void finer(final String message, final Object details) {
        if (MAX_LOG_LEVEL < 6) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.FINER,message,details,new StringException());
    }

    // FINEST level logging (7)
    public static void finest(final String message) {
        if (MAX_LOG_LEVEL < 7) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.FINEST,message,null,new StringException());
    }
    public static void finest(final String message, final Object details) {
        if (MAX_LOG_LEVEL < 7) return;
        sfpegDebug_UTL.logMessage( LoggingLevel.FINEST,message,details,new StringException());
    }

    // Private actual logging utility
    private static void logMessage(final LoggingLevel Level, final String message, final Object details, Exception context) {

        String stackTrace = context.getStackTraceString().split('\n',2)[1];
		String methodName = stackTrace.substringBefore(':').substringAfterLast('.');
		if (stackTrace.startsWith('Class.')) {
			stackTrace = stackTrace.substringAfter('Class.');
		}
		String className = stackTrace.substringBefore(':').substringBeforeLast('.');
        
        if (details == null) {
            System.debug(Level, className + '|' + methodName + '|' + message);
        }
        else {
            System.debug(Level, className + '|' + methodName + '|' + message + '|' + details);
        }
    }
}