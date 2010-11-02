/** @license
 *
 * arduino.js: JavaScript-based Arduino communication
 * http://schillmania.com/projects/arduino-js/
 * Copyright 2010 (c) Scott Schiller,
 * Released under an MIT license.
 * Version: 2010.10.31
 *
 * ----------------------------------------------------------------------------
 * An experimental JavaScript wrapper for the ActionScript "AS3Glue" library
 * allowing for JavaScript <-> Flash <-> Socket/serial proxy <-> Arduino USB
 * communication/control within a web browser. Needs Flash 9 + Firmata 2.0.
 * 
 * The arduino.js package makes use of the following software:
 *
 * AS3Glue
 * Copyright 2007-2008 (c) Erik Sjodin, http://eriksjodin.net
 * and Bjoern Hartmann, http://bjoern.org
 * http://code.google.com/p/as3glue/
 * Released under an MIT license.
 * Some elements of AS3Glue's ActionScript code have been ported to JavaScript.
 *
 * Flash - Arduino Example script
 * Copyleft: Kasper Kamperman - Art & Technology - Saxion
 * http://www.kasperkamperman.com/blog/arduino/arduino-flash-communication-as3/
 * This script was used as the basis for ArduinoJS.as.
 *
 * See license.txt for details.
 *
 * ----------------------------------------------------------------------------
 */

/*jslint white: false, onevar: true, undef: true, nomen: false, eqeqeq: true, plusplus: false, bitwise: true, regexp: true, newcap: true, immed: true, regexp: false */
/*global window, document, navigator, console */

(function(window) {

function Arduino() {

  // -- Configuration options --

  this.config = {

    defaultHost: '127.0.0.1',
    defaultPort: 5331,

    // -- Pin configuration (analog + digital I/O) ---

    pins: [

    // -- type --------- label ----------- options ---

      null,            // Pin 0         null (is RX)
      null,            // Pin 1         null (is TX)
      'digitalOut',    // Pin 2         digitalIn or digitalOut
      'digitalOut',    // Pin 3         pwmOut or digitalIn or digitalOut
      'digitalOut',    // Pin 4         digitalIn or digitalOut
      'digitalOut',    // Pin 5         pwmOut or digitalIn or digitalOut
      'digitalOut',    // Pin 6         pwmOut or digitalIn or digitalOut
      'digitalOut',    // Pin 7         digitalIn or digitalOut
      'digitalOut',    // Pin 8         digitalIn or digitalOut
      'pwmOut',        // Pin 9         pwmOut or digitalIn or digitalOut or servo
      'pwmOut',        // Pin 10        pwmOut or digitalIn or digitalOut or servo
      'pwmOut',        // Pin 11        pwmOut or digitalIn or digitalOut
      'digitalIn',     // Pin 12        digitalIn or digitalOut
      'digitalOut',    // Pin 13        digitalIn or digialOut (LED connected)

    // -- dedicated analog inputs (Arduino Uno) ------

      'analogIn',      // Analog pin 0  analogIn
      'analogIn',      // Analog pin 1  analogIn
      'analogIn',      // Analog pin 2  analogIn
      'analogIn',      // Analog pin 3  analogIn
      'analogIn',      // Analog pin 4  analogIn
      'analogIn'       // Analog pin 5  analogIn

    ],

    /*
     * Debug options (global / type-specific)
     * ---------------------------------------------------------------
     * Note that enabling debugging can be handy for troubleshooting,
     * but will cause a lot of console.log() activity and will likely
     * cause lag/slowness in your app including serial tx/rx delays
     * due to high CPU use, etc. Disable debug for best responsiveness.
     *
     */

    debug: {

      enabled: true, // global switch for enabling/disabling output
      offlineMode: false, // true = fake socks connection, don't actually connect
      types: {
        common: true,  // setup/config/connection messages, "everything else" etc.
        getData: false, // get/write data calls can be very frequent
        writeData: true,
        onAnalogRX: false, // analogRX events will likely fire constantly due to electrical noise
        onDigitalRX: false
      }

    },

    // flash socket/firmata protocol proxy configuration
    flash: {

      url: 'swf/arduinojs.swf',  // where to load the flash movie from
      debug: true,               // enable additional console debug messages originating from Flash
      showUI: false,              // true = show SWF inline (debugging/flash blocker cases?), true = "hide" flash movie off-screen
      useHighPerformance: true,  // true = uses position:fixed for (hidden) on-screen positioning, better responsiveness
      containerID: 'arduino-container', // <div> element to create or append to
      movieID: 'arduinoSWF',     // for the <embed> or <object>
      movieWidth: 400,
      movieHeight: 120

    }

  };

  // --- "pinData" cache (referenced by getters/setters, updated via Flash) ---
  this.pinData = [];

  // --- User-assignable events ---
  this.onload = null;
  this.onconnect = null;
  this.onAnalogReceiveData = function(pinNumber, port, value) {};
  this.onDigitalReceiveData = function(pinNumber, port, value) {};

  // flash <-> Arduino connection flags
  this.connected = false;
  this.connectFailed = false;

  // --- Private internals ---
  var _flash = null,
      oMC = null,
      self = this,
      isReady = false,
      madeSWF = false,
      _isIE = (navigator.userAgent.match(/msie/i)),
      _onready, _ready, _onconnect, callFlash, getSWF, makeSWF, domReady, domReadyIE, init, applyDefaultPinConfig, pinModes, pinRanges, validateCall, analogInputPinOffset, validators = {
      aOut: /(analogOut|pwmOut)/,
      dOut: /digitalOut/,
      servo: /servo/
      };


  // --- Public API methods ---
  this.connect = function(host, port, onconnect) {

    var str = 'arduino.connect(' + host + ',' + port + '): Opening socket...';
    self.connectFailed = false;
    if (typeof host === 'undefined') {
      host = self.config.defaultHost;
    }
    if (typeof port === 'undefined') {
      port = self.config.defaultPort;
    }
    self.writeDebug(str);
    if (self.connected) {
      self.writeDebug(str + ': Already connected.');
      return false;
    }
    self.onconnect = onconnect;
    callFlash('_connect', host, port);
    window.setTimeout(function() {
      if (!self.connected) {
        if (self.config.debug.offlineMode) {
          self._flash.fakeConnect();
        } else if (!self.connectFailed) {
          self.writeDebug('arduino.connect: If proxy is running but not returning firmware version, try restarting it (and/or check its serial config)');
        }
      }
    }, 2000);
    return true;

  };

  this.writeAnalogPin = function(pinNumber, value) { // value: 0-255

    var m = 'arduino.writeAnalogPin(' + pinNumber + ', ' + value + ')',
        mType = 'writeData',
        result = validateCall(pinNumber, value, validators.aOut);
    if (!result.ok) {
      throw new Error(m + ': ' + result.message);
    }
    self.writeDebug(m, mType);
    // only write fresh values
    if (self.pinData[pinNumber] !== value) {
      callFlash('_writeAnalogPin', pinNumber, value);
      self.pinData[pinNumber] = value;
    }
    return true;

  };

  this.getAnalogData = function(pinNumber) {
    self.writeDebug('arduino.getAnalogData(' + pinNumber + ')', 'getData');
    // we can pull this from the local "cache" rather than doing a JS/Flash call.
    return self.pinData[analogInputPinOffset + pinNumber];
    // return callFlash('_getAnalogData', pinNumber);
  };

  this.writeDigitalPin = function(pinNumber, bit) { // bit: 0 or 1

    var m = 'arduino.writeDigitalPin(' + pinNumber + ', ' + bit + ')',
        mType = 'writeData',
        result = validateCall(pinNumber, bit, validators.dOut);
    if (!result.ok) {
      throw new Error(m + ': ' + result.message);
    }
    self.writeDebug(m, 'writeData');
    if (self.pinData[pinNumber] !== bit) {
      callFlash('_writeDigitalPin', pinNumber, bit);
      self.pinData[pinNumber] = bit; // .. and update the local cache
    }

  };

  this.getDigitalData = function(pinNumber) {

    self.writeDebug('arduino.getDigitalData(' + pinNumber + ')', 'getData');
    // use local cache instead of JS/flash call
    // return callFlash('_getDigitalData', pinNumber);
    return self.pinData[pinNumber];

  };

  this.setPinMode = function(pinNumber, modeType) {

    self.writeDebug('arduino.setPinMode(' + pinNumber + ', ' + modeType + ')');
    callFlash('_setPinMode', pinNumber, pinModes[modeType]);
    self.config.pins[pinNumber] = modeType; // update local config, too
  };

  this.setAnalogPinReporting = function(pinNumber, mode) {

    self.writeDebug('arduino.setAnalogPinReporting(' + pinNumber + ', ' + mode + ')');
    callFlash('_setAnalogPinReporting', pinNumber, mode);

  };

  this.enableDigitalPinReporting = function() {

    self.writeDebug('arduino.enableDigitalPinReporting()');
    callFlash('_enableDigitalPinReporting');

  };

  this.disableDigitalPinReporting = function() {

    self.writeDebug('arduino.disableDigitalPinReporting()');
    callFlash('_disableDigitalPinReporting');

  };

  this.getFirmwareVersion = function() {

    self.writeDebug('arduino.getFirmwareVersion()');
    return callFlash('_getFirmwareVersion');

  };

  this.setupServo = function(pinNumber, angle) {

    self.writeDebug('arduino.setupServo(' + pinNumber + ', ' + angle + ')');
    callFlash('_setupServo', pinNumber, angle);

  };

  this.resetBoard = function() {

    self.writeDebug('arduino.resetBoard()');
    callFlash('_resetBoard');

  };

  // --- Pseudo-private internals ---

  // methods that are called from flash

  this._flash = {

    onready: function() {
      if (self._flash.timer) {
        window.clearTimeout(self._flash.timer);
        self._flash.timer = null;
      }
      self.writeDebug('arduino::flash::Ready to connect.');
      _flash = getSWF();
      _onready();
    },

    onconnect: function() {
      self.writeDebug('arduino::flash::onconnect()');
      self.connected = true;
      applyDefaultPinConfig();
      _onconnect();
    },

    onAnalogRX: function(pin, port, value) {
      self.writeDebug('arduino::flash::onAnalogRX: ' + pin + ', ' + port + ', ' + value, 'onAnalogRX');
      self.pinData[analogInputPinOffset + pin] = value;
      self.onAnalogReceiveData(pin, port, value);
    },

    onDigitalRX: function(pin, port, value) {
      self.writeDebug('arduino::flash::onDigitalRX: ' + pin + ', ' + port + ', ' + value, 'onDigitalRX');
      self.pinData[pin] = value;
      self.onDigitalReceiveData(pin, port, value);
    },

    debugFromFlash: function(s) {
      self.writeDebug('(arduino SWF) ' + s);
    },

    connectFailed: function() {
      self.writeDebug('arduino::flash::connectFailed()');
      self.connectFailed = true;
    },

    startupFailed: function() {
      var o = getSWF(), oBox = document.getElementById(arduino.config.flash.containerID),
          didLoad = o && typeof o.PercentLoaded !== 'undefined' && o.PercentLoaded() > 0,
          isHTTP = document.location.protocol.match(/http/);
      self.writeDebug('arduino::flash::SWF load/start-up failed');
      self.writeDebug('arduino::makeSWF: '+(!didLoad ? (!isHTTP ? 'Flash blocked, missing .SWF, or additional flash security permissions may be needed for offline viewing to work (see Adobe Flash Global Security Settings Panel.)':'') : 'Check that flash file is not missing, or blocked from loading.'));
      self._flash.timer = null;
      if (!isHTTP) {
        if (oBox) {
          oBox.style.background = '#eee';
          oBox.style.padding = '0.5em';
          oBox.style.width = 'auto';
          oBox.style.height = 'auto';
        }
      }
      if (self.onloaderror) {
        self.onloaderror();
      }
    },

    fakeConnect: function() {
      // fake it, connect anyhow
      self.writeDebug('Offline mode: Connection likely timed out. Faking it...');
      if (!isReady) {
        _onready();
      }
      self._flash.isOffline = true;
      self._flash.onconnect();
    },

    timer: null,
    isOffline: false

  };

  this.writeDebug = function(s, sType) {

    if (!self.config.debug.enabled) {
      return false;
    }
    if (typeof sType === 'undefined') {
      sType = 'common';
    }
    if (self.config.debug.types[sType] && typeof console !== 'undefined' && typeof console.log !== 'undefined') {
      console.log(s);
    }

  };

  // --- More private internals ---

  applyDefaultPinConfig = function() {

    // set pin modes according to defaultPinConfig

    self.writeDebug('arduino: Applying pin configuration');
    var pins = self.config.pins,
        i, j;
    for (i = 0, j = pins.length; i < j; i++) {
      if (pins[i] && pins[i].match(/(digitalOut|digitalIn|pwmOut)/)) {
        self.setPinMode(i, pins[i]);
      } else if (pins[i] === "servo") {
        self.setupServo(i, 0);
        // write set start position to 0 otherwise it turns directly to 90 degrees.
        self.writeAnalogPin(i, 0);
      }
    }

    // enable analog + digital pin reporting

    for (j = 0; j < self.config.pins.analogInputCount; j++) {
      self.setAnalogPinReporting(j, 1);
    }
    self.enableDigitalPinReporting();

  };

  // allowed pin modes and values, validation

  pinModes = {

    digitalIn: 0,
    digitalOut: 1,
    pwmOut: 3

  };

  pinRanges = {

    digitalOut: {
      min: 0,
      max: 1
    },
    analogOut: {
      min: 0,
      max: 1023
    },
    pwmOut: {
      min: 0,
      max: 255
    },
    servo: {
      min: 0,
      max: 179
    }

  };

  validateCall = function(pinNumber, value, allowedMethods) {

    var pinConfigType = self.config.pins[pinNumber],
        pinCount = analogInputPinOffset, // addressable range
        ranges = pinRanges[pinConfigType],
        configMismatch = (!ranges || !allowedMethods.test(pinConfigType)),
        isInvisiblePin = (pinNumber < 0 || pinNumber > pinCount),
        isBad = (!ranges || isNaN(value) || value < ranges.min || value > ranges.max || configMismatch || isInvisiblePin),
        message;

    if (isBad) {
      if (isInvisiblePin) {
        message = 'Pin ' + pinNumber + ' does not exist. Valid range is 2-' + (pinCount-1) + ' for standard pins, 0-' + (self.config.pins.length-pinCount) + ' for analog inputs.';
      } else if (configMismatch) {
        message = 'Call not permitted, pin ' + pinNumber + ' type is ' + pinConfigType;
      } else {
        message = 'Value invalid or out of range (' + ranges.min + '-' + ranges.max + ' expected for ' + pinConfigType + ' type)';
      }
    }

    return {
      'ok': !isBad,
      'message': message
    };

  };

  // internal event handlers

  _onready = function() {

    self.writeDebug('arduino::onready()');
    isReady = true;
    if (self.onload) {
      self.onload();
    }

  };

  _onconnect = function() {

    self.writeDebug('Arduino: Ready for I/O.');
    if (self.onconnect) {
      self.onconnect();
    }

  };

  _ready = function() {

    if (!self._flash.isOffline && (!isReady || !_flash)) {
      self.writeDebug('arduino: Not ready yet. Wait for onready().');
      return false;
    }
    if (!self.connected) {
      self.writeDebug('arduino: Not connected yet, or connection failed.');
      return false;
    }
    return true;

  };

  // flash communication/handling

  callFlash = function() {

    var args = Array.prototype.slice.call(arguments),
        // real array, please
        method = args.shift(), // first argument
        isConnect = (arguments[0] === '_connect'),
        result;
    if (!isConnect && (!_ready() || self._flash.isOffline)) { // allow connect attempt at any time, but filter not ready / not online
      return false;
    }
    try {
      // no call/apply() on NPAPI objects, eg. Flash plugin? (otherwise, would not need silly argument length checks.)
      if (args.length === 3) {
        result = getSWF()[method](args[2], args[1], args[0]);
      } else if (args.length === 2) {
        result = getSWF()[method](args[0], args[1]);
      } else if (args.length === 1) {
        result = getSWF()[method](args[0]);
      } else {
        result = getSWF()[method]();
      }
    } catch (e) {
      self.writeDebug('Flash ExternalInterface ' + e.toString());
    }
    return result;

  };

  getSWF = function() {

    var id = self.config.flash.movieID;
    return (window[id] || document[id] || document.getElementById(id)); // IE vs. Safari vs. all good browsers

  };

  makeSWF = function() {

    if (madeSWF) {
      return false;
    }

    madeSWF = true;

    var flash = self.config.flash,
        oMC = document.getElementById(flash.containerID) ? document.getElementById(flash.containerID) : document.createElement('div'),
        movieHTML, oMovie, didCreate = false,
        oEmbed, tmp, s, x;

    self.writeDebug('arduino::makeSWF: Loading ' + flash.url);

    self._flash.timer = window.setTimeout(self._flash.startupFailed, 2000);

    if (!oMC.id) {
      didCreate = true;
      oMC.id = flash.containerID;
      if (!flash.useHighPerformance) {
        try {
          oMC.style.display = 'inline-block';
        } catch(e) {
          // oh well
        }
      }
    }

    oEmbed = {
      'name': flash.movieID,
      'id': flash.movieID,
      'src': flash.url,
      'width': flash.movieWidth,
      'height': flash.movieHeight,
      'quality': 'high',
      'allowScriptAccess': 'always',
      'bgcolor': '#ffffff',
      'pluginspage': 'http://www.macromedia.com/go/getflashplayer',
      'type': 'application/x-shockwave-flash',
      'wmode': 'transparent',
      'FlashVars': 'hideFlashUI=' + (flash.showUI ? 0 : 1) + '&allowJSDebug=' + (self.config.debug.enabled && self.config.flash.debug ? 1 : 0)
    };

    if (flash.showUI) {
      delete oEmbed.wmode;
    }

    if (_isIE) {
      // IE is "special".
      oMovie = document.createElement('div');
      movieHTML = '<object id="' + flash.movieID + '" data="' + flash.movieURL + '" type="' + oEmbed.type + '" width="' + oEmbed.width + '" height="' + oEmbed.height + '"><param name="movie" value="' + flash.url + '" /><param name="AllowScriptAccess" value="' + oEmbed.allowScriptAccess + '" /><param name="quality" value="' + oEmbed.quality + '" />' + (oEmbed.wmode ? '<param name="wmode" value="' + oEmbed.wmode + '" /> ' : '') + '<param name="bgcolor" value="' + oEmbed.bgColor + '" />' + (!flash.showUI ? '<param name="FlashVars" value="' + oEmbed.FlashVars + '" />' : '') + '<!-- --></object>';
    } else {
      oMovie = document.createElement('embed');
      for (tmp in oEmbed) {
        if (oEmbed.hasOwnProperty(tmp)) {
          oMovie.setAttribute(tmp, oEmbed[tmp]);
        }
      }
    }

    if (!flash.showUI) {
      if (flash.useHighPerformance) {
        s = {
          'position': 'fixed',
          'width': '8px',
          'height': '8px',
          // >= 6px for flash to run fast, >= 8px to start up under Firefox/win32 in some cases. odd? yes.
          'bottom': '0px',
          'right': '0px',
          'overflow': 'hidden'
        };
      } else {
        s = {
          'position': 'absolute',
          'width': '6px',
          'height': '6px',
          'top': '-9999px',
          'left': '-9999px'
        };
      }
    } else {
      s = {
        border: '1px solid #ccc',
        padding: '5px'
      };
    }

    for (x in s) {
      if (s.hasOwnProperty(x)) {
        oMC.style[x] = s[x];
      }
    }

    try {
      if (!_isIE) {
        oMC.appendChild(oMovie);
      }
      if (didCreate) {
        (document.body || document.documentElement).appendChild(oMC);
      }
      if (_isIE) {
        oMC.appendChild(document.createElement('div')).innerHTML = movieHTML;
      }
    } catch(ee) {
      throw new Error('Fatal: Could not append SWF to DOM.');
    }

  };

  // domReady events for init

  domReady = function() {

    makeSWF();
    document.removeEventListener('DOMContentLoaded', domReady, false);

  };

  domReadyIE = function() {

    if (document.readyState === 'complete') {
      makeSWF();
      document.detachEvent('onreadystatechange', domReadyIE);
    }

  };

  init = function() {

    var i, analogCount = 0;
    for (i = 0; i < self.config.pins.length; i++) {
      self.pinData[i] = null;
      if (self.config.pins[i] === 'analogIn') {
        analogCount++;
      }
    }

    self.config.pins.analogInputCount = analogCount;

    // analog inputs get their own zero-based offset, eg. writeAnalogPin(0)

    analogInputPinOffset = parseInt(self.config.pins.length - analogCount, 10);

    if (document.addEventListener) {
      document.addEventListener('DOMContentLoaded', domReady, false);
    } else if (document.attachEvent) {
      document.attachEvent('onreadystatechange', domReadyIE);
    }
    if (document.readyState === 'complete') {
      domReady();
    }

  };

  init(); // .. and, begin.

}

window.arduino = new Arduino();

}(window));