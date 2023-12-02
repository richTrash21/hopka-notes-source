package objects;

import flixel.animation.FlxAnimation;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;
import flixel.FlxObject;
import flixel.util.FlxSort;

#if MODS_ALLOWED
import sys.FileSystem;
#end
import openfl.utils.Assets;

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

class Character extends objects.ExtendedSprite
{
	inline public static final DEFAULT_CHARACTER:String = 'bf'; //In case a character is missing, it will use BF on its place

	//public var animOffsets:Map<String, Array<Float>> = [];
	public var debugMode:Bool = false;

	public var isPlayer(default, set):Bool;
	public var curCharacter:String;
	@:noCompletion function set_isPlayer(bool:Bool):Bool
	{
		if (isPlayer != bool) flipX = !flipX;
		return isPlayer = bool;
	}

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix(default, set):String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var hasMissAnimations(default, null):Bool = false;

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var originalFlipY:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var camFollow(default, null):FlxObject = new FlxObject(0, 0, 1, 1);
	public var camFollowOffset(default, null):FlxPoint = FlxPoint.get();

	public function new(x:Float, y:Float, ?character:String = DEFAULT_CHARACTER, ?isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super(x, y);
		curCharacter = character;
		
		final characterPath:String = 'characters/$character.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) path = Paths.getPreloadPath(characterPath);

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!Assets.exists(path))
		#end
			path = Paths.getPreloadPath('characters/$DEFAULT_CHARACTER.json'); //If a character couldn't be found, change him to BF just to prevent a crash

		final rawJson = #if MODS_ALLOWED sys.io.File.getContent(path) #else Assets.getText(path) #end;

		final json:CharacterFile = cast haxe.Json.parse(rawJson);
		final img:String = json.image;
		#if MODS_ALLOWED
		final modAnimToFind:String = Paths.modFolders('images/$img/Animation.json');
		final animToFind:String = Paths.getPath('images/$img/Animation.json', TEXT);
		final useAtlas = (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind));
		#else
		final useAtlas = Assets.exists(Paths.getPath('images/$img/Animation.json', TEXT));
		#end

		frames = !useAtlas ? Paths.getAtlas(img, null, allowGPU) : animateatlas.AtlasFrameMaker.construct(img);

		imageFile = img;
		if (json.scale != 1)
		{
			jsonScale = json.scale;
			setGraphicSize(Math.floor(width * jsonScale));
			updateHitbox();
		}

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = json.flip_x;
		flipY = json.flip_y;

		if (json.healthbar_colors != null && json.healthbar_colors.length > 2)
			healthColorArray = json.healthbar_colors;

		// antialiasing
		noAntialiasing = json.no_antialiasing;
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if (animationsArray != null && animationsArray.length > 0)
		{
			for (anim in animationsArray) generateAnim(anim);
		}
		else addAnim('idle', 'BF idle dance', null, 24, false);
		originalFlipX = flipX;
		originalFlipY = flipY;
		this.isPlayer = isPlayer;

		for (name => offset in animOffsets)
			if (name.startsWith('sing') && name.contains('miss'))
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
		if (!debugMode && animation.curAnim != null)
		{
			if (heyTimer > 0)
			{
				// https://github.com/ShadowMario/FNF-PsychEngine/pull/13591 (nvmd replaced with FlxG.animationTimeScale)
				heyTimer -= elapsed * FlxG.animationTimeScale;
				//heyTimer -= elapsed * PlayState.instance.playbackRate;
				if (heyTimer <= 0)
				{
					if (specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer')
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			}
			else if (specialAnim && animation.curAnim.finished)
			{
				specialAnim = false;
				dance();
			}
			else if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
			{
				dance();
				animation.finish();
			}

			if (animation.curAnim.name.startsWith('sing'))
				holdTimer += elapsed;
			else if (isPlayer)
				holdTimer = 0;

			if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
			{
				dance();
				holdTimer = 0;
			}

			if (animation.curAnim.finished && animation.getByName(animation.curAnim.name + '-loop') != null)
				playAnim(animation.curAnim.name + '-loop');
		}
		super.update(elapsed);
		camFollow.update(elapsed); // https://upload.wikimedia.org/wikipedia/ru/c/c2/%D0%A1%D0%B0%D0%BC%D1%8B%D0%B9_%D1%83%D0%BC%D0%BD%D1%8B%D0%B9_%D0%A1%D0%A2%D0%A1.jpg
	}

	#if FLX_DEBUG
	override public function draw()
	{
		super.draw();
		camFollow.draw();
	}
	#end

	var _midPoint:FlxPoint = FlxPoint.get();
	inline public function updateCamFollow()
	{
		getMidpoint(_midPoint);
		camFollow.setPosition(_midPoint.x + (isPlayer ? -cameraPosition[0] : cameraPosition[0]) + camFollowOffset.x, _midPoint.y + cameraPosition[1] + camFollowOffset.y);
	}

	override public function destroy()
	{
		super.destroy();
		_midPoint = FlxDestroyUtil.destroy(_midPoint);
		camFollow = FlxDestroyUtil.destroy(camFollow);
		camFollowOffset = FlxDestroyUtil.put(camFollowOffset);
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(Force:Bool = false)
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if (animation.curAnim != null && animation.curAnim.looped && animation.curAnim.loopPoint > 0 && animation.curAnim.curFrame >= animation.curAnim.loopPoint)
				animation.finish(); // fix for characters that have loopPoint > 0
			var danceAnim:String = 'idle$idleSuffix';
			if (danceIdle)
			{
				danced = !danced;
				danceAnim = 'dance${danced ? 'Right' : 'Left'}$idleSuffix';
			}
			playAnim(danceAnim, Force);
		}
	}

	override public function playAnim(AnimName:String, Force:Bool = false, ?Reversed:Bool = false, ?Frame:Int = 0):Void
	{
		specialAnim = false;
		// if there is no animation named "AnimName" then just skips the whole shit
		if (AnimName == null || !animation.exists(AnimName))
		{
			FlxG.log.warn('No animation called "$AnimName"');
			return;
		}
		animation.play(AnimName, Force, Reversed, Frame);
		
		if (animOffsets.exists(AnimName))
			offset.copyFrom(animOffsets.get(AnimName));
		else
			offset.set();

		if (curCharacter.startsWith('gf') || danceIdle) // idk
			switch (AnimName)
			{
				case 'singLEFT':			 danced = true;
				case 'singRIGHT':			 danced = false;
				case 'singUP' | 'singDOWN':	 danced = !danced;
			}
	}
	
	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle()
	{
		final lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.exists('danceLeft$idleSuffix') && animation.exists('danceRight$idleSuffix'));

		if (settingCharacterUp)
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		else if (lastDanceIdle != danceIdle)
			danceEveryNumBeats = Math.round(Math.max(danceEveryNumBeats * (danceIdle ? 0.5 : 2), 1));

		settingCharacterUp = false;
	}

	@:noCompletion inline function set_idleSuffix(Suffix:String):String
	{
		final prevSuffix = idleSuffix;
		idleSuffix = Suffix;
		if (prevSuffix != Suffix)
			recalculateDanceIdle();

		return Suffix;
	}

	//creates a copy of this character🤯😱
	inline public function copy(?allowGPU:Bool = true):Character
	{
		final faker:Character = new Character(x, y, curCharacter, isPlayer, allowGPU);
		faker.debugMode = debugMode;
		return faker;
	}

	/**
	 * for reuse in character edditor.
	 * btw stolen from redar13 :3
	 * https://i.imgur.com/P7MDx2C.png
	 */
	inline public function generateAnim(Anim:AnimArray)
	{
		if (Anim != null)
		{
			final animAnim:String = '' + Anim.anim;
			final temp:Array<Float> = Anim.offsets;
			final animOffsets:Array<Float> = (temp != null && temp.length > 1) ? temp : [0.0, 0.0];
			addAnim(animAnim, '' + Anim.name, Anim.indices, Anim.fps, Anim.loop, Anim.animflip_x, Anim.animflip_y, Anim.loop_point);
			addOffset(animAnim, animOffsets[0], animOffsets[1]);
		}
	}

	@:noCompletion override inline function set_x(X:Float):Float
	{
		camFollow.x += X - x;
		return x = X;
	}

	@:noCompletion override inline function set_y(Y:Float):Float
	{
		camFollow.y += Y - y;
		return y = Y;
	}

	@:noCompletion override inline function set_width(Width:Float):Float
	{
		#if FLX_DEBUG
		if (Width < 0)
		{
			FlxG.log.warn("An object's width cannot be smaller than 0. Use offset for sprites to control the hitbox position!");
			return Width;
		}
		#end
		camFollow.x += (width - Width) * 0.5;
		return width = Width;
	}

	@:noCompletion override inline function set_height(Height:Float):Float
	{
		#if FLX_DEBUG
		if (Height < 0)
		{
			FlxG.log.warn("An object's height cannot be smaller than 0. Use offset for sprites to control the hitbox position!");
			return Height;
		}
		#end
		camFollow.y += (height - Height) * 0.5;
		return height = Height;
	}
}
