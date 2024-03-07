package objects;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import flixel.FlxObject;

#if MODS_ALLOWED
import sys.FileSystem;
#end
import openfl.utils.Assets;

@:allow(states.editors.CharacterEditorState)
class Character extends objects.ExtendedSprite
{
	inline public static final DEFAULT_CHARACTER = "bf"; //In case a character is missing, it will use BF on its place

	public static function resolveCharacterData(data:CharacterData):CharacterFile
	{
		// from character name
		if (data is String)
		{
			var path:String;
			final characterPath = 'characters/$data.json';
			#if MODS_ALLOWED
			path = Paths.modFolders(characterPath);
			if (!FileSystem.exists(path))
				path = Paths.getPreloadPath(characterPath);
	
			if (!FileSystem.exists(path))
			#else
			path = Paths.getPreloadPath(characterPath);
			if (!Assets.exists(path))
			#end
				path = Paths.getPreloadPath('characters/$DEFAULT_CHARACTER.json'); // If a character couldn't be found, change him to BF just to prevent a crash
	
			return cast haxe.Json.parse(#if MODS_ALLOWED sys.io.File.getContent(path) #else Assets.getText(path) #end);	
		}
		// nvmd just standart character file data
		return cast data;
	}

	public var hasMissAnimations(default, null):Bool = false;
	public var animationsArray:Array<AnimArray> = [];
	public var isPlayer(default, set):Bool;
	public var curCharacter:String;

	// public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix(default, set):String = "";
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = "face";
	public var healthColor:FlxColor = FlxColor.RED;

	public var camFollow(default, null):FlxObject = new FlxObject(0, 0, 1, 1);
	public var cameraOffset:FlxPoint = FlxPoint.get();
	public var position:FlxPoint = FlxPoint.get();

	// Used on Character Editor
	var imageFile = "";
	var jsonScale = 1.;
	var noAntialiasing = false;
	var originalFlipX = false;
	var originalFlipY = false;

	@:allow(states.PlayState)
	var camFollowOffset(default, null):FlxPoint;
	var debugMode = false;

	// DEPRECATED!!!!!
	public var positionArray(get, set):Array<Float>;
	public var cameraPosition(get, set):Array<Float>;
	public var healthColorArray(get, set):Array<Int>;

	public function new(x:Float, y:Float, ?character = DEFAULT_CHARACTER, ?isPlayer = false, ?allowGPU = true)
	{
		super(x, y);
		camFollowOffset = new FlxCallbackPoint(updateCamFollow);
		curCharacter = character;

		loadCharacter(character, allowGPU);
		this.isPlayer = isPlayer;
	}

	public function loadCharacter(data:CharacterData, ?gpu = false)
	{
		final json = resolveCharacterData(data);
		settingCharacterUp = true;

		specialAnim = stunned = danceIdle = skipDance = false;
		holdTimer = heyTimer = 0;
		singDuration = 4;
		idleSuffix = "";

		final img = json.image;
		#if MODS_ALLOWED
		final modAnimToFind = Paths.modFolders('images/$img/Animation.json');
		final animToFind = Paths.getPath('images/$img/Animation.json', TEXT);
		final useAtlas = (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind));
		#else
		final useAtlas = Assets.exists(Paths.getPath('images/$img/Animation.json', TEXT));
		#end

		frames = useAtlas ? animateatlas.AtlasFrameMaker.construct(img) : Paths.getAtlas(img, null, gpu);

		imageFile = img;
		// if (json.scale != 1)
		// {
		jsonScale = json.scale;
		// setGraphicSize(width * jsonScale);
		setScale(jsonScale);
		updateHitbox();
		// }

		// positioning
		position.set(json.position[0], json.position[1]);
		cameraOffset.set(json.camera_position[0], json.camera_position[1]);

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = json.flip_x;
		flipY = json.flip_y;

		if (json.healthbar_colors?.length > 2)
			healthColor = FlxColor.fromRGB(json.healthbar_colors[0], json.healthbar_colors[1], json.healthbar_colors[2]);

		// antialiasing
		noAntialiasing = json.no_antialiasing;
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if (animationsArray?.length == 0)
			addAnim("idle", "BF idle dance", null, 24, false);
		else
			for (anim in animationsArray)
				generateAnim(anim);

		originalFlipX = flipX;
		originalFlipY = flipY;

		hasMissAnimations = false;
		for (name => offset in animOffsets)
			if (name.startsWith("sing") && name.contains("miss"))
			{
				hasMissAnimations = true;
				break;
			}

		recalculateDanceIdle();
		updateCamFollow();
		dance();
	}

	override public function update(elapsed:Float)
	{
		if (debugMode || animation.curAnim == null)
		{
			super.update(elapsed);
			camFollow.update(elapsed); // https://upload.wikimedia.org/wikipedia/ru/c/c2/%D0%A1%D0%B0%D0%BC%D1%8B%D0%B9_%D1%83%D0%BC%D0%BD%D1%8B%D0%B9_%D0%A1%D0%A2%D0%A1.jpg
			return;
		}

		if (heyTimer > 0)
		{
			// https://github.com/ShadowMario/FNF-PsychEngine/pull/13591 (nvmd replaced with FlxG.animationTimeScale)
			if ((heyTimer -= elapsed * FlxG.animationTimeScale) <= 0)
			{
				if (specialAnim && animation.curAnim.name == "hey" || animation.curAnim.name == "cheer")
				{
					specialAnim = false;
					dance();
				}
				// heyTimer = 0;
			}
		}
		else if (specialAnim && animation.curAnim.finished)
		{
			specialAnim = false;
			dance();
		}
		else if (animation.curAnim.name.endsWith("miss") && animation.curAnim.finished)
		{
			dance();
			animation.finish();
		}

		if (animation.curAnim.name.startsWith("sing"))
			holdTimer += elapsed;
		else if (isPlayer)
			holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music == null ? 1 : FlxG.sound.music.pitch) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		if (animation.curAnim.finished && animation.exists(animation.curAnim.name + "-loop"))
			playAnim(animation.curAnim.name + "-loop");

		super.update(elapsed);
		camFollow.update(elapsed);
	}

	#if FLX_DEBUG
	override public function draw()
	{
		super.draw();
		camFollow.draw();
	}
	#end

	var __midpoint = FlxPoint.get();
	/*inline*/ public function updateCamFollow(?_:FlxPoint)
	{
		getMidpoint(__midpoint);
		camFollow.setPosition(
			__midpoint.x + (isPlayer ? -cameraOffset.x : cameraOffset.x) + camFollowOffset.x,
			__midpoint.y + cameraOffset.y + camFollowOffset.y
		);
	}

	override public function destroy()
	{
		super.destroy();
		camFollowOffset = FlxDestroyUtil.destroy(camFollowOffset);
		camFollow = FlxDestroyUtil.destroy(camFollow);

		cameraOffset = FlxDestroyUtil.put(cameraOffset);
		__midpoint = FlxDestroyUtil.put(__midpoint);
		position = FlxDestroyUtil.put(position);
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(force = false)
	{
		if (debugMode || skipDance || specialAnim)
			return;

		if (animation.curAnim != null && animation.curAnim.looped && animation.curAnim.loopPoint > 0 && animation.curAnim.curFrame >= animation.curAnim.loopPoint)
			animation.finish(); // fix for characters that have loopPoint > 0

		var danceAnim = 'idle$idleSuffix';
		if (danceIdle)
		{
			danced = !danced;
			danceAnim = "dance" + (danced ? "Right" : "Left") + idleSuffix;
		}
		playAnim(danceAnim, force);
	}

	override public function playAnim(animName:String, force = false, ?reversed = false, ?frame = 0):Void
	{
		specialAnim = false;
		// if there is no animation named "animName" then just skips the whole shit
		if (animName == null || !animation.exists(animName))
		{
			FlxG.log.warn('No animation called "$animName"');
			return;
		}
		animation.play(animName, force, reversed, frame);

		if (curCharacter.startsWith("gf") || danceIdle) // idk
			switch (animName)
			{
				case "singLEFT":			 danced = true;
				case "singRIGHT":			 danced = false;
				case "singUP" | "singDOWN":	 danced = !danced;
			}
	}

	var settingCharacterUp = true;
	public var danceEveryNumBeats:Int = 2;

	public function recalculateDanceIdle()
	{
		final lastDanceIdle = danceIdle;
		danceIdle = (animation.exists('danceLeft$idleSuffix') && animation.exists('danceRight$idleSuffix'));

		if (settingCharacterUp)
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		else if (lastDanceIdle != danceIdle)
			danceEveryNumBeats = Math.round(Math.max(danceEveryNumBeats * (danceIdle ? 0.5 : 2), 1));

		settingCharacterUp = false;
	}

	// creates a copy of this character🤯😱
	/*inline public function copy(?allowGPU:Bool = true):Character
	{
		final faker:Character = new Character(x, y, curCharacter, isPlayer, allowGPU);
		faker.debugMode = debugMode;
		return faker;
	}*/

	/**
	 * for reuse in character edditor.
	 * btw stolen from redar13 :3
	 * https://i.imgur.com/P7MDx2C.png
	 */
	inline public function generateAnim(data:AnimArray)
	{
		if (data == null)
			return;

		final animAnim = "" + data.anim;
		final animOffsets = (data.offsets?.length < 2) ? [0.0, 0.0] : data.offsets;
		addAnim(animAnim, "" + data.name, data.indices, data.fps, data.loop, data.animflip_x, data.animflip_y, data.loop_point);
		addOffset(animAnim, animOffsets[0], animOffsets[1]);
	}

	@:noCompletion inline function set_idleSuffix(value:String):String
	{
		final prevSuffix = idleSuffix;
		idleSuffix = value;
		if (prevSuffix != value)
			recalculateDanceIdle();

		return value;
	}

	@:noCompletion inline function set_isPlayer(value:Bool):Bool
	{
		if (isPlayer != value)
			flipX = !flipX;

		return isPlayer = value;
	}

	@:noCompletion override inline function set_x(value:Float):Float
	{
		camFollow.x += value - x;
		return x = value;
	}

	@:noCompletion override inline function set_y(value:Float):Float
	{
		camFollow.y += value - y;
		return y = value;
	}

	@:noCompletion override inline function set_width(value:Float):Float
	{
		#if FLX_DEBUG
		if (value < 0)
		{
			FlxG.log.warn("An object's width cannot be smaller than 0. Use offset for sprites to control the hitbox position!");
			return value;
		}
		#end
		camFollow.x += (width - value) * 0.5;
		return width = value;
	}

	@:noCompletion override inline function set_height(value:Float):Float
	{
		#if FLX_DEBUG
		if (value < 0)
		{
			FlxG.log.warn("An object's height cannot be smaller than 0. Use offset for sprites to control the hitbox position!");
			return value;
		}
		#end
		camFollow.y += (height - value) * 0.5;
		return height = value;
	}

	@:noCompletion inline function get_healthColorArray():Array<Int>
	{
		return [healthColor.red, healthColor.green, healthColor.blue];
	}

	@:noCompletion inline function set_healthColorArray(value:Array<Int>):Array<Int>
	{
		healthColor = FlxColor.fromRGB(value[0], value[1], value[2]);
		return value;
	}

	@:noCompletion inline function get_positionArray():Array<Float>
	{
		return [position.x, position.y];
	}

	@:noCompletion inline function set_positionArray(value:Array<Float>):Array<Float>
	{
		if (value != null)
		{
			position.x = value[0];
			if (value.length > 1)
				position.y = value[1];
		}
		return value;
	}

	@:noCompletion inline function get_cameraPosition():Array<Float>
	{
		return [cameraOffset.x, cameraOffset.y];
	}

	@:noCompletion inline function set_cameraPosition(value:Array<Float>):Array<Float>
	{
		if (value != null)
		{
			cameraOffset.x = value[0];
			if (value.length > 1)
				cameraOffset.y = value[1];
		}
		return value;
	}
}

typedef CharacterData = haxe.extern.EitherType<String, CharacterFile>;

typedef CharacterFile = {
	animations:Array<AnimArray>,
	image:String,
	scale:Float,
	sing_duration:Float,
	healthicon:String,

	position:Array<Float>,
	camera_position:Array<Float>,

	flip_x:Bool,
	flip_y:Bool,
	no_antialiasing:Bool,
	healthbar_colors:Array<Int>
}

typedef AnimArray = {
	anim:String,
	name:String,
	fps:Int,
	loop:Bool,
	loop_point:Int,
	indices:Array<Int>,
	offsets:Array<Float>,
	animflip_x:Bool,
	animflip_y:Bool
}

/**
	A group that stores a bunch of idiots (привет Алик!!). 
**/
class CharacterGroup extends FlxTypedSpriteGroup<Character>
{
	/**
		So every character can have a unique string key through which they can be pulled.
	**/
	public var membersMap(default, null):Map<String, Character>;

	/**
		List of active characters that can be used in game.
	**/
	public var activeList(default, null):Array<Character>;

	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);
		membersMap = [];
		activeList = [];
	}

	public function setActiveByKey(Keys:Array<String>)
	{
		var char:Character = null;
		while (activeList.length > 0)
		{
			char = activeList.pop();
			diactivate(char);
		}

		for (key in Keys)
			addActiveByKey(key);
	}

	public function addActiveByKey(Key:String)
	{
		if (membersMap.exists(Key))
			activeList.push(membersMap.get(Key));
	}

	inline function diactivate(char:Character):Character
	{
		char.alpha = 0.00001;
		char.active = false; // for optimisation!!
		return char;
	}

	inline function activate(char:Character):Character
	{
		char.alpha = 1;
		char.active = true;
		return char;
	}
}
