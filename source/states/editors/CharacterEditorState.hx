package states.editors;

import flixel.util.FlxStringUtil;
import flixel.input.mouse.FlxMouseEventManager;
import flixel.FlxObject;

import flixel.animation.FlxAnimation;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUITabMenu;
import flixel.math.FlxPoint;
import flixel.ui.FlxButton;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import haxe.Json;

import objects.ui.UIInputTextAdvanced;
import objects.ui.DropDownAdvanced;
import objects.Character;
import objects.HealthIcon;
import objects.Bar;

import backend.MusicBeatUIState;

#if MODS_ALLOWED
import sys.FileSystem;
#end

class CharacterEditorState extends backend.MusicBeatUIState
{
	#if !RELESE_BUILD_FR
	var char:Character;
	var ghostChar:Character;
	var textAnim:FlxText;
	var charLayer:FlxTypedGroup<Character>;
	var dumbTexts:FlxTypedGroup<FlxText>;
	var curAnim:Int = 0;
	var daAnim:String = 'spooky';
	var goToPlayState:Bool = true;
	var camFollow:FlxObject;

	public function new(daAnim:String = 'spooky', goToPlayState:Bool = true)
	{
		super();
		this.daAnim = daAnim;
		this.goToPlayState = goToPlayState;
	}

	var UI_box:FlxUITabMenu;
	var UI_characterbox:FlxUITabMenu;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;
	private var camMenu:FlxCamera;

	var leHealthIcon:HealthIcon;
	var characterList:Array<String> = [];

	var cameraFollowPointer:FlxSprite;
	var healthBar:Bar;

	var bg:BGSprite;
	var stageFront:BGSprite;

	var mouseManager:FlxMouseEventManager;

	override function create()
	{
		FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), 0.4);
		if(ClientPrefs.data.cacheOnGPU) Paths.clearStoredMemory();

		camEditor = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camMenu = new FlxCamera();
		camMenu.bgColor.alpha = 0;

		FlxG.cameras.reset(camEditor);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camMenu, false);
		FlxG.cameras.setDefaultDrawTarget(camEditor, true);

		// fuck pixel bg nobody used it anyway
		var prevLevel:String = Paths.currentLevel;
		Paths.setCurrentLevel('week1');
		bg = new BGSprite('stageback', -600 + OFFSET_X, -300, 0.9, 0.9);
		add(bg);

		stageFront = new BGSprite('stagefront', -650 + OFFSET_X, 500);
		stageFront.setGraphicSize(Math.floor(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);
		Paths.setCurrentLevel(prevLevel);

		charLayer = new FlxTypedGroup<Character>();
		add(charLayer);

		cameraFollowPointer = new FlxSprite(0, 0, flixel.graphics.FlxGraphic.fromClass(flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross));
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		add(cameraFollowPointer);

		loadChar(!daAnim.startsWith('bf'), false);

		healthBar = new Bar(30, FlxG.height - 75);
		//healthBar.scrollFactor.set();
		add(healthBar);
		healthBar.cameras = [camHUD];
		
		if(ClientPrefs.data.cacheOnGPU) Paths.clearUnusedMemory();

		leHealthIcon = new HealthIcon(char.healthIcon, false, false);
		//leHealthIcon.scrollFactor.set(1, 1);
		leHealthIcon.y = FlxG.height - 150;
		add(leHealthIcon);
		leHealthIcon.cameras = [camHUD];

		mouseManager = new FlxMouseEventManager();
		mouseManager.add(leHealthIcon, function(icon:HealthIcon) {
			var anim = icon.animation.curAnim;
			anim.curFrame = FlxMath.wrap(anim.curFrame + 1, 0, anim.numFrames-1);
			icon.scale.set(0.975 * icon.baseScale, 0.975 * icon.baseScale);
		}, function(icon:HealthIcon) icon.scale.set(icon.baseScale, icon.baseScale));
		add(mouseManager);
		//mouseManager.cameras = [camHUD];

		dumbTexts = new FlxTypedGroup<FlxText>();
		add(dumbTexts);
		dumbTexts.cameras = [camHUD];

		textAnim = new FlxText(300, 16);
		textAnim.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		textAnim.borderSize = 1;
		//textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);

		genBoyOffsets();

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);

		var tipTextArray:String = "
		Tab - Switch HUD visibility
		E/Q - Camera Zoom In/Out
		R - Reset Camera Zoom
		JKLI - Move Camera
		W/S - Previous/Next Animation
		Space - Play Animation
		Arrow Keys - Move Character Offset
		T - Reset Current Offset
		Hold Shift to Move 10x faster";

		var tipText:FlxText = new FlxText(FlxG.width - 360, FlxG.height - 330, 340, tipTextArray, 12);
		tipText.setFormat(null, 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		tipText.cameras = [camHUD];
		tipText.borderSize = 1;
		add(tipText);

		FlxG.camera.follow(camFollow);

		UI_box = new FlxUITabMenu(null, [{name: 'Settings', label: 'Settings'}], true);
		UI_box.cameras = [camMenu];

		UI_box.resize(250, 120);
		UI_box.x = FlxG.width - 275;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		UI_characterbox = new FlxUITabMenu(null, [
			{name: 'Character', label: 'Character'},
			{name: 'Animations', label: 'Animations'}
		], true);
		UI_characterbox.cameras = [camMenu];

		UI_characterbox.resize(350, 250);
		UI_characterbox.x = UI_box.x - 100;
		UI_characterbox.y = UI_box.y + UI_box.height;
		UI_characterbox.scrollFactor.set();
		add(UI_characterbox);
		add(UI_box);

		//addOffsetsUI();
		addSettingsUI();

		addCharacterUI();
		addAnimationsUI();
		UI_characterbox.selected_tab_id = 'Character';

		FlxG.mouse.visible = true;
		reloadCharacterOptions();

		super.create();
	}

	var OFFSET_X:Float = 300;
	function reloadBGs() {
		var playerXDifference = char.isPlayer ? 670 : 0;
		bg.x = -600 + OFFSET_X - playerXDifference;
		stageFront.x = -650 + OFFSET_X - playerXDifference;
	}

	final TemplateCharacter:String = '{
			"animations": [
				{
					"anim": "idle",
					"name": "Dad idle dance",
					"loop": false,
					"loop_point": 0,
					"offsets": [0, 0],
					"fps": 24,
					"indices": [],
					"animflip_x": false,
					"animflip_y": false
				},
				{
					"anim": "singLEFT",
					"name": "Dad Sing Note LEFT",
					"loop": false,
					"loop_point": 0,
					"offsets": [0, 0],
					"fps": 24,
					"indices": [],
					"animflip_x": false,
					"animflip_y": false
				},
				{
					"anim": "singDOWN",
					"name": "Dad Sing Note DOWN",
					"loop": false,
					"loop_point": 0,
					"offsets": [0, 0],
					"fps": 24,
					"indices": [],
					"animflip_x": false,
					"animflip_y": false
				},
				{
					"anim": "singUP",
					"name": "Dad Sing Note UP",
					"loop": false,
					"loop_point": 0,
					"offsets": [0, 0],
					"fps": 24,
					"indices": [],
					"animflip_x": false,
					"animflip_y": false
				},
				{
					"anim": "singRIGHT",
					"name": "Dad Sing Note RIGHT",
					"loop": false,
					"loop_point": 0,
					"offsets": [0, 0],
					"fps": 24,
					"indices": [],
					"animflip_x": false,
					"animflip_y": false
				}
			],
			"no_antialiasing": false,
			"image": "characters/DADDY_DEAREST",
			"healthbar_colors": [161, 161, 161],
			"healthicon": "face",
			"camera_position": [0, 0],
			"position": [0, 0],
			"flip_x": false,
			"flip_y": false,
			"sing_duration": 6.1,
			"scale": 1
		}';

	var charDropDown:DropDownAdvanced;
	function addSettingsUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Settings";

		var check_player = new FlxUICheckBox(10, 60, null, null, "Playable Character", 100);
		check_player.checked = daAnim.startsWith('bf');
		check_player.callback = function()
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = !char.flipX;
			updatePointerPos();
			reloadBGs();
			ghostChar.flipX = char.flipX;
		};

		charDropDown = new DropDownAdvanced(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(character:String)
		{
			daAnim = characterList[Std.parseInt(character)];
			check_player.checked = daAnim.startsWith('bf');
			loadChar(!check_player.checked);
			updatePresence();
			reloadCharacterDropDown();
		});
		charDropDown.selectedLabel = daAnim;
		reloadCharacterDropDown();

		var reloadCharacter:FlxButton = new FlxButton(140, 20, "Reload Char", function()
		{
			loadChar(!check_player.checked);
			reloadCharacterDropDown();
		});

		var templateCharacter:FlxButton = new FlxButton(140, 50, "Load Template", function()
		{
			var parsedJson:CharacterFile = cast Json.parse(TemplateCharacter);
			var characters:Array<Character> = [char, ghostChar];
			var isPlayer:Bool = char.isPlayer;
			for (character in characters)
			{
				character.animOffsets.clear();
				character.animationsArray = parsedJson.animations;
				for (anim in character.animationsArray)  character.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				if(character.animationsArray[0] != null) character.playAnim(character.animationsArray[0].anim, true);

				character.singDuration = parsedJson.sing_duration;
				character.positionArray = parsedJson.position;
				character.cameraPosition = parsedJson.camera_position;

				character.imageFile = parsedJson.image;
				character.jsonScale = parsedJson.scale;
				character.noAntialiasing = parsedJson.no_antialiasing;
				character.originalFlipX = parsedJson.flip_x;
				character.originalFlipY = parsedJson.flip_y;
				character.healthIcon = parsedJson.healthicon;
				character.healthColorArray = parsedJson.healthbar_colors;
				character.setPosition(character.positionArray[0] + OFFSET_X + 100, character.positionArray[1]);

				character.flipX = isPlayer;
				character.flipY = false;
			}

			reloadCharacterImage();
			reloadCharacterDropDown();
			reloadCharacterOptions();
			resetHealthBarColor();
			updatePointerPos();
			genBoyOffsets();
		});
		templateCharacter.color = FlxColor.RED;
		templateCharacter.label.color = FlxColor.WHITE;

		tab_group.add(new FlxText(charDropDown.x, charDropDown.y - 18, 0, 'Character:'));
		tab_group.add(check_player);
		tab_group.add(reloadCharacter);
		tab_group.add(charDropDown);
		tab_group.add(reloadCharacter);
		tab_group.add(templateCharacter);
		UI_box.addGroup(tab_group);
	}

	var imageInputText:UIInputTextAdvanced;
	var healthIconInputText:UIInputTextAdvanced;

	var singDurationStepper:FlxUINumericStepper;
	var scaleStepper:FlxUINumericStepper;
	var positionXStepper:FlxUINumericStepper;
	var positionYStepper:FlxUINumericStepper;
	var positionCameraXStepper:FlxUINumericStepper;
	var positionCameraYStepper:FlxUINumericStepper;

	var flipXCheckBox:FlxUICheckBox;
	var flipYCheckBox:FlxUICheckBox;
	var noAntialiasingCheckBox:FlxUICheckBox;

	var healthColorStepperR:FlxUINumericStepper;
	var healthColorStepperG:FlxUINumericStepper;
	var healthColorStepperB:FlxUINumericStepper;

	var optimizeJsonBox:FlxUICheckBox;

	function addCharacterUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Character";

		imageInputText = new UIInputTextAdvanced(15, 30, 200, 'characters/BOYFRIEND', 8);
		var reloadImage:FlxButton = new FlxButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", function()
		{
			char.imageFile = imageInputText.text;
			reloadCharacterImage();
			if(char.animation.curAnim != null) char.playAnim(char.animation.curAnim.name, true);
		});

		var decideIconColor:FlxButton = new FlxButton(reloadImage.x, reloadImage.y + 30, "Get Icon Color", function()
			{
				var coolColor = FlxColor.fromInt(CoolUtil.dominantColor(leHealthIcon));
				healthColorStepperR.value = coolColor.red;
				healthColorStepperG.value = coolColor.green;
				healthColorStepperB.value = coolColor.blue;
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperR, null);
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperG, null);
				getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperB, null);
			});

		healthIconInputText = new UIInputTextAdvanced(15, imageInputText.y + 35, 75, leHealthIcon.getCharacter(), 8);

		singDurationStepper = new FlxUINumericStepper(15, healthIconInputText.y + 45, 0.1, 4, 0, 999, 1);

		scaleStepper = new FlxUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);

		flipXCheckBox = new FlxUICheckBox(singDurationStepper.x + 75, singDurationStepper.y, null, null, "Flip X", 40);
		flipXCheckBox.checked = char.flipX;
		if(char.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.callback = function() {
			char.originalFlipX = !char.originalFlipX;
			char.flipX = char.isPlayer ? !char.originalFlipX : char.originalFlipX;
			ghostChar.flipX = char.flipX;
		};

		flipYCheckBox = new FlxUICheckBox(flipXCheckBox.x + 55, flipXCheckBox.y, null, null, "Flip Y", 40);
		flipYCheckBox.checked = char.flipY;
		flipYCheckBox.callback = function() {
			char.originalFlipY = !char.originalFlipY;
			char.flipY = char.originalFlipY;
			ghostChar.flipY = char.flipY;
		};

		noAntialiasingCheckBox = new FlxUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, null, null, "No Antialiasing", 80);
		noAntialiasingCheckBox.checked = char.noAntialiasing;
		noAntialiasingCheckBox.callback = function() {
			char.antialiasing = !noAntialiasingCheckBox.checked && ClientPrefs.data.antialiasing;
			char.noAntialiasing = noAntialiasingCheckBox.checked;
			ghostChar.antialiasing = char.antialiasing;
		};

		positionXStepper = new FlxUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y, 10, char.positionArray[0], -9999, 9999, 0);
		positionYStepper = new FlxUINumericStepper(positionXStepper.x + 60, positionXStepper.y, 10, char.positionArray[1], -9999, 9999, 0);

		positionCameraXStepper = new FlxUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, char.cameraPosition[0], -9999, 9999, 0);
		positionCameraYStepper = new FlxUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, char.cameraPosition[1], -9999, 9999, 0);

		var saveCharacterButton:FlxButton = new FlxButton(reloadImage.x, noAntialiasingCheckBox.y + 40, "Save Character", saveCharacter);

		optimizeJsonBox = new FlxUICheckBox(saveCharacterButton.x, saveCharacterButton.y-20, null, null, "Optimize JSON?", 55);

		healthColorStepperR = new FlxUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, char.healthColorArray[0], 0, 255, 0);
		healthColorStepperG = new FlxUINumericStepper(singDurationStepper.x + 60, saveCharacterButton.y, 20, char.healthColorArray[1], 0, 255, 0);
		healthColorStepperB = new FlxUINumericStepper(singDurationStepper.x + 120, saveCharacterButton.y, 20, char.healthColorArray[2], 0, 255, 0);

		tab_group.add(new FlxText(15, imageInputText.y - 18, 0, 'Image file name:'));
		tab_group.add(new FlxText(15, healthIconInputText.y - 18, 0, 'Health icon name:'));
		tab_group.add(new FlxText(15, singDurationStepper.y - 18, 0, 'Sing Animation length:'));
		tab_group.add(new FlxText(15, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Character X/Y:'));
		tab_group.add(new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 0, 'Camera X/Y:'));
		tab_group.add(new FlxText(healthColorStepperR.x, healthColorStepperR.y - 18, 0, 'Health bar R/G/B:'));
		tab_group.add(imageInputText);
		tab_group.add(reloadImage);
		tab_group.add(decideIconColor);
		tab_group.add(healthIconInputText);
		tab_group.add(singDurationStepper);
		tab_group.add(scaleStepper);
		tab_group.add(flipXCheckBox);
		tab_group.add(flipYCheckBox);
		tab_group.add(noAntialiasingCheckBox);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(positionCameraXStepper);
		tab_group.add(positionCameraYStepper);
		tab_group.add(healthColorStepperR);
		tab_group.add(healthColorStepperG);
		tab_group.add(healthColorStepperB);
		tab_group.add(saveCharacterButton);
		tab_group.add(optimizeJsonBox);
		UI_characterbox.addGroup(tab_group);
	}

	var ghostDropDown:DropDownAdvanced;
	var animationDropDown:DropDownAdvanced;
	var animationInputText:UIInputTextAdvanced;
	var animationNameInputText:UIInputTextAdvanced;
	var animationIndicesInputText:UIInputTextAdvanced;
	var animationNameFramerate:FlxUINumericStepper;
	var animationLoopCheckBox:FlxUICheckBox;
	var animationFlipXCheckBox:FlxUICheckBox;
	var animationFlipYCheckBox:FlxUICheckBox;
	var animationLoopPoint:FlxUINumericStepper;
	function addAnimationsUI() {
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Animations";

		animationInputText = new UIInputTextAdvanced(15, 85, 80, '', 8);
		animationNameInputText = new UIInputTextAdvanced(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		animationIndicesInputText = new UIInputTextAdvanced(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		animationNameFramerate = new FlxUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240);
		animationLoopCheckBox = new FlxUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, null, null, "Looped?", 50);
		animationFlipXCheckBox = new FlxUICheckBox(animationNameFramerate.x + 85, animationNameFramerate.y - animationNameFramerate.height - 5, null, null, "Flip X", 40);
		animationFlipYCheckBox = new FlxUICheckBox(animationFlipXCheckBox.x, animationFlipXCheckBox.y + animationFlipXCheckBox.height + 5, null, null, "Flip Y", 40);
		animationLoopPoint = new FlxUINumericStepper(animationFlipYCheckBox.x, animationLoopCheckBox.y, 1, 0, 0);

		animationDropDown = new DropDownAdvanced(15, animationInputText.y - 55, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(pressed:String) {
			var anim:AnimArray = char.animationsArray[Std.parseInt(pressed)];
			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationLoopPoint.value = anim.loop_point;
			animationNameFramerate.value = anim.fps;
			animationFlipXCheckBox.checked = anim.animflip_x;
			animationFlipYCheckBox.checked = anim.animflip_y;

			var indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
		});

		ghostDropDown = new DropDownAdvanced(animationDropDown.x + 150, animationDropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(pressed:String) {
			var selectedAnimation:Int = Std.parseInt(pressed);
			ghostChar.visible = selectedAnimation > 0;
			char.alpha = selectedAnimation > 0 ? 0.85 : 1;
			if(selectedAnimation > 0) ghostChar.playAnim(ghostChar.animationsArray[selectedAnimation-1].anim, true);
		});

		var addUpdateButton:FlxButton = new FlxButton(70, animationIndicesInputText.y + 30, "Add/Update", function() {
			var str:String = animationIndicesInputText.text.trim();
			var indices:Array<Int> = [];
			// stolen from redar13 (again) >:3
			if (str.contains('...')) {
				var split:Array<String> = str.split('...');
				var from:Int = FlxMath.absInt(Std.parseInt(split[0]));
				var to:Int = FlxMath.absInt(Std.parseInt(split[1]));
				var reverse:Bool = from > to;

				for (i in 0...(reverse ? from - to : to - from) + 1)
					indices.push((reverse ? to : from) + i);

				if (reverse) indices.reverse();
				animationIndicesInputText.text = indices.join(',');
			} else
				indices = str.length > 0 ? FlxStringUtil.toIntArray(str) : [];

			var lastAnim:String = char.animationsArray[curAnim] != null ? char.animationsArray[curAnim].anim : '';
			var lastOffsets:Array<Int> = [0, 0];
			for (anim in char.animationsArray)
				if(animationInputText.text == anim.anim) {
					lastOffsets = anim.offsets;
					if(char.animation.getByName(animationInputText.text) != null)
						char.animation.remove(animationInputText.text);
					char.animationsArray.remove(anim);
				}

			var newAnim:AnimArray = {
				anim: animationInputText.text,
				name: animationNameInputText.text,
				fps: Math.round(animationNameFramerate.value),
				loop: animationLoopCheckBox.checked,
				loop_point: Math.round(animationLoopPoint.value),
				indices: indices,
				offsets: lastOffsets,
				animflip_x: animationFlipXCheckBox.checked,
				animflip_y: animationFlipYCheckBox.checked
			};
			char.generateAnim(newAnim);
			char.animationsArray.push(newAnim);

			if(lastAnim == animationInputText.text) {
				var leAnim:FlxAnimation = char.animation.getByName(lastAnim);
				if(leAnim != null && leAnim.frames.length > 0)
					char.playAnim(lastAnim, true);
				else
					for(i in 0...char.animationsArray.length)
						if(char.animationsArray[i] != null) {
							leAnim = char.animation.getByName(char.animationsArray[i].anim);
							if(leAnim != null && leAnim.frames.length > 0) {
								char.playAnim(char.animationsArray[i].anim, true);
								curAnim = i;
								break;
							}
						}
			}

			reloadAnimationDropDown();
			genBoyOffsets();
			trace('Added/Updated animation: ' + animationInputText.text);
		});

		var removeButton:FlxButton = new FlxButton(180, animationIndicesInputText.y + 30, "Remove", function() {
			for (anim in char.animationsArray) {
				if(animationInputText.text == anim.anim) {
					var resetAnim:Bool = char.animation.curAnim != null && anim.anim == char.animation.curAnim.name;
					if(char.animation.getByName(anim.anim) != null) char.animation.remove(anim.anim);
					if(char.animOffsets.exists(anim.anim)) char.animOffsets.remove(anim.anim);
					char.animationsArray.remove(anim);

					if(resetAnim && char.animationsArray.length > 0) char.playAnim(char.animationsArray[0].anim, true);
					reloadAnimationDropDown();
					genBoyOffsets();
					trace('Removed animation: ' + animationInputText.text);
					break;
				}
			}
		});

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tab_group.add(new FlxText(ghostDropDown.x, ghostDropDown.y - 18, 0, 'Animation Ghost:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tab_group.add(new FlxText(animationNameFramerate.x, animationNameFramerate.y - 18, 0, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation on .XML/.TXT file:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));
		tab_group.add(new FlxText(animationLoopPoint.x, animationNameInputText.y - 18, 0, 'Loop Point:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationNameFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(animationFlipXCheckBox);
		tab_group.add(animationFlipYCheckBox);
		tab_group.add(animationLoopPoint);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(ghostDropDown);
		tab_group.add(animationDropDown);
		UI_characterbox.addGroup(tab_group);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if(id == UIInputTextAdvanced.CHANGE_EVENT && (sender is UIInputTextAdvanced)) {
			if(sender == healthIconInputText) {
				leHealthIcon.changeIcon(healthIconInputText.text, false);
				char.healthIcon = healthIconInputText.text;
				updatePresence();
			}
			else if(sender == imageInputText) {
				char.imageFile = imageInputText.text;
			}
		} else if(id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper)) {
			if (sender == scaleStepper)
			{
				reloadCharacterImage();
				char.jsonScale = sender.value;
				char.setGraphicSize(Math.floor(char.width * char.jsonScale));
				char.updateHitbox();
				ghostChar.setGraphicSize(Math.floor(ghostChar.width * char.jsonScale));
				ghostChar.updateHitbox();
				reloadGhost();
				updatePointerPos();

				if(char.animation.curAnim != null) char.playAnim(char.animation.curAnim.name, true);
			}
			else if(sender == positionXStepper)
			{
				char.positionArray[0] = positionXStepper.value;
				char.x = char.positionArray[0] + OFFSET_X + 100;
				updatePointerPos();
			}
			else if(sender == singDurationStepper)
			{
				char.singDuration = singDurationStepper.value;//ermm you forgot this??
			}
			else if(sender == positionYStepper)
			{
				char.positionArray[1] = positionYStepper.value;
				char.y = char.positionArray[1];
				updatePointerPos();
			}
			else if(sender == positionCameraXStepper)
			{
				char.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
			}
			else if(sender == positionCameraYStepper)
			{
				char.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
			}
			else if(sender == healthColorStepperR)
			{
				char.healthColorArray[0] = Math.round(healthColorStepperR.value);
				healthBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if(sender == healthColorStepperG)
			{
				char.healthColorArray[1] = Math.round(healthColorStepperG.value);
				healthBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if(sender == healthColorStepperB)
			{
				char.healthColorArray[2] = Math.round(healthColorStepperB.value);
				healthBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
		}
	}

	function reloadCharacterImage() {
		var lastAnim:String = char.animation.curAnim != null ?  char.animation.curAnim.name: '';
		char.frames = (Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT))
			? animateatlas.AtlasFrameMaker.construct(char.imageFile)
			: Paths.getAtlas(char.imageFile);

		if(char.animationsArray != null && char.animationsArray.length > 0) {
			for (anim in char.animationsArray) char.generateAnim(anim);
		} else char.addAnim('idle', 'BF idle dance', null, 24, false);

		(lastAnim != '')
			? char.playAnim(lastAnim, true)
			: char.dance();

		ghostDropDown.selectedLabel = '';
		reloadGhost();
	}

	function genBoyOffsets():Void
	{
		var i:Int = dumbTexts.members.length-1;
		while(i >= 0) {
			var memb:FlxText = dumbTexts.members[i];
			if(memb != null) {
				memb.kill();
				dumbTexts.remove(memb);
				memb.destroy();
			}
			--i;
		}
		dumbTexts.clear();

		var daLoop:Int = 0;
		var offset:Float = Main.fpsVar.visible ? 34 : 20;
		for (anim => offsets in char.animOffsets)
		{
			var text:FlxText = new FlxText(10, offset + (18 * daLoop), 0, anim + ": " + offsets, 16);
			text.setFormat(null, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			//text.scrollFactor.set();
			text.borderSize = 1;
			dumbTexts.add(text);
			text.cameras = [camHUD];
			daLoop++;
		}

		textAnim.visible = true;
		if(dumbTexts.length < 1) {
			var text:FlxText = new FlxText(10, 38, 0, "ERROR! No animations found.", 15);
			//text.scrollFactor.set();
			text.borderSize = 1;
			text.cameras = [camHUD];
			dumbTexts.add(text);
			textAnim.visible = false;
		}
	}

	function loadChar(isDad:Bool, genOffsets:Bool = true) {
		var i:Int = charLayer.members.length-1;
		while(i >= 0) {
			var memb:Character = charLayer.members[i];
			if(memb != null) {
				memb.kill();
				charLayer.remove(memb);
				memb.destroy();
			}
			--i;
		}
		charLayer.clear();
		char = new Character(0, 0, daAnim, !isDad);
		if(char.animationsArray[0] != null) char.playAnim(char.animationsArray[0].anim, true);
		char.debugMode = true;

		ghostChar = char.copy();
		ghostChar.alpha = 0.6;

		charLayer.add(ghostChar);
		charLayer.add(char);

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);

		if(genOffsets) genBoyOffsets();
		reloadCharacterOptions();
		reloadBGs();
		updatePointerPos();
	}

	function updatePointerPos() {
		var charMidpoint:FlxPoint = char.getMidpoint();
		var x:Float = charMidpoint.x + (!char.isPlayer ? 150 + char.cameraPosition[0] : (100 + char.cameraPosition[0]) * -1) - (cameraFollowPointer.height * 0.5);
		var y:Float = charMidpoint.y - (100 - char.cameraPosition[1]) - (cameraFollowPointer.height * 0.5);
		cameraFollowPointer.setPosition(x, y);
		charMidpoint.put();
	}

	function findAnimationByName(name:String):AnimArray {
		for (anim in char.animationsArray) if(anim.anim == name) return anim;
		return null;
	}

	function reloadCharacterOptions() {
		if(UI_characterbox != null) {
			imageInputText.text = char.imageFile;
			healthIconInputText.text = char.healthIcon;
			singDurationStepper.value = char.singDuration;
			scaleStepper.value = char.jsonScale;
			flipXCheckBox.checked = char.originalFlipX;
			flipYCheckBox.checked = char.originalFlipY;
			noAntialiasingCheckBox.checked = char.noAntialiasing;
			resetHealthBarColor();
			leHealthIcon.changeIcon(healthIconInputText.text, false);
			positionXStepper.value = char.positionArray[0];
			positionYStepper.value = char.positionArray[1];
			positionCameraXStepper.value = char.cameraPosition[0];
			positionCameraYStepper.value = char.cameraPosition[1];
			reloadAnimationDropDown();
			updatePresence();
		}
	}

	function reloadAnimationDropDown() {
		var anims:Array<String> = [];
		var ghostAnims:Array<String> = [''];
		for (anim in char.animationsArray) {
			anims.push(anim.anim);
			ghostAnims.push(anim.anim);
		}
		if(anims.length < 1) anims.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims, true));
		ghostDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(ghostAnims, true));
		reloadGhost();
	}

	function reloadGhost() {
		ghostChar.frames = char.frames;
		for (anim in char.animationsArray)
			ghostChar.generateAnim(anim);

		char.alpha = 0.85;
		ghostChar.visible = true;
		if(ghostDropDown.selectedLabel == '') {
			ghostChar.visible = false;
			char.alpha = 1;
		}
		ghostChar.color = 0xFF666688;
		ghostChar.antialiasing = char.antialiasing;
	}

	function reloadCharacterDropDown() {
		var charsLoaded:Map<String, Bool> = new Map();

		#if MODS_ALLOWED
		characterList = [];
		var directories:Array<String> = [Paths.mods('characters/'), Paths.mods(Mods.currentModDirectory + '/characters/'), Paths.getPreloadPath('characters/')];
		for(mod in Mods.getGlobalMods()) directories.push(Paths.mods(mod + '/characters/'));
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if(!charsLoaded.exists(charToCheck)) {
							characterList.push(charToCheck);
							charsLoaded.set(charToCheck, true);
						}
					}
				}
			}
		}
		#else
		characterList = CoolUtil.coolTextFile(Paths.txt('characterList'));
		#end

		charDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true));
		charDropDown.selectedLabel = daAnim;
	}

	function resetHealthBarColor() {
		healthColorStepperR.value = char.healthColorArray[0];
		healthColorStepperG.value = char.healthColorArray[1];
		healthColorStepperB.value = char.healthColorArray[2];
		healthBar.leftBar.color = healthBar.rightBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
	}

	function updatePresence() {
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", "Character: " + daAnim, leHealthIcon.getCharacter());
		#end
	}

	override function update(elapsed:Float)
	{
		if(char.animationsArray[curAnim] != null) {
			var txtAnim:String = char.animationsArray[curAnim].anim;
			final curAnim:FlxAnimation = char.animation.getByName(txtAnim);
			if(curAnim == null || curAnim.frames.length < 1)
				txtAnim += ' (ERROR!)';
			else if(txtAnim.endsWith('-loop'))
				txtAnim += ' (-loop is DEPRECATED!)';
			
			final txtFrame:String = curAnim != null ? '[${curAnim.curFrame}/${curAnim.numFrames-1}]' : 'null';
			textAnim.text = txtAnim + '\nCurrent Frame: $txtFrame';
		}
		else textAnim.text = '';

		var inputTexts:Array<UIInputTextAdvanced> = [animationInputText, imageInputText, healthIconInputText, animationNameInputText, animationIndicesInputText];
		for (i in 0...inputTexts.length) {
			if(inputTexts[i].hasFocus) {
				ClientPrefs.toggleVolumeKeys(false);
				super.update(elapsed);
				return;
			}
		}
		ClientPrefs.toggleVolumeKeys(true);

		if(!charDropDown.dropPanel.visible) {
			if (FlxG.keys.justPressed.ESCAPE) {
				if(goToPlayState) {
					MusicBeatUIState.switchState(new PlayState());
				} else {
					MusicBeatUIState.switchState(new states.editors.MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				FlxG.mouse.visible = false;
				return;
			}

			if (FlxG.keys.justPressed.TAB)
				camMenu.visible = camHUD.visible = !camHUD.visible;

			if (FlxG.keys.justPressed.R) {
				var midPoint:FlxPoint = cameraFollowPointer.getGraphicMidpoint();
				camFollow.setPosition(midPoint.x, midPoint.y);
				midPoint.put();
				FlxG.camera.zoom = 1;
			}

			if (FlxG.keys.pressed.E || FlxG.keys.pressed.Q)
			{
				var add:Float = FlxG.camera.zoom;
					 if	 (FlxG.keys.pressed.E)	add *= elapsed;
				else if	 (FlxG.keys.pressed.Q)	add *= -elapsed;
				FlxG.camera.zoom = FlxMath.bound(FlxG.camera.zoom + add, 0.1, 3);
			}

			if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L)
			{
				var addToCam:Float = 500 * elapsed;
				if (FlxG.keys.justPressed.SHIFT) addToCam *= 4;

					 if	 (FlxG.keys.pressed.I)	camFollow.y -= addToCam;
				else if	 (FlxG.keys.pressed.K)	camFollow.y += addToCam;
					 if	 (FlxG.keys.pressed.J)	camFollow.x -= addToCam;
				else if	 (FlxG.keys.pressed.L)	camFollow.x += addToCam;
			}

			final _animName = char.animationsArray[curAnim].anim;
			final _curAnim = char.animation.getByName(_animName);
			final _curAnimGHOST = char.animation.getByName(_animName);
			if ((FlxG.keys.justPressed.Z || FlxG.keys.justPressed.X) && _curAnim != null) // like in flash!!! :D
			{
				if (!_curAnim.paused) _curAnim.pause();
				var add:Int = 0;
					 if	 (FlxG.keys.justPressed.Z)	add--;
				else if	 (FlxG.keys.justPressed.X)	add++;
				_curAnim.curFrame = Std.int(FlxMath.bound(_curAnim.curFrame + add, 0, _curAnim.numFrames-1));
				if(ghostChar.visible && #if (haxe > "4.2.5") _curAnimGHOST?.name #else _curAnimGHOST != null && _curAnimGHOST.name #end == _curAnim.name)
					_curAnimGHOST.curFrame = _curAnim.curFrame;
			}

			if(char.animationsArray.length > 0) {
				if (FlxG.keys.justPressed.W) curAnim--;
				if (FlxG.keys.justPressed.S) curAnim++;

				if (curAnim < 0) curAnim = char.animationsArray.length - 1;
				if (curAnim >= char.animationsArray.length) curAnim = 0;

				if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
				{
					char.playAnim(char.animationsArray[curAnim].anim, true);
					genBoyOffsets();
				}
				if (FlxG.keys.justPressed.T)
				{
					char.animationsArray[curAnim].offsets = [0, 0];

					char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
					ghostChar.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
					genBoyOffsets();
				}

				var controlArray:Array<Bool> = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];

				for (i in 0...controlArray.length) {
					if(controlArray[i]) {
						var multiplier = FlxG.keys.justPressed.SHIFT ? 10 : 1;
						var arrayVal = i > 1 ? 1 : 0;
						var negaMult:Int = i % 2 == 1 ? -1 : 1;
						char.animationsArray[curAnim].offsets[arrayVal] += negaMult * multiplier;

						char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
						ghostChar.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);

						char.playAnim(char.animationsArray[curAnim].anim, false);
						if(#if (haxe > "4.2.5") _curAnim?.name == _curAnimGHOST?.name
							#else _curAnimGHOST != null && _curAnim != null && _curAnim.name == _curAnimGHOST.name #end)
							ghostChar.playAnim(_curAnim.name, false);
						genBoyOffsets();
					}
				}
			}
		}
		ghostChar.setPosition(char.x, char.y);
		super.update(elapsed);
	}

	var _file:FileReference;

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
	}

	/**
	*  Called when the save file dialog is cancelled.
	*/
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	*  Called if there is an error while saving the gameplay recording.
	*/
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}

	function saveCharacter() {
		var json = {
			"animations": char.animationsArray,
			"image": char.imageFile,
			"scale": char.jsonScale,
			"sing_duration": char.singDuration,
			"healthicon": char.healthIcon,

			"position":	char.positionArray,
			"camera_position": char.cameraPosition,

			"flip_x": char.originalFlipX,
			"flip_y": char.originalFlipY,
			"no_antialiasing": char.noAntialiasing,
			"healthbar_colors": char.healthColorArray
		};

		var data:String = haxe.Json.stringify(json, !optimizeJsonBox.checked ? "\t" : null);

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, daAnim + ".json");
		}
	}

	function ClipboardAdd(prefix:String = ''):String {
		if(prefix.toLowerCase().endsWith('v')) //probably copy paste attempt
			prefix = prefix.substring(0, prefix.length-1);

		var text:String = prefix + lime.system.Clipboard.text.replace('\n', '');
		return text;
	}
	#end
}
