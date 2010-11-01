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
package net.eriksjodin.arduino.events {

	import flash.events.Event;
	
	/**
	* @author Erik Sjodin, eriksjodin.net
	*/
	public class ArduinoEvent extends Event {
	
		// the pin that triggered the event
		private var _pin:int;
		
		// the value of the pin that triggered the event
		private var _value:Number;
		
		// the port number identifies the board that dispatched the event
		private var _port:int;
		
		// event identifiers
		public static const ANALOG_DATA : String = "ARD_ANALOG_DATA";
		public static const DIGITAL_DATA : String = "ARD_DIGITAL_DATA";
		public static const FIRMWARE_VERSION : String = "ARD_FIRMWARE_VERSION";
		
		public function ArduinoEvent(type:String, pin:int, value:Number, port:int){
			super(type);
			_pin = pin;
			_value = value;
			_port = port;
			// writeDebug('ArduinoEvent(): pin '+pin+', value: '+value+', port: '+port);
		}
		
		// mandatory override of the inherited clone() method
	    override public function clone():Event{
	    	return new ArduinoEvent(type, pin , value, port);
	    }
	             
		public function set pin(n:int):void{
			_pin = n;
		}
		
		public function set value(n:Number):void{
			_value = n;
		}
		
		public function set port(n:int):void{
			_port = n;
		}
		
		public function get pin():int {
			return _pin;
		}
		
		public function get value():Number {
			return _value;
		}
		
		public function get port():int {
			return _port;
		}
		
	}

}
