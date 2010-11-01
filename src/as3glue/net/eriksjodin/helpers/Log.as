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
package net.eriksjodin.helpers
{
	/**
	* @author Erik Sjodin, eriksjodin.net
	*/
	public final class Log
	{
		private static var _user:String = "info";
		private static var _enabled:Boolean = false;
		private static var _level:int = 0;
		
		public static const DEBUG:int = 0;
		
		public static const INFO:int = 1;
		
		public static const WARN:int = 2;
		
		public static const ERROR:int = 3;
		
		public static const FATAL:int = 4;

		private static function resolveLevelAsName(level:int):String
		{
			switch(level)
			{
				case 0:
					return "debug";
				break;
				
				case 1:
					return "info";
				break;
				
				case 2:
					return "warn";
				break;
				
				case 3:
					return "error";
				break;
				
				case 4:
					return "fatal";
				break;
				
				default:
					return "debug";
			}
		}
		
		public static function fatal(user:String = "info", ... args):void
		{
			if(_enabled && (_user==user || user == "info") && _level>=FATAL){
				trace(resolveLevelAsName(_level), user , args);
			}
		}
		
		public static function error(user:String = "info", ... args):void
		{
			if(_enabled && (_user==user || user == "info") && _level>=ERROR){
				trace(resolveLevelAsName(_level), user , args);
			}
		}
		
		public static function warn(user:String = "info", ... args):void
		{
			if(_enabled && (_user==user || user == "info") && _level>=WARN){
				trace(resolveLevelAsName(_level), user , args);
			}
		}
		
		public static function info(user:String = "info", ... args):void
		{
			if(_enabled && (_user==user || user == "info") && _level>=INFO){
				trace(resolveLevelAsName(_level), user , args);
			}
		}
		
		public static function debug(user:String = "info", ... args):void
		{
			if(_enabled && (_user==user || user == "info") && _level>=DEBUG){
				trace(resolveLevelAsName(_level), user , args);
			}
		}
		
		/**
		* @param level setting the the level to 0 will log everything for the specified user
		* @param user setting the the user to "info" will show logs for all users
		* @return nothing
		*/
		public static function enable(level:int = 0, user:String = "info"):void
		{
			_user = user;
			_level = level;
			_enabled = true;
		}
		
		public static function disable():void
		{
			_enabled = false;
		}
		
	}
}