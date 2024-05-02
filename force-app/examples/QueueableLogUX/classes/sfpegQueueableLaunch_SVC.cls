/***
* @description  Simple implementation of the generic sfpegAction_SVC class 
*               (see PEG_LIST package) to execute a simple checkLaunch() of an
*               Apex singleton queueable apex class via the sfpegQueueableLaunch_SVC
*               (see PEG_APEX package) utility class.
* @author       P-E GROS
* @date         Jan 2024
* @see          sfpegQueueable_UTL
* @see PEG_APEX package (https://github.com/pegros/PEG_APEX)
* @see          sfpegAction_SVC
* @see PEG_LIST package (https://github.com/pegros/PEG_LIST)
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
public with sharing class sfpegQueueableLaunch_SVC extends sfpegAction_SVC  {

    /***
  * @description  Standard override of the sfpegAction_SVC execute() method
    *               to execute a checkLaunch() via the sfpegQueueableLaunch_SVC
    *               of the Apex singleton Apex class name provided via the 
    *               CLASS input parameter (method parameter is ignored).
    ***/
  public override Object execute(final Object input, final String method) {
    sfpegDebug_UTL.info('execute: START with input ',input);

        Map<Object,Object> inputMap = (Map<Object,Object>) input;
        String queueableName = (String) inputMap?.get('CLASS');
        sfpegDebug_UTL.debug('execute: queueable name extracted ', queueableName);

        if (String.isBlank(queueableName)) {
            sfpegDebug_UTL.error('END KO / Missing CLASS property in config');
            Exception error = new System.NullPointerException();
            error.setMessage('CLASS property is missing in action input!');
            throw error;
        }

        sfpegQueueable_UTL.checkLaunch(queueableName);
    sfpegDebug_UTL.info('execute: END / checklaunch done');
    return true;
  }
}