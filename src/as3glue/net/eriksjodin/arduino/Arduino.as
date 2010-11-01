/*
 * arduino.js: Flash <-> Socket/serial proxy component: Implementation using AS3Glue
 * http://github.com/scottschiller/arduino-js/
 * Copyright 2010 (c) Scott Schiller, http://schillmania.com/
 * Released under an MIT license.
 * version: 2010.10.29
 *
 * Based on "Flash - Arduino Example Script" (Copyleft)
 *
 * --- Flash - Arduino Example Script-------------------------------------------------
 * 
 * Flash - Arduino Example script
 * Version 1.5: 13-09-2010
 * Copyleft: Kasper Kamperman - Art & Technology - Saxion
 *
 * More info on how to setup Arduino/Flash communication:
 * http://www.kasperkamperman.com/blog/arduino/arduino-flash-communication-as3/
 *
 *
 * --- AS3Glue license ---------------------------------------------------------------
 *
 * Copyright 2007-2008 (c) Erik Sjodin, eriksjodin.net and Bjoern Hartmann, bjoern.org
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
package net.eriksjodin.arduino {
	
	import flash.net.Socket;
	import flash.events.ProgressEvent;
	import net.eriksjodin.arduino.events.ArduinoEvent;
	import net.eriksjodin.arduino.events.ArduinoSysExEvent;
	import flash.utils.ByteArray;
	import net.eriksjodin.helpers.Log;
	
	 /**
	 * The Arduino class acts as a proxy for Arduino boards that communicate 
	 * over a serial proxy, Ethernet shield or Serial-to-Ethernet hardware gateway 
	 * using the FirmataV2 protocol and the StandardFirmata firmware.
	 * This version ONLY WORKS WITH FIRMATA VERSION 2.
	 * @author Erik Sjodin, eriksjodin.net
	 * @author Bjoern Hartmann, bjoern.org
	 *
	 * TODO: using analog pins as digital I/O (PORTC or PORT#=2) is not yet supported.
	 */
	public class Arduino extends Socket {
		
		// enumerations
		public static const OUTPUT : int = 1;
		public static const INPUT	: int = 0;
		public static const HIGH : int = 1;
		public static const LOW : int = 0;
		public static const ON : int = 1;
		public static const OFF : int = 0;
		public static const PWM : int = 3;
		 	
		private var _host			: String  = "127.0.0.1"; 	
		private var _port			: uint  = 5331;		 
		
		// data processing variables
		private var _waitForData 				: int = 0;
		private var _executeMultiByteCommand 	: int = 0;	
		private var _multiByteChannel			: int = 0; 		// indicates which pin the data came from
		
		// data holders
		private var _storedInputData		: Array = new Array();
		private var _analogData				: Array = new Array();
		private var _previousAnalogData		: Array = new Array();
		private var _digitalData			: Array = [0,0,0,0,0,0,0,0,0,0,0,0,0,0];
		private var _previousDigitalData	: Array = [0,0,0,0,0,0,0,0,0,0,0,0,0,0];
		private var _firmwareVersion		: int = 0;
		private var _digitalPins			: int = 0;
		private var _sysExData				: ByteArray = new ByteArray();
		
		// private enums
		private static const ARD_TOTAL_DIGITAL_PINS			: uint = 14; 
		
		// computer <-> arduino messages
		private static const ARD_DIGITAL_MESSAGE			: int = 144; 
		private static const ARD_REPORT_DIGITAL_PORTS		: int = 208; 
		private static const ARD_REPORT_ANALOG_PIN			: int = 192; 
		private static const ARD_REPORT_VERSION				: int = 249; 
		private static const ARD_SET_DIGITAL_PIN_MODE		: int = 244; 	
		private static const ARD_ANALOG_MESSAGE				: int = 224; 
		private static const ARD_SYSTEM_RESET				: int = 255; 
		protected static const ARD_SYSEX_MESSAGE_START		: int = 240; //expose to let subclasses send sysex
		protected static const ARD_SYSEX_MESSAGE_END			: int = 247;
		
		private static const ARD_SYSEX_STRING				: int = 113; //0x71;
		private static const ARD_SYSEX_QUERY_FIRMWARE		: int = 121; //0x79;
		
		public function Arduino(host:String = "127.0.0.1", port:int = 5331) {
			super();			
	
			if ((_port < 1024) || (_port > 65535)) {
				trace("Arduino: Port must be from 1024 to 65535!")		
			} else {
				_port = port;
			}
			_host = host;
			// auto connect
			super.connect(_host,_port);
			
			// listen for socket data
			addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler, false, 0, true);			
		}
		
		//---------------------------------------
		//	PUBLIC FUNCTIONS
		//---------------------------------------
				
		// GETTERS
		
		public function getFirmwareVersion (): int{
			return _firmwareVersion;
		}
		
		public function getAnalogData (pin:int): int{
			return _analogData[pin];
		}
		
		public function getDigitalData (pin:int): int{
			return _digitalData[pin];
		}
		
		public function setAnalogPinReporting (pin:int, mode:int):void{
			writeByte(ARD_REPORT_ANALOG_PIN+pin);
			writeByte(mode);
			flush();
		}
	
		public function enableDigitalPinReporting ():void{
			writeByte(ARD_REPORT_DIGITAL_PORTS+0); //port0
			writeByte(1);
			flush();
			//FIRMATA2.0 change: have to enable ports 0 and 1 separately
			writeByte(ARD_REPORT_DIGITAL_PORTS+1); //port1
			writeByte(1);
			flush();
		}
		
		public function disableDigitalPinReporting ():void{
			writeByte(ARD_REPORT_DIGITAL_PORTS);
			writeByte(0);
			flush();
			//FIRMATA2.0 change: have to enable ports 0 and 1 separately
			writeByte(ARD_REPORT_DIGITAL_PORTS+1); //port1
			writeByte(0);
			flush();
		}
		
		public function setPinMode (pin:Number, mode:Number):void{
			writeByte(ARD_SET_DIGITAL_PIN_MODE);
			writeByte(pin);
			writeByte(mode);
			flush();
		}
		
		//FIRMATA2.0 change: have to send a PORT-specific message
		public function writeDigitalPin (pin:int, mode:int):void{
		
			// set the bit
            if(mode==1)
            	_digitalPins |= (mode << pin);
                                
            // clear the bit        
			if(mode==0)
				_digitalPins &= ~(1 << pin);
        
				if(pin<=7){
					writeByte(ARD_DIGITAL_MESSAGE+0);//PORT0
					writeByte(_digitalPins % 128); // Tx pins 0-6
					writeByte((_digitalPins >> 7)&1); // Tx pin 7
				} else {
					writeByte(ARD_DIGITAL_MESSAGE+1);//PORT1
					writeByte(_digitalPins >>8); //Tx pins 8..13
					writeByte(0);
				}
			flush();
						

		}
		
		public function writeDigitalPins (mask:Number):void{
			// TODO
		}
		
		public function writeAnalogPin (pin:Number, value:Number):void{
			writeByte(ARD_ANALOG_MESSAGE+pin);
			writeByte(value % 128);
			writeByte(value >> 7);
			flush();
		}
		
		public function requestFirmwareVersion ():void{
			// writeDebug('requestFirmwareVersion()');
			writeByte(ARD_REPORT_VERSION);
			flush();
		}
		
		//FIRMATA2.0: SYSEX message to get version and name
		public function requestFirmwareVersionAndName():void{
			// writeDebug('requestFirmwareVersionAndName()');
			writeByte(ARD_SYSEX_MESSAGE_START);
			writeByte(ARD_SYSEX_QUERY_FIRMWARE);
			writeByte(ARD_SYSEX_MESSAGE_END);
			flush();
			
		}
		public function resetBoard ():void{
			// writeDebug('resetBoard()');
			writeByte(ARD_SYSTEM_RESET);
			flush();
		}
		
		//---------------------------------------
		//	PRIVATE FUNCTIONS
		//---------------------------------------
		private function socketDataHandler(event:ProgressEvent):void {
	    	while (bytesAvailable>0)
				processData(readByte());
		}
	
		private function processData (inputData:int) : void{
			if(inputData<0) 
				inputData=256+inputData;	
				
			// we have command data
			if(_waitForData>0 && inputData<128) {
				_waitForData--;
				
				// collect the data
				_storedInputData[_waitForData] = inputData;
				
				// we have all data executeMultiByteCommand
				if(_waitForData==0) {
					switch (_executeMultiByteCommand) {
						case ARD_DIGITAL_MESSAGE:
							//FIRMATA2.0 change in message format
							processDigitalPortBytes(_multiByteChannel, _storedInputData[1], _storedInputData[0]); //(LSB, MSB)
							//processDigitalBytes(_storedInputData[1], _storedInputData[0]); //(LSB, MSB)	
						break;
						case ARD_REPORT_VERSION: // report version						    
							//FIRMATA2.0 change in byte order
							// modification to display to subversion number ( 2.1 as 21 )							
							_firmwareVersion = (_storedInputData[1]*10)+_storedInputData[0]; // 10;
							dispatchEvent(new ArduinoEvent(ArduinoEvent.FIRMWARE_VERSION, 0, _firmwareVersion, _port));
						break;
						case ARD_ANALOG_MESSAGE: 
							_analogData[_multiByteChannel] = (_storedInputData[0] << 7) | _storedInputData[1];
							if(_analogData[_multiByteChannel]!=_previousAnalogData[_multiByteChannel])
								dispatchEvent(new ArduinoEvent(ArduinoEvent.ANALOG_DATA, _multiByteChannel, _analogData[_multiByteChannel], _port));
							_previousAnalogData[_multiByteChannel] = _analogData[_multiByteChannel];
						break;
					}
				
				}
			}
			// we have SysEx command data
			else if(_waitForData<0){
					// we have all sysex data
					if(inputData==ARD_SYSEX_MESSAGE_END){
						_waitForData=0;
						switch(_sysExData[0]) {
							case ARD_SYSEX_QUERY_FIRMWARE:
								processQueryFirmwareResult(_sysExData);
							break;
							case ARD_SYSEX_STRING:
								processSysExString(_sysExData);
							break
							default:
								dispatchEvent(new ArduinoSysExEvent(ArduinoSysExEvent.SYSEX_MESSAGE, _port, _sysExData));
							break;
						}
						_sysExData = new ByteArray();
					}
					// still have data, collect it
					else {
						_sysExData.writeByte(inputData);
					}
			}
			// we have a command
			else{
				
				var command:int;
				
				// extract the command and channel info from a byte if it is less than 0xF0
				if(inputData < 240) {
				  command = inputData & 240;
				  _multiByteChannel = inputData & 15;
				} 
				else {
				  // commands in the 0xF* range don't use channel data
				  command = inputData; 
				}
	
				switch (command) {
					case ARD_REPORT_VERSION:
					case ARD_DIGITAL_MESSAGE:
					case ARD_ANALOG_MESSAGE:
						_waitForData = 2;  // 2 bytes needed 
						_executeMultiByteCommand = command;
					break;
					case ARD_SYSEX_MESSAGE_START:
						_waitForData = -1;  // n bytes needed 
						_executeMultiByteCommand = command;
					break;
				}
				
			}	
		}
		
		/*Firmata2.0 change: new SysExMessage for receiving strings */
		/*TODO: do something with this */
		private function processSysExString(msg:ByteArray):void{
			//assemble string from rcv bytes - weird.
			var fname:String="";
			for(var i:Number=1; i< msg.length;i+=2) {
				fname+=String.fromCharCode(msg[i]);
			}
			//trace("Received SysExString:'" +fname+"'");
		
		}
		
		/*Firmata2.0 change: new SysExMessage for receiving Firmware Version and Name */
		private function processQueryFirmwareResult(msg:ByteArray):void{
				//assemble string from rcv bytes - weird.
				var fname:String="";
				for(var i:Number=3; i< msg.length;i+=2) {
					fname+=String.fromCharCode(msg[i]);
				}
				//trace("Firmware is: "+fname+ " Version "+msg[1]+"."+msg[2]);
				//_firmwareVersion = msg[1]+ msg[2] / 10;
				//TODO: create new event that transmits name?
				//dispatchEvent(new ArduinoEvent(ArduinoEvent.FIRMWARE_VERSION, 0, _firmwareVersion, _port));
		}
		
		/*Firmata2.0 change - incoming digital byte messages are now 8bit ports*/
		private function processDigitalPortBytes(port:int,bits0_6:int,bits7_13:int):void{
			var i:int;
			var mask:int;
			var twoBytesForPorts:int;
			var low:int;
			var high:int;
			var offset:int;
			twoBytesForPorts = bits0_6 + (bits7_13 << 7);
			// if port is 0, write bits 2..7 into _digitalData[2..7]
			// if port is 1, write bits 0..5 into _digitalData[8..13]
			if(port==0){
				low=2; high=7; offset = 0;
			} else {
				low=0; high=5; offset = 8;
			}
				for(i=low; i<=high; i++) {
					mask = 1 << i;
					_digitalData[i+offset]=(twoBytesForPorts & mask)>>i;
					if(_digitalData[i+offset]!=_previousDigitalData[i+offset])
						dispatchEvent(new ArduinoEvent(ArduinoEvent.DIGITAL_DATA, i+offset, _digitalData[i+offset], _port));
					_previousDigitalData[i+offset] = _digitalData[i+offset];
				  }
				}

		/**
		* Write up to 14 bits of an integer as two separate 7bit- bytes
		*/
		protected function writeIntAsTwoBytes(i:Number):void {
			i=int(i);
			writeByte(i%128); //LSB first
			writeByte(i>>7);  //MSB second
		}
	}
}