package com.kasperkamperman.monitor{	import flash.display.Sprite;	import flash.display.Graphics;	import flash.utils.Timer;	import flash.events.*;	import flash.text.*;		public class WavePlot extends Sprite 	{	private var _g:Graphics;		private var _refreshTimer:Timer;		private var _waveHeight:int;		private var _waveWidth:int;		private var _values:Array;		private var _col:uint;		private var _inputVal:Number;		private var _scaleFactor:Number; 
		
		private var _t:String; 				// name of graph
		private var _txt:TextField;
		private var _txtFormat:TextFormat;				public function WavePlot(t:String, w:uint = 128, h:uint = 128, maxVal:uint = 1023, color:uint = 0x00CC00) 	    { 	_waveHeight = h;			_waveWidth = w;
			_t = t;						// scale the value so the maxvalue is on top of the graph. 		    _scaleFactor = h/maxVal; 											var canvas:Sprite = new Sprite();			addChild(canvas);
			
			// don't plot more then 128 values, otherwise scale						if(_waveWidth>128)			{ canvas.scaleX = _waveWidth/128;							  _waveWidth = 128;			} 			
			_txtFormat = new TextFormat();
			_txtFormat.color = 0x000000;			_txtFormat.font = "Arial";			_txtFormat.bold = false;			_txtFormat.size = 12;
						_txt = new TextField();
			_txt.width = 256;			_txt.text = _t;
			_txt.setTextFormat(_txtFormat);			addChild(_txt);						canvas.x = 0;			canvas.y = 0;			_g = canvas.graphics;						_col = color;			_inputVal = 0;						_values = new Array(_waveWidth);						// init values array			for(var i:int =0; i<_waveWidth; i++) {				_values[i]=0;			}						_refreshTimer = new Timer(50);			_refreshTimer.addEventListener("timer", refreshPlot);			_refreshTimer.start();		}				public function set amplitude(v:Number):void		{ _inputVal = int(_scaleFactor * v);
		  //_txt.text = _t + " - value : " + v;
		  _txt.setTextFormat(_txtFormat);					}				private function refreshPlot(event:TimerEvent):void		{   _values.shift();			_values.push(_inputVal);						_g.clear();			_g.lineStyle(0, _col);			_g.beginFill(_col, 0.5);			_g.moveTo(0, _waveHeight);						for (var i:int = 0; i < _waveWidth; i++) {				_g.lineTo(i, _waveHeight - _values[i]);			}			_g.lineTo(i, _waveHeight);			_g.endFill();		}
	}	}