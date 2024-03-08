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
	inline public static final DEFAULT_CHARACTER = "bf"; // In case a character is missing, it will use BF on its place

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

	public var hasMissAnimations(default, null):Bool;
	public var animationsArray:Array<AnimArray>;
	public var isPlayer(default, set):Bool;
	public var curCharacter:String;

	// public var colorTween:FlxTween;
	public var holdTimer:Float;
	public var heyTimer:Float;
	public var specialAnim:Bool;
	public var stunned:Bool;
	public var singDuration:Float; // Multiplier of how long a character holds the sing pose
	public var idleSuffix(default, set):String;
	public var danceIdle:Bool; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool;

	public var healthIcon:String = "face";
	public var healthColor:FlxColor = FlxColor.RED;

	public var camFollow(default, null):FlxObject = new FlxObject(0, 0, 1, 1);
	public var cameraOffset:FlxPoint = FlxPoint.get();
	public var position:FlxPoint = FlxPoint.get();

	// Used on Character Editor
	var imageFile:String;
	var jsonScale:Float;
	var noAntialiasing:Bool;
	var originalFlipX:Bool;
	var originalFlipY:Bool;

	@:allow(states.PlayState)
	var camFollowOffset(default, null):FlxPoint;
	var debugMode:Bool;
	var firstSetup = true;

	// DEPRECATED!!!!!
	public var positionArray(get, set):Array<Float>;
	public var cameraPosition(get, set):Array<Float>;
	public var healthColorArray(get, set):Array<Int>;

	public function new(?x = 0., ?y = 0., character:String, isPlayer = false, ?allowGPU = true)
	{
		super(x, y);
		camFollowOffset = new FlxCallbackPoint(updateCamFollow);
		// curCharacter = character;

		loadCharacter(character, allowGPU);
		this.isPlayer = isPlayer;
		firstSetup = false;
	}

	public function loadCharacter(data:CharacterData, ?gpu = false)
	{
		final json = resolveCharacterData(data);
		if (!debugMode && imageFile == json.image)
			return;

		// remove old positioning
		subtractPosition(position.x, position.y);

		// reset data
		curCharacter = data is String ? data : "unknown";
		hasMissAnimations = specialAnim = skipDance = danceIdle = stunned = false;
		settingCharacterUp = true;
		holdTimer = heyTimer = 0;
		singDuration = 4;
		@:bypassAccessor idleSuffix = "";

		final oldAnim = animation.curAnim?.name;
		final oldFrame = animation.curAnim?.curFrame ?? 0;
		final wasPlayer = isPlayer;
		if (!firstSetup)
			isPlayer = false;

		while (animationsArray?.length > 0)
			animationsArray.pop();

		// load spritesheet
		imageFile = json.image;
		#if MODS_ALLOWED
		final modAnimToFind = Paths.modFolders('images/$imageFile/Animation.json');
		final animToFind = Paths.getPath('images/$imageFile/Animation.json', TEXT);
		final useAtlas = (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind));
		#else
		final useAtlas = Assets.exists(Paths.getPath('images/$imageFile/Animation.json', TEXT));
		#end

		frames = useAtlas ? animateatlas.AtlasFrameMaker.construct(imageFile) : Paths.getAtlas(imageFile, gpu);

		// scale sprite
		jsonScale = json.scale;
		setScale(jsonScale);
		updateHitbox();

		// positioning
		cameraOffset.set(json.camera_position[0], json.camera_position[1]);
		position.set(json.position[0], json.position[1]);
		// add new position
		addPosition(position.x, position.y);

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
		if (animationsArray?.length > 0)
			for (anim in animationsArray)
				generateAnim(anim);
		else
			addAnim("idle", "BF idle dance", 24, false);

		originalFlipX = flipX;
		originalFlipY = flipY;

		for (name => offset in animOffsets)
			if (name.startsWith("sing") && name.contains("miss"))
			{
				hasMissAnimations = true;
				break;
			}

		if (!firstSetup)
			isPlayer = wasPlayer;

		recalculateDanceIdle();
		updateCamFollow();

		if (debugMode || oldAnim == null || !animExists(oldAnim))
			dance();
		else
			playAnim(oldAnim, oldFrame);
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
		while (animationsArray?.length > 0)
			animationsArray.pop();

		animationsArray = null;

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

		playAnim((danceIdle ? "dance" + ((danced = !danced) ? "Right" : "Left") : "idle") + idleSuffix, force);
	}

	override public function playAnim(animName:String, force = false, ?reversed = false, ?frame = 0):Void
	{
		specialAnim = false;
		if (animName == null || !animExists(animName))
		{
			final txt = 'No animation called "$animName"';
			return #if debug FlxG.log.warn(txt) #else trace(txt) #end;
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
		danceIdle = (animExists('danceLeft$idleSuffix') && animExists('danceRight$idleSuffix'));

		if (settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
			settingCharacterUp = false;
		}
		else if (lastDanceIdle != danceIdle)
			danceEveryNumBeats = Math.round(Math.max(danceEveryNumBeats * (danceIdle ? 0.5 : 2), 1));
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
		while (activeList.length > 0)
			diactivate(activeList.pop());

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
