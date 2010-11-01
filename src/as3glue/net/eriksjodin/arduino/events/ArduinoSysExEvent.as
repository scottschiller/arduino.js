/*
 * Copyright 2007 (c) Erik Sjodin, eriksjodin.net
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
package net.eriksjodin.arduino.events
{
	
	import flash.utils.ByteArray;
	import flash.events.Event;
	
	 /**
	 * @author Erik Sjodin, eriksjodin.net
	 */
	public class ArduinoSysExEvent extends Event{
	
		public static const SYSEX_MESSAGE : String = "ARD_SYSEX_MESSAGE";
		
		private var _port:int;
		private var _data:ByteArray;
		
		public function ArduinoSysExEvent(type:String, port:int, data:ByteArray){
			super(type);
			_port = port;
			_data = data;
			// writeDebug('ArduinoSysExEvent(): port: '+port+', data: '+data);
		}
		
		// mandatory override of the inherited clone() method
	    override public function clone():Event{
	    	return new ArduinoSysExEvent(type, port, data);
	    }
		
		public function set data(d:ByteArray):void{
			_data = d;
		}
		
		public function set port(n:int):void{
			_port = n;
		}
		
		public function get data():ByteArray {
			return _data;
		}
		
		public function get port():int {
			return _port;
		}
		
	}
}