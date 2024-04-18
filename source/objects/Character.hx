package objects;

import flixel.util.FlxDestroyUtil;

#if MODS_ALLOWED
import sys.FileSystem;
#end
import openfl.utils.Assets;

@:allow(states.editors.CharacterEditorState)
class Character extends objects.ExtendedSprite
{
	inline public static final DEFAULT_CHARACTER = "bf"; // In case a character is missing, it will use BF on its place
	inline public static final UNKNOWN_CHARACTER = "__unknown__character__";
	public static final jsonCache = new Map<String, CharacterFile>();

	public static function resolveCharacterData(data:CharacterData, ?useCache = true):CharacterFile
	{
		// from character name
		if (data is String)
		{
			final name = cast (data, String);
			if (useCache && jsonCache.exists(name))
				return jsonCache.get(name);

			var path:String;
			final characterPath = 'characters/$name.json';
			#if MODS_ALLOWED
			path = Paths.modFolders(characterPath);
			if (!FileSystem.exists(path))
			#end
				path = Paths.getSharedPath(characterPath);

			if (#if MODS_ALLOWED !FileSystem.exists(path) #else !Assets.exists(path) #end)
				path = Paths.getSharedPath('characters/$DEFAULT_CHARACTER.json'); // If a character couldn't be found, change him to BF just to prevent a crash
	
			final json:CharacterFile = cast haxe.Json.parse(#if MODS_ALLOWED sys.io.File.getContent(path) #else Assets.getText(path) #end);
			if (useCache)
				jsonCache.set(name, json);
			return json;
		}
		// nvmd just standart character file data
		return cast data;
	}

	public var hasMissAnimations(default, null):Bool;
	public var animationsArray:Array<AnimArray>;
	public var isPlayer(default, set):Bool;
	public var curCharacter(default, null):String;

	public var holdTimer:Float;
	public var heyTimer:Float;
	public var specialAnim:Bool;
	public var stunned:Bool;
	public var singDuration:Float; // Multiplier of how long a character holds the sing pose
	public var idleSuffix(default, set):String;
	public var danceIdle:Bool; // Character use "dance" instead of "idle"
	public var maxDance(default, null):Int;
	public var skipDance:Bool;

	public var healthIcon:String = "face";
	public var healthColor:FlxColor = FlxColor.RED;

	public var camFollow(default, null) = new CameraTarget();
	public var cameraOffset = FlxPoint.get();
	public var position = FlxPoint.get();

	public var danceEveryNumBeats:Int = 2;
	public var danced:Bool;

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
	var settingCharacterUp = true;
	var curDance = -1;

	// DEPRECATED!!!!!
	public var positionArray(get, set):Array<Float>;
	public var cameraPosition(get, set):Array<Float>;
	public var healthColorArray(get, set):Array<Int>;

	public function new(?x = 0., ?y = 0., character:String, isPlayer = false, ?allowGPU = true, ?useCache = true)
	{
		super(x, y);
		camFollowOffset = new FlxCallbackPoint(updateCamFollow);
		// curCharacter = character;

		loadCharacter(character, allowGPU, useCache);
		this.isPlayer = isPlayer;
		firstSetup = false;
	}

	public function loadCharacter(data:CharacterData, ?gpu = true, ?useCache = true)
	{
		final name = data is String ? cast (data, String) : UNKNOWN_CHARACTER;
		if (!debugMode && name == curCharacter)
			return;

		final json = resolveCharacterData(data, useCache);

		// remove old positioning
		subtractPosition(position.x, position.y);

		// reset data
		curCharacter = name;
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

		// load spritesheet
		imageFile = json.image;
		#if MODS_ALLOWED
		final modAnimToFind = Paths.modFolders('images/$imageFile/Animation.json');
		#end
		final animToFind = Paths.getPath('images/$imageFile/Animation.json', TEXT);
		final useAtlas = (#if MODS_ALLOWED FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) #else Assets.exists(animToFind) #end);
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
		antialiasing = ClientPrefs.data.antialiasing && !(noAntialiasing = json.no_antialiasing);

		// animations
		animationsArray = json.animations;
		if (animationsArray != null && animationsArray.length != 0)
			for (anim in animationsArray)
				generateAnim(anim);
		else
			addAnim("idle", "BF idle dance", 24, false);

		originalFlipX = flipX;
		originalFlipY = flipY;

		if (!firstSetup)
			isPlayer = wasPlayer;

		recalculateDanceIdle();
		updateCamFollow();

		if (debugMode || oldAnim == null || !animation.exists(oldAnim))
			dance();
		else
			playAnim(oldAnim, oldFrame);
	}

	override public function update(elapsed:Float)
	{
		if (debugMode || animation.curAnim == null)
		{
			super.update(elapsed);
			#if FLX_DEBUG
			// https://upload.wikimedia.org/wikipedia/ru/c/c2/%D0%A1%D0%B0%D0%BC%D1%8B%D0%B9_%D1%83%D0%BC%D0%BD%D1%8B%D0%B9_%D0%A1%D0%A2%D0%A1.jpg
			if (camFollow.active && camFollow.exists)
				camFollow.update(elapsed);
			#end
			return;
		}

		if (heyTimer > 0.0)
		{
			if ((heyTimer -= elapsed * FlxG.animationTimeScale) <= 0.0)
				if (specialAnim && animation.curAnim.name == "hey" || animation.curAnim.name == "cheer")
				{
					specialAnim = false;
					dance();
				}
		}
		else if (specialAnim && animation.curAnim.finished)
		{
			specialAnim = false;
			dance();
		}

		if (animation.curAnim.name.startsWith("sing"))
			holdTimer += elapsed;
		else if (isPlayer)
			holdTimer = 0.0;

		final maxTimer = __calc__hold__timer();
		final missAnim = animation.curAnim.name.endsWith("miss");
		if ((!isPlayer || missAnim) && holdTimer >= maxTimer)
		{
			dance();
			if (missAnim)
				animation.finish();
			holdTimer -= maxTimer;
		}

		if (animation.curAnim.finished && animation.exists(animation.curAnim.name + "-loop"))
			playAnim(animation.curAnim.name + "-loop");

		super.update(elapsed);
		#if FLX_DEBUG
		if (camFollow.active && camFollow.exists)
			camFollow.update(elapsed);
		#end
	}

	#if FLX_DEBUG
	override public function draw()
	{
		super.draw();
		if (camFollow.visible && camFollow.exists)
			camFollow.draw();
	}
	#end

	var __midpoint = FlxPoint.get();
	public function updateCamFollow(?_)
	{
		getMidpoint(__midpoint);
		camFollow.setPosition(
			__midpoint.x + (isPlayer ? -cameraOffset.x : cameraOffset.x) + camFollowOffset.x,
			__midpoint.y + cameraOffset.y + camFollowOffset.y
		);
	}

	override public function destroy()
	{
		animationsArray = null;
		camFollowOffset = FlxDestroyUtil.destroy(camFollowOffset);
		camFollow = FlxDestroyUtil.destroy(camFollow);
		cameraOffset = FlxDestroyUtil.put(cameraOffset);
		__midpoint = FlxDestroyUtil.put(__midpoint);
		position = FlxDestroyUtil.put(position);
		super.destroy();
	}

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(force = false)
	{
		if (debugMode || skipDance || specialAnim)
			return;

		if (animation.curAnim != null && animation.curAnim.looped && animation.curAnim.loopPoint != 0 && animation.curAnim.curFrame >= animation.curAnim.loopPoint)
			animation.finish(); // fix for characters that have loopPoint > 0

		var a = "idle";
		if (danceIdle)
		{
			a = "dance";
			if (maxDance == -1)
			{
				if (danced = !danced)
				{
					a += "Right";
					curDance = 1;
				}
				else
				{
					a += "Left";
					curDance = 0;
				}
			}
			else
			{
				a += (curDance = ++curDance % maxDance);
				danced = FlxMath.isOdd(curDance);
			}
		}
		playAnim(a + idleSuffix, force);
	}

	override public function playAnim(animName:String, force = false, reversed = false, frame = 0):Void
	{
		specialAnim = false;
		if (animName.startsWith("sing"))
			holdTimer = 0.0;

		if (animName == null || !animation.exists(animName))
			return Main.warn('No animation called "$animName", for character "$curCharacter"');

		animation.play(animName, force, reversed, frame);
		if (curCharacter.startsWith("gf") || (danceIdle && maxDance == -1)) // idk
			switch (animName)
			{
				case "singLEFT":			 danced = true;
				case "singRIGHT":			 danced = false;
				case "singUP" | "singDOWN":	 danced = !danced;
			}
	}

	public function recalculateDanceIdle()
	{
		final lastDanceIdle = danceIdle;

		if (animation.exists('dance0$idleSuffix')) // new (numbered) dance anims (stolen from twist engine ehehehe) - rich >:3
		{
			maxDance = 0;
			while (animation.exists("dance" + ++maxDance + idleSuffix)) { /*aaaaaand it does nothing*/ }
		}
		else
			maxDance = -1;

		danceIdle = (maxDance > 1 || animation.exists('danceLeft$idleSuffix') && animation.exists('danceRight$idleSuffix'));

		if (settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
			settingCharacterUp = false;
		}
		else if (lastDanceIdle != danceIdle)
			danceEveryNumBeats = FlxMath.maxInt(danceIdle ? Math.round(danceEveryNumBeats * 0.5) : (danceEveryNumBeats * 2), 1);
	}

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
		final animOffsets = (data.offsets == null || data.offsets.length < 2) ? [0.0, 0.0] : data.offsets;
		addAnim(animAnim, "" + data.name, data.indices, data.fps, data.loop, data.animflip_x, data.animflip_y, data.loop_point);
		addOffset(animAnim, animOffsets[0], animOffsets[1]);

		if (!hasMissAnimations && animAnim.startsWith("sing") && animAnim.contains("miss"))
			hasMissAnimations = true;
	}

	@:allow(states.PlayState)
	@:noCompletion extern inline function __calc__hold__timer():Float
	{
		return Conductor.stepCrochet * (#if FLX_PITCH FlxG.sound.music != null ? 0.0011 / FlxG.sound.music.pitch : #end 0.0011) * singDuration;
	}

	@:noCompletion function set_idleSuffix(value:String):String
	{
		if (idleSuffix != value)
		{
			idleSuffix = value;
			recalculateDanceIdle();
		}
		return value;
	}

	@:noCompletion function set_isPlayer(value:Bool):Bool
	{
		if (isPlayer != value)
			flipX = !flipX;

		return isPlayer = value;
	}

	@:noCompletion override function set_x(value:Float):Float
	{
		camFollow.x += value - x;
		return x = value;
	}

	@:noCompletion override function set_y(value:Float):Float
	{
		camFollow.y += value - y;
		return y = value;
	}

	@:noCompletion override function set_width(value:Float):Float
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

	@:noCompletion override function set_height(value:Float):Float
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
		if (value != null)
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
			position.set(value[0], value[1]);

		return value;
	}

	@:noCompletion inline function get_cameraPosition():Array<Float>
	{
		return [cameraOffset.x, cameraOffset.y];
	}

	@:noCompletion inline function set_cameraPosition(value:Array<Float>):Array<Float>
	{
		if (value != null)
			cameraOffset.set(value[0], value[1]);

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
