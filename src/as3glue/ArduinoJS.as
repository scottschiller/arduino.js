/*
 * arduino.js: JavaScript-based Arduino communication
 * http://schillmania.com/projects/arduino-js/
 * Copyright 2010 (c) Scott Schiller, http://schillmania.com/
 * Released under an MIT license.
 * Version: 2010.10.29
 * 
 * See license.txt for details.
 *
 * This file is based on "Flash - Arduino Example script"
 * Copyleft: Kasper Kamperman - Art & Technology - Saxion
 * http://www.kasperkamperman.com/blog/arduino/arduino-flash-communication-as3/
 *
 *
 * Original AS3Glue header + copyright notice (MIT license):
 * http://code.google.com/p/as3glue/
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

package {

	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFieldAutoSize;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.external.ExternalInterface; // woo
	import net.eriksjodin.arduino.Arduino;
	import net.eriksjodin.arduino.ArduinoWithServo;
	import net.eriksjodin.arduino.events.ArduinoEvent;
	import net.eriksjodin.arduino.events.ArduinoSysExEvent;

	public class ArduinoJS extends Sprite {

		// Arduino object
		private var a:ArduinoWithServo;
		
		// name reference of the JavaScript object we'll call in the browser
		private var arduinoJSObj:String = 'window.arduino._flash';

		private var hideFlashUI:Boolean = false;
		private var allowJSDebug:Boolean = true;
		private var paramList:Object;
		private var messages:Array = [];
		private var textField: TextField = null;
		private var textStyle: TextFormat = new TextFormat();
		
		private function flashDebug(txt:String):void {

			if (allowJSDebug) {
				messages.push(txt);
				var didCreate: Boolean = false;
				textStyle.font = 'Arial';
				textStyle.size = 12;
				// 320x240 if no stage dimensions (happens in IE, apparently 0 before stage resize event fires.)
				var w:Number = this.stage.width?this.stage.width:320;
				var h:Number = this.stage.height?this.stage.height:240;
				if (textField == null) {
					didCreate = true;
					this.stage.scaleMode = 'noScale';
					this.stage.align = 'TL';
					var canvas: Sprite = new Sprite();
					canvas.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
					addChild(canvas);
					textField = new TextField();
					textField.autoSize = TextFieldAutoSize.LEFT;
					textField.x = 0;
					textField.y = 0;
					textField.multiline = true;
					textField.textColor = 0;
					textField.wordWrap = true;
				}
				textField.htmlText = messages.join('\n');
				textField.setTextFormat(textStyle);
				textField.width = w;
				textField.height = h;
				if (didCreate) {
					canvas.addChild(textField);
				}
			}

		}
		
		private function writeDebug(str:String):void {

			flashDebug(str);
			if (allowJSDebug) {
				try {
					ExternalInterface.call(jsMethod('debugFromFlash'), str);
				} catch(e:Error) {
					// oh well
					// flashDebug('Error during writeDebug call');
				}
			}

		}
		
		private function jsMethod(method:String):String { // allowWriteDebug:Boolean = true
			return arduinoJSObj+"."+method;
		}
		
		private function _connect(host:String, port:String):void {

			try {
				writeDebug('arduino.connect('+host+', '+port+')');

				// connect to a serial proxy
				a = new ArduinoWithServo(host, parseInt(port));

				addArduinoListeners(a);

				// add ExternalInterface callbacks
				addArduinoEI(a);

				// listen for connection
				a.addEventListener(Event.CONNECT,onSocketConnect);
				a.addEventListener(IOErrorEvent.IO_ERROR,errorHandler);

				// listen for firmware (sent on startup)
				a.addEventListener(ArduinoEvent.FIRMWARE_VERSION, onReceiveFirmwareVersion);
			} catch(e:Error) {
				writeDebug('arduino.connect failure: '+e.toString());
			}

		}
		
		private function addEI():void {

			if (ExternalInterface.available) {
				writeDebug('-- arduino.js, SWF component --');
				writeDebug('ExternalInterface available');
				try {
					writeDebug('Adding ExternalInterface callbacks...');
					ExternalInterface.addCallback('_connect', _connect);
					writeDebug('OK (waiting for connect() from JS)');
					writeDebug('Firing onready(), JS-side...');
					ExternalInterface.call(jsMethod('onready'));
				} catch(e: Error) {
					writeDebug('Fatal: ExternalInterface error: ' + e.toString());
				}
			} else {
				writeDebug('Fatal: ExternalInterface (Flash &lt;-&gt; JS) not available');
			}

		}
		
		private function onReceiveAnalogData(e:ArduinoEvent):void {

			ExternalInterface.call(jsMethod('onAnalogRX'), e.pin, e.port, e.value);

		}

		private function onReceiveDigitalData(e:ArduinoEvent):void {

			ExternalInterface.call(jsMethod('onDigitalRX'), e.pin, e.port, e.value);

		}
		
		private function addArduinoListeners(a:ArduinoWithServo):void {
			
			writeDebug('addArduinoListeners()');
			a.addEventListener(ArduinoEvent.ANALOG_DATA, onReceiveAnalogData);
			a.addEventListener(ArduinoEvent.DIGITAL_DATA, onReceiveDigitalData);
			
		}

		private function addArduinoEI(a:ArduinoWithServo):void {

			ExternalInterface.addCallback('_writeDigitalPin', function(pin:int, bit:int):void {
				// writeDebug('arduino::writeDigitalPin('+pin+', '+(bit === 1 ? Arduino.ON : Arduino.OFF)+')');
				a.writeDigitalPin(pin, bit);
			});

			ExternalInterface.addCallback('_writeAnalogPin', function(pin:int, value:Number):void {
				// writeDebug('arduino::writeAnalogPin('+pin+', '+value+')');
				a.writeAnalogPin(pin, value);
			});

			ExternalInterface.addCallback('_getFirmwareVersion', function():int {
				// writeDebug('arduino::getFirmwareVersion');
				return a.getFirmwareVersion();
			});

			ExternalInterface.addCallback('_getAnalogData', function(pin:int):int {
				// writeDebug('arduino::getAnalogData('+pin+')');
				return a.getAnalogData(pin);
			});

			ExternalInterface.addCallback('_getDigitalData', function(pin:int):int {
				// writeDebug('arduino::getDigitalData('+pin+')');
				return (a.getDigitalData(pin) ? 1 : 0);
			});

			ExternalInterface.addCallback('_setAnalogPinReporting', function(pin:int, mode:int):void {
				// writeDebug('arduino::setAnalogPinReporting('+pin+', '+mode+')');
				a.setAnalogPinReporting(pin, mode);
			});

			ExternalInterface.addCallback('_enableDigitalPinReporting', function():void {
				// writeDebug('arduino::enableDigitalPinReporting()');
				a.enableDigitalPinReporting();
			});

			ExternalInterface.addCallback('_disableDigitalPinReporting', function():void {
				// writeDebug('arduino::disableDigitalPinReporting()');
				a.disableDigitalPinReporting();
			});

			ExternalInterface.addCallback('_setPinMode', function(pin:int, mode:int):void {
				// writeDebug('arduino::setPinMode('+pin+', '+mode+')');
				a.setPinMode(pin, mode);
			});

			ExternalInterface.addCallback('_writeDigitalPin', function(pin:int, value:int):void {
				// writeDebug('arduino::writeDigitalPin('+pin+', '+value+')');
				a.writeDigitalPin(pin, value);
			});

			ExternalInterface.addCallback('_writeAnalogPin', function(pin:int, value:int):void {
				// writeDebug('arduino::writeAnalogPin('+pin+', '+value+')');
				a.writeAnalogPin(pin, value);
			});

			ExternalInterface.addCallback('_setupServo', function(pin:Number, angle:Number):void {
				// writeDebug('arduino::setupServo('+pin+', '+angle+')');
				a.setupServo(pin, angle);
			});

			/*
			ExternalInterface.addCallback('_requestFirmwareVersion', function():void {
				writeDebug('arduino::requestFirmwareVersion()');
				a.requestFirmwareVersion();
			});

			ExternalInterface.addCallback('_requestFirmwareVersionAndName', function():void {
				writeDebug('arduino::requestFirmwareVersionAndName()');
				a.requestFirmwareVersionAndName();
			});
			*/

			ExternalInterface.addCallback('_resetBoard', function():void {
				// writeDebug('arduino::resetBoard()');
				a.resetBoard();
			});

		}
		
		public function ArduinoJS() {

			paramList = this.root.loaderInfo.parameters;

			if (paramList.hideFlashUI == 1) {
				hideFlashUI = true;
			}
			if (paramList.allowJSDebug == 0) {
				allowJSDebug = false;
			}

			addEI();

		}

		// == SETUP AND INITIALIZE CONNECTION ( don't modify ) ==================================
		// triggered when there is an IO Error
		private function errorHandler(errorEvent:IOErrorEvent):void {

			writeDebug("- "+errorEvent.text);
			writeDebug("Socket IO error, unable to connect. (Check that proxy is running.)");
			ExternalInterface.call(jsMethod('connectFailed'));

		}

		// triggered when a serial socket connection has been established
		private function onSocketConnect(e:Object):void {

			writeDebug("Socket connection established, waiting for firmware version...");
			// request the firmware version
			a.requestFirmwareVersion();

		}

		private function onReceiveFirmwareVersion(e:ArduinoEvent):void {

			writeDebug("Connection with Arduino - Firmata version: " + String(e.value));
			startProgram();
	
		}

		// == START PROGRAM =====================================================================

		private function startProgram():void {

			writeDebug("Arduino: Connected.");
			ExternalInterface.call(jsMethod('onconnect'));

		}
	
	}

}