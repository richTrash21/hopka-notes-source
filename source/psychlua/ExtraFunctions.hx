package psychlua;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import flixel.util.FlxSave;
import openfl.utils.Assets;

//
// Things to trivialize some dumb stuff like splitting strings on older Lua
//

class ExtraFunctions
{
	public static function implement(funk:FunkinLua)
	{		
		// Keyboard & Gamepads
		funk.set("keyboardJustPressed",	  LuaUtils.keyJustPressed);
		funk.set("keyboardPressed",		  LuaUtils.keyPressed);
		funk.set("keyboardJustReleased",  LuaUtils.keyJustReleased);
		funk.set("keyboardReleased",	  LuaUtils.keyReleased);

		funk.set("anyGamepadJustPressed", FlxG.gamepads.anyJustPressed);
		funk.set("anyGamepadPressed",	  FlxG.gamepads.anyPressed);
		funk.set("anyGamepadReleased",	  FlxG.gamepads.anyJustReleased);

		funk.set("gamepadAnalogX", function(id:Int, ?leftStick:Bool = true)
		{
			final controller = FlxG.gamepads.getByID(id);
			return controller == null ? 0.0 : controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		funk.set("gamepadAnalogY", function(id:Int, ?leftStick:Bool = true)
		{
			final controller = FlxG.gamepads.getByID(id);
			return controller == null ? 0.0 : controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		funk.set("gamepadJustPressed", function(id:Int, name:String)
		{
			final controller = FlxG.gamepads.getByID(id);
			return controller == null ? false : Reflect.getProperty(controller.justPressed, name) == true;
		});
		funk.set("gamepadPressed", function(id:Int, name:String)
		{
			final controller = FlxG.gamepads.getByID(id);
			return controller == null ? false : Reflect.getProperty(controller.pressed, name) == true;
		});
		funk.set("gamepadReleased", function(id:Int, name:String)
		{
			final controller = FlxG.gamepads.getByID(id);
			return controller == null ? false : Reflect.getProperty(controller.justReleased, name) == true;
		});

		funk.set("keyJustPressed", function(name:String = '') {
			return switch(name = name.toLowerCase()) {
				case 'left':	return PlayState.instance.controls.NOTE_LEFT_P;
				case 'down':	return PlayState.instance.controls.NOTE_DOWN_P;
				case 'up':		return PlayState.instance.controls.NOTE_UP_P;
				case 'right':	return PlayState.instance.controls.NOTE_RIGHT_P;
				default:		return PlayState.instance.controls.justPressed(name);
			}
		});
		funk.set("keyPressed", function(name:String = '') {
			return switch(name = name.toLowerCase()) {
				case 'left':	return PlayState.instance.controls.NOTE_LEFT;
				case 'down':	return PlayState.instance.controls.NOTE_DOWN;
				case 'up':		return PlayState.instance.controls.NOTE_UP;
				case 'right':	return PlayState.instance.controls.NOTE_RIGHT;
				default:		return PlayState.instance.controls.pressed(name);
			}
		});
		funk.set("keyReleased", function(name:String = '') {
			return switch(name = name.toLowerCase()) {
				case 'left':	return PlayState.instance.controls.NOTE_LEFT_R;
				case 'down':	return PlayState.instance.controls.NOTE_DOWN_R;
				case 'up':		return PlayState.instance.controls.NOTE_UP_R;
				case 'right':	return PlayState.instance.controls.NOTE_RIGHT_R;
				default:		return PlayState.instance.controls.justReleased(name);
			}
		});

		// Save data management
		funk.set("initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			if(!PlayState.instance.modchartSaves.exists(name))
			{
				final save:FlxSave = new FlxSave();
				// folder goes unused for flixel 5 users. @BeastlyGhost
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				PlayState.instance.modchartSaves.set(name, save);
				return;
			}
			FunkinLua.luaTrace('initSaveData: Save file already initialized: $name');
		});
		funk.set("flushSaveData", function(name:String) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				PlayState.instance.modchartSaves.get(name).flush();
				return;
			}
			FunkinLua.luaTrace('flushSaveData: Save file not initialized: $name', false, false, FlxColor.RED);
		});
		funk.set("getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				final saveData = PlayState.instance.modchartSaves.get(name).data;
				(Reflect.hasField(saveData, field))
					? return Reflect.field(saveData, field)
					: return defaultValue;
			}
			FunkinLua.luaTrace('getDataFromSave: Save file not initialized: $name', false, false, FlxColor.RED);
			return defaultValue;
		});
		funk.set("setDataFromSave", function(name:String, field:String, value:Dynamic) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				Reflect.setField(PlayState.instance.modchartSaves.get(name).data, field, value);
				return;
			}
			FunkinLua.luaTrace('setDataFromSave: Save file not initialized: $name', false, false, FlxColor.RED);
		});

		// File management
		funk.set("checkFileExists", function(filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute) return FileSystem.exists(filename);
			var path:String = Paths.modFolders(filename);
			if(FileSystem.exists(path)) return true;
			return FileSystem.exists(Paths.getPath('assets/$filename', TEXT));
			#else
			if(absolute) return Assets.exists(filename);
			return Assets.exists(Paths.getPath('assets/$filename', TEXT));
			#end
		});
		funk.set("saveFile", function(path:String, content:String, ?absolute:Bool = false)
		{
			try {
				#if MODS_ALLOWED
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
				#end
					File.saveContent(path, content);

				return true;
			} catch (e:Dynamic) {
				FunkinLua.luaTrace("saveFile: Error trying to save " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});
		funk.set("deleteFile", function(path:String, ?ignoreModFolders:Bool = false)
		{
			try {
				#if MODS_ALLOWED
				if(!ignoreModFolders)
				{
					var lePath:String = Paths.modFolders(path);
					if(FileSystem.exists(lePath))
					{
						FileSystem.deleteFile(lePath);
						return true;
					}
				}
				#end

				var lePath:String = Paths.getPath(path, TEXT);
				if(Assets.exists(lePath))
				{
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch (e:Dynamic) {
				FunkinLua.luaTrace("deleteFile: Error trying to delete " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});
		funk.set("getTextFromFile", Paths.getTextFromFile);
		funk.set("directoryFileList", function(folder:String) {
			final list:Array<String> = [];
			#if sys
			if(FileSystem.exists(folder))
				for (folder in FileSystem.readDirectory(folder))
					if (!list.contains(folder))
						list.push(folder);
			#end
			return list;
		});

		// String tools
		funk.set("stringStartsWith", StringTools.startsWith);
		funk.set("stringEndsWith",	 StringTools.endsWith);
		funk.set("stringSplit",		 function(s:String, d:String) return s.split(d));
		funk.set("stringTrim",		 StringTools.trim);

		// Randomization
		funk.set("getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '')
			return FlxG.random.int(min, max, [for (ex in exclude.split(',')) Std.parseInt(ex.trim())])
		);
		funk.set("getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '')
			return FlxG.random.float(min, max, [for (ex in exclude.split(',')) Std.parseFloat(ex.trim())])
		);
		funk.set("getRandomBool", FlxG.random.bool);
	}
}