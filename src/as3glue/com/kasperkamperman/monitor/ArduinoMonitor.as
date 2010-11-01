package  com.kasperkamperman.monitor{	/* Monitor object
       Problem switch servo - pwm doens't work without restarting. 
	*/
	
	
	import flash.display.*;  	import flash.events.*;		
	import net.eriksjodin.arduino.ArduinoWithServo;	import net.eriksjodin.arduino.events.ArduinoEvent;	import net.eriksjodin.arduino.events.ArduinoSysExEvent;
	
	import com.kasperkamperman.monitor.PinConfigObj;
	import com.kasperkamperman.monitor.PinMonitorObj;
	
	import fl.controls.Button; 
		public class ArduinoMonitor extends MovieClip   	{	
  				private var _ioPin:int;		private var _ioPinName:String;		private var _ioPinText:String;	
		private var _a:ArduinoWithServo;				private var _defaultCfg:Array;		private var _monitorObject:PinMonitorObj;		private var _monitorObjectsArray:Array = new Array();
		
		private var _configObject:PinConfigObj;		private var _configObjectsArray:Array = new Array();				private var numEvents:uint; 
		  		public function ArduinoMonitor(a:ArduinoWithServo, dftCfg:Array = null)		{	_a = a;			_defaultCfg = dftCfg;			numEvents = 0;									for(var i:uint = 2; i<_defaultCfg.length; i++)			{ _monitorObject = new PinMonitorObj(_a, i, _defaultCfg);
			  _monitorObjectsArray[i] = _monitorObject;			  			  _monitorObject.x = 180;			  _monitorObject.y = 10+(35*(i-2)); 
				
			  // no config object needed for the analog pins
			  // they cannot be changed	
			  if(i<14) 
			  {	
				  _configObject = new PinConfigObj(_a, i, _defaultCfg, _monitorObject);
				  _configObjectsArray[i] = _configObject;
				  _configObject.x = 10;
				  _configObject.y = 10+(35*(i-2));
				  addChild(_configObject);
			  }
			 			   			  			  addChild(_monitorObject); 			} 	
			
			_a.addEventListener(ArduinoEvent.ANALOG_DATA, onReceiveAnalogData); 			_a.addEventListener(ArduinoEvent.DIGITAL_DATA, onReceiveDigitalData);			_a.addEventListener(ArduinoSysExEvent.SYSEX_MESSAGE, onReceiveSysExMessage);			
		}									// trace out data when it arrives...			private function onReceiveAnalogData(e:ArduinoEvent):void {			//trace((numEvents++) +" Analog pin " + e.pin + " on port: " + e.port +" = " + e.value);			if(_monitorObjectsArray[e.pin+14]!=null) _monitorObjectsArray[e.pin+14].update(e.value);					}				// trace out data when it arrives...		private function onReceiveDigitalData(e:ArduinoEvent):void {			if(_monitorObjectsArray[e.pin]!=null) _monitorObjectsArray[e.pin].update(e.value);						//trace((numEvents++) +" Digital pin " + e.pin + " on port: " + e.port +" = " + e.value);		}						// trace incoming sysex messages		private function onReceiveSysExMessage(e:ArduinoSysExEvent) {			trace((numEvents++) +" Received SysExMessage. Command:"+e.data[0]);		}					  	}	}