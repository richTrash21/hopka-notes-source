package objects;

import animateatlas.AtlasFrameMaker;

import flixel.util.FlxSort;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end
import openfl.utils.Assets;
import tjson.TJSON as Json;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	@:optional var animflip_x:Bool;
	@:optional var animflip_y:Bool;
}

class Character extends FlxSprite
{
	public static var DEFAULT_CHARACTER(default, null):String = 'bf'; //In case a character is missing, it will use BF on its place

	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = new Map<String, Array<Dynamic>>();
		curCharacter = character;
		this.isPlayer = isPlayer;

		var characterPath:String = 'characters/' + curCharacter + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if(!FileSystem.exists(path)) path = Paths.getPreloadPath(characterPath);

		if(!FileSystem.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if(!Assets.exists(path))
		#end
			path = Paths.getPreloadPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = Assets.getText(path);
		#end

		var json:CharacterFile = cast Json.parse(rawJson);
		var useAtlas:Bool = false;

		#if MODS_ALLOWED
		var modAnimToFind:String = Paths.modFolders('images/' + json.image + '/Animation.json');
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
		useAtlas = (FileSystem.exists(modAnimToFind) || FileSystem.exists(animToFind) || Assets.exists(animToFind));
		#else
		useAtlas = Assets.exists(Paths.getPath('images/' + json.image + '/Animation.json', TEXT));
		#end

		frames = !useAtlas ? Paths.getAtlas(json.image) : AtlasFrameMaker.construct(json.image);

		imageFile = json.image;
		if(json.scale != 1) {
			jsonScale = json.scale;
			setGraphicSize(Std.int(width * jsonScale));
			updateHitbox();
		}

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = json.flip_x;

		if(json.healthbar_colors != null && json.healthbar_colors.length > 2)
			healthColorArray = json.healthbar_colors;

		// antialiasing
		noAntialiasing = json.no_antialiasing;
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if(animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) generateAnim(anim);
		}
		else addAnim('idle', 'BF idle dance', null, 24, false);
		originalFlipX = flipX;

		hasMissAnimations = (animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss'));
		recalculateDanceIdle();
		dance();

		if (isPlayer) flipX = !flipX;
	}

	override function update(elapsed:Float)
	{
		if(!debugMode && animation.curAnim != null)
		{
			if(heyTimer > 0)
			{
				heyTimer -= elapsed * PlayState.instance.playbackRate;
				if(heyTimer <= 0)
				{
					if(specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer')
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			}
			else if(specialAnim && animation.curAnim.finished)
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

			if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1)) * singDuration)
			{
				dance();
				holdTimer = 0;
			}

			if (animation.curAnim.finished && animation.getByName(animation.curAnim.name + '-loop') != null)
				playAnim(animation.curAnim.name + '-loop');
		}
		super.update(elapsed);
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if (danceIdle)
			{
				danced = !danced;
				playAnim('dance' + (danced ? 'Right' : 'Left') + idleSuffix);
			}
			else
				playAnim('idle' + idleSuffix);
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		// if there is no animation named "AnimName" then just skips the whole shit
		if(AnimName == null || animation.getByName(AnimName) == null) {
			FlxG.log.warn("No animation called \"" + AnimName + "\"");
			return;
		}
		animation.play(AnimName, Force, Reversed, Frame);

		if (animOffsets.exists(AnimName)) {
			var daOffset = animOffsets.get(AnimName);
			offset.set(daOffset[0], daOffset[1]);
		} else
			offset.set(0, 0);

		if (curCharacter.startsWith('gf'))
		{
			if (AnimName == 'singLEFT')
				danced = true;
			else if (AnimName == 'singRIGHT')
				danced = false;
			else if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}
	
	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle(){
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

		if (settingCharacterUp)
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		else if (lastDanceIdle != danceIdle)
			danceEveryNumBeats = Math.round(Math.max(danceEveryNumBeats * (danceIdle ? 0.5 : 2), 1));

		settingCharacterUp = false;
	}

	//creates a copy of this character🤯😱
	public function copy():Character {
		var faker:Character = new Character(x, y, curCharacter, isPlayer);
		faker.debugMode = debugMode;
		return faker;
	}

	/**
	 * for reuse in character edditor.
	 * btw stolen from redar13 :3
	 * https://i.imgur.com/P7MDx2C.png
	 */
	public function generateAnim(Anim:AnimArray) {
		if(Anim != null) {
			var animAnim:String = '' + Anim.anim;
			var animName:String = '' + Anim.name;
			var animFps:Int = Anim.fps;
			var animLoop:Bool = Anim.loop;
			var animIndices:Array<Int> = Anim.indices;
			var animFlipX:Bool = Anim.animflip_x;
			var animFlipY:Bool = Anim.animflip_y;
			addAnim(animAnim, animName, animIndices, animFps, animLoop, animFlipX, animFlipY);
			if(Anim.offsets != null && Anim.offsets.length > 1) addOffset(animAnim, Anim.offsets[0], Anim.offsets[1]);
		}
	}

	//quick n' easy animation setup
	public function addAnim(Name:String, Prefix:String, ?Indices:Array<Int>, FrameRate:Int = 24, Looped:Bool = true, FlipX:Bool = false, FlipY:Bool = false) {
		if (Indices != null && Indices.length > 0)
			animation.addByIndices(Name, Prefix, Indices, "", FrameRate, Looped, FlipX, FlipY);
		else
			animation.addByPrefix(Name, Prefix, FrameRate, Looped, FlipX, FlipY);
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
		animOffsets[name] = [x, y];
}
