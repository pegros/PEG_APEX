/***
* @description  Test class for sfpegDebug_UTL
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
@isTest
public with sharing class sfpegDebug_UTL_TST {

    @isTest
	public static void testLogs() {

        system.debug('debug max Level ' + sfpegDebug_UTL.MAX_LOG_LEVEL);
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.error('error','with details');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn',new StringException('with details'));
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.info('info',new Account(Name = 'newAccount'));
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug',new List<String>{'debug #1','debug #2'});
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine','with details');
        sfpegDebug_UTL.finer('debug finer');
        sfpegDebug_UTL.finer('debug finer','with details');
        sfpegDebug_UTL.finest('debug finest');
        sfpegDebug_UTL.finest('debug finest','with details');

        system.debug('==============================');
        sfpegDebug_UTL.MAX_LOG_LEVEL = 3;
        system.debug('debug max Level updated ' + sfpegDebug_UTL.MAX_LOG_LEVEL);
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.error('error','with details');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn',new StringException('with details'));
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.info('info',new Account(Name = 'newAccount'));
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug',new List<String>{'debug #1','debug #2'});
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine','with details');
        sfpegDebug_UTL.finer('debug finer');
        sfpegDebug_UTL.finer('debug finer','with details');
        sfpegDebug_UTL.finest('debug finest');
        sfpegDebug_UTL.finest('debug finest','with details');

        system.debug('==============================');
        sfpegDebug_UTL.MAX_LOG_LEVEL = 5;
        system.debug('debug max Level updated ' + sfpegDebug_UTL.MAX_LOG_LEVEL);
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.error('error','with details');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn',new StringException('with details'));
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.info('info',new Account(Name = 'newAccount'));
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug',new List<String>{'debug #1','debug #2'});
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine','with details');
        sfpegDebug_UTL.finer('debug finer');
        sfpegDebug_UTL.finer('debug finer','with details');
        sfpegDebug_UTL.finest('debug finest');
        sfpegDebug_UTL.finest('debug finest','with details');

        system.debug('==============================');
        sfpegDebug_UTL.MAX_LOG_LEVEL = 8;
        system.debug('debug max Level updated ' + sfpegDebug_UTL.MAX_LOG_LEVEL);
        sfpegDebug_UTL.error('error');
        sfpegDebug_UTL.error('error','with details');
        sfpegDebug_UTL.warn('warn');
        sfpegDebug_UTL.warn('warn',new StringException('with details'));
        sfpegDebug_UTL.info('info');
        sfpegDebug_UTL.info('info',new Account(Name = 'newAccount'));
        sfpegDebug_UTL.debug('debug');
        sfpegDebug_UTL.debug('debug',new List<String>{'debug #1','debug #2'});
        sfpegDebug_UTL.fine('debug fine');
        sfpegDebug_UTL.fine('debug fine','with details');
        sfpegDebug_UTL.finer('debug finer');
        sfpegDebug_UTL.finer('debug finer','with details');
        sfpegDebug_UTL.finest('debug finest');
        sfpegDebug_UTL.finest('debug finest','with details');
    }
}