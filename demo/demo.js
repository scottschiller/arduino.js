/*
 * arduino.js: Canvas UI demo
 *
 */

/*jslint white: false, onevar: true, undef: true, nomen: false, eqeqeq: true, plusplus: false, bitwise: true, regexp: true, newcap: true, immed: true, regexp: false */
/*global arduino, window, document, setTimeout, setInterval */

var arduinoTimer = null;

function GraphItem(oCanvasCTX, index, x, y, w, h, maxY) {

  var history = [], i;
    
  for (i=0; i<w; i++) {
    history[i] = 0;
  }

  if (typeof maxY === 'undefined') {
    maxY = 1023;
  }

  this.recordValue = function(y) {
    history.push(y);
    if (history.length > w) {
      history.shift();
    }
  };

  this.draw = function() {
    if (!oCanvasCTX) {
      return false;
    }
    var thisY = null, i;
    oCanvasCTX.strokeStyle = 'rgba(32,128,224,1)';
    oCanvasCTX.fillStyle = 'rgba(0,0,0,0.75)';
    oCanvasCTX.font = 'bold 11px Helvetica, Arial, Sans-Serif';
    for (i=0; i<history.length; i++) {
      thisY = parseInt(Math.floor(h*(history[i]/maxY)), 10);
      if (thisY) {
        oCanvasCTX.strokeRect(x+i, y-thisY, 1, thisY);
      }
    }
    oCanvasCTX.fillText('A'+index+': '+history[history.length-1], x+3, y-(h-15));
  };

}

function CanvasThingy(analogPins) {

  var o = document.getElementById('arduino-canvas'),
    oCTX = (typeof o.getContext !== 'undefined' ? o.getContext('2d') : null),
    self = this,
    graphWidth = 256,
    graphHeight = 48,
    graphSpacing = 8;

  this.graphs = [];
    
  this.init = function() {
    var i, itemHeight = (graphHeight+graphSpacing);
    for (i=0; i<analogPins; i++) {
      self.graphs.push(new GraphItem(oCTX, i, 0, itemHeight*(i+1), graphWidth, graphHeight));
    }
    o.width = graphWidth;
    o.height = itemHeight*self.graphs.length;
  };
  
  this.recordValue = function(i, y) {
    self.graphs[i].recordValue(y);
  };
  
  this.update = function() {
    if (!oCTX) {
      return false;
    }
    oCTX.clearRect(0, 0, graphWidth, graphHeight*(self.graphs.length+1));
    for (var i=self.graphs.length; i--;) {
      self.graphs[i].draw();
    }
  };
  
  this.init();
  
}

arduino.onload = function() {
  // flash loaded, etc. Allow "connect" button.
  var o = document.getElementById('do-connect'),
      oMsg = document.getElementById('problem'),
      oFlash = document.getElementById(arduino.config.flash.containerID);
  if (o) {
    o.disabled = '';
    delete o.disabled;
  }
  if (oMsg) {
    // error recovery
    oMsg.innerHTML = 'Flash loaded, ready to connect.';
    // try to re-hide the flash, too?
    oFlash.style.background = 'transparent';
    oFlash.style.width = '1px';
    oFlash.style.height = '1px';
  }
};

arduino.onloaderror = function() {
  // flash maybe could not load, or start (blocked, or offline case)
  var o = document.getElementById('device-status-text');
  o.innerHTML = o.innerHTML + '&nbsp; <span id="problem"><b>Problem</b>: Flash could not start. Missing SWF, blocked, or viewing offline? Check <a href="#flash-troubleshooting">Flash Troubleshooting</a>.</span>';
};

function startArduinoDemo() {
  
  var pins = arduino.config.pins,
      analogPins = pins.analogInputCount, // use/show all analog inputs
      canvasItem = new CanvasThingy(analogPins), i;

  function updateStatus(html) {

    document.getElementById('device-status-text').innerHTML = html;

  }

  function swapDigital() {

    arduino.writeDigitalPin(this.rel, arduino.getDigitalData(this.rel) ? 0 : 1);

  }

  function randomizeAnalog() {

    arduino.writeAnalogPin(this.rel, parseInt(Math.random()*1023, 10));

  }

  function randomizePWM() {

    arduino.writeAnalogPin(this.rel, parseInt(Math.random()*256, 10));

  }


  function decorateIOPins() {

    var pins = arduino.config.pins,
        i, item, btn = document.createElement('button'), o;
    for (i=0; i<pins.length-1; i++) {
      item = document.getElementById('pin'+i+'-button');
      if (pins[i] === 'digitalOut') {
        o = item.appendChild(btn.cloneNode(true));
        o.innerHTML = 'invert';
        o.rel = i;
        o.onclick = swapDigital;
      } else if (pins[i] === 'analogOut') {
        o = item.appendChild(btn.cloneNode(true));
        o.innerHTML = 'randomize';
        o.rel = i;
        o.onclick = randomizeAnalog;
      } else if (pins[i] === 'pwmOut') {
        o = item.appendChild(btn.cloneNode(true));
        o.innerHTML = 'randomize';
        o.rel = i;
        o.onclick = randomizePWM;
      }
    }    

  }

  function readInputs() {

    var result = null, i, j;

    for (i=analogPins; i--;) {
      result = arduino.getAnalogData(i);
      document.getElementById('analog-pin'+i+'-value').innerHTML = result;
      canvasItem.recordValue(i, result);
    }

    for (i=2, j=pins.length - analogPins; i<j; i++) {
      document.getElementById('pin'+i+'-value').innerHTML = '(' + pins[i]+'): ' + arduino.pinData[i];
    }

  }

  function randomizePins() {

    var pins = arduino.config.pins,
        i, rndBit, rndValue;
    arduino.writeDebug('Randomizing pins for offline mode demo, using fake data');
    for (i=0; i<pins.length-1; i++) {
       rndBit = Math.random()>0.5?1:0;
       rndValue = parseInt(Math.random()*1024, 10);
      if (pins[i] === 'digitalOut' && i !== 13) { // exclude pin 13 from randomness
        arduino.writeDigitalPin(i, rndBit); 
      } else if (pins[i] === 'analogOut') {
        arduino.writeAnalogPin(i, rndValue);
      } else if (pins[i] === 'pwmOut') {
        arduino.writeAnalogPin(i, parseInt(Math.random()*256, 10));
      }
    }

  }

  function getBlinkInterval() {
    // use text input value.
    var defaultInterval = 1000,
        o = parseInt(document.getElementById('blink-interval').value, 10),
        i = (!isNaN(o) ? Math.abs(o) : defaultInterval);
    return i;
  }

  function doPin13Blink() {
    if (arduinoTimer) {
      arduino.writeDigitalPin(13, arduino.getDigitalData(13) === 1 ? 0 : 1);
      setTimeout(doPin13Blink, getBlinkInterval());
    }
  }

  updateStatus('Attempting to make socket connection...');

  arduino.connect('127.0.0.1', '5331', function() {

    var i = 0;

    if (arduino._flash.isOffline) {
      updateStatus('Unable to connect or no device found. Using randomly-generated data.');
      randomizePins();
    } else {
      updateStatus('Device found, connection established. Using live data.');
    }

    decorateIOPins();

    arduinoTimer = setInterval(function() {
      readInputs();
      if (arduino._flash.isOffline) {
        for (i=0; i<6; i++) {
          arduino.pinData[14+i] = parseInt(Math.random()*1024, 10);
        }
      }
      canvasItem.update();
    }, 50); // higher interval (msec) = less-frequent updates, etc.

    doPin13Blink();

  });
  
}