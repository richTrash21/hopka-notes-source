package states.editors;

import flixel.input.mouse.FlxMouseEvent;
#if !RELESE_BUILD_FR
import flixel.math.FlxPoint;
import flixel.ui.FlxButton;
import flixel.addons.ui.*;

import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import openfl.events.Event;

import objects.ui.UIInputTextAdvanced;
import objects.ui.DropDownAdvanced;
import objects.HealthIcon;
import objects.Character;
import objects.Bar;

import sys.FileSystem;

#if (FLX_DEBUG || flixel < version("5.7.0"))
typedef PointerGraphic = flixel.system.debug.interaction.tools.Pointer.GraphicCursorCross;
#else
// flixel 5.7.x fix
@:bitmap("assets/images/debugger/cursorCross.png")
class PointerGraphic extends openfl.display.BitmapData {}
#end

class CharacterEditorState extends backend.MusicBeatUIState
{
	static final dadPosition = FlxPoint.get(100, 100);
	static final bfPosition = FlxPoint.get(770, 100);
	static final textMarkup = [
		new FlxTextFormatMarkerPair(new FlxTextFormat(FlxColor.RED), "<r>"),
		new FlxTextFormatMarkerPair(new FlxTextFormat(FlxColor.LIME), "<l>")
	];

	var character:Character;
	var ghost:FlxSprite;
	var animateGhostImage:String;
	var cameraFollowPointer:FlxSprite;
	var silhouettes:FlxSpriteGroup;

	var cameraZoomText:FlxText;
	var frameAdvanceText:FlxText;

	var healthBar:Bar;
	var healthIcon:HealthIcon;

	var copiedOffset = FlxPoint.get();
	var _char:String = null;
	var _goToPlayState:Bool = true;

	var anims:Array<AnimArray> = null;
	var animsTxt:FlxText;
	var curAnim = 0;

	var camHUD:FlxCamera;

	var UI_box:FlxUITabMenu;
	var UI_characterbox:FlxUITabMenu;

	var helpSubstate:HelpSubstate;

	public function new(?char:String, goToPlayState:Bool = true)
	{
		this._char = char ?? Character.DEFAULT_CHARACTER;
		this._goToPlayState = goToPlayState;
		super();
	}

	override function create()
	{
		HealthIcon.jsonCache.clear();
		Character.jsonCache.clear();
		if (ClientPrefs.data.cacheOnGPU)
			Paths.clearStoredMemory(true);

		persistentUpdate = true;
		FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(substates.PauseSubState.songName ?? ClientPrefs.data.pauseMusic)), 0.4);
		FlxG.cameras.add(camHUD = new FlxCamera(), false).bgColor = 0;

		var lastLoaded = Paths.currentLevel;
		Paths.currentLevel = "week1";

		final bg = new ExtendedSprite(-600, -200, "stageback");
		bg.scrollFactor.set(0.9, 0.9);
		add(bg);

		final stageFront = new ExtendedSprite(-650, 600, "stagefront");
		stageFront.setScale(1.1);
		stageFront.updateHitbox();
		add(stageFront);

		Paths.currentLevel = lastLoaded;

		animsTxt = new FlxText(10, 32, 0, "", 16);
		animsTxt.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1);

		silhouettes = new FlxSpriteGroup();
		add(silhouettes);

		final dad = new FlxSprite(dadPosition.x, dadPosition.y, Paths.image("editors/silhouetteDad"));
		dad.antialiasing = ClientPrefs.data.antialiasing;
		dad.active = false;
		dad.offset.set(-4, 1);
		silhouettes.add(dad);

		final boyfriend = new FlxSprite(bfPosition.x, bfPosition.y + 350, Paths.image("editors/silhouetteBF"));
		boyfriend.antialiasing = ClientPrefs.data.antialiasing;
		boyfriend.active = false;
		boyfriend.offset.set(-6, 2);
		silhouettes.add(boyfriend);

		silhouettes.alpha = 0.25;

		ghost = new FlxSprite();
		ghost.visible = false;
		ghost.alpha = ghostAlpha;
		add(ghost);

		// addCharacter();
		character = new Character(0, 0, _char, !predictCharacterIsNotPlayer(_char), true, false);
		character.debugMode = true;
		character.camera = FlxG.camera;
		add(character);

		cameraFollowPointer = new FlxSprite(flixel.graphics.FlxGraphic.fromClass(PointerGraphic));
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		add(cameraFollowPointer);

		healthBar = new Bar(30, FlxG.height - 75);
		healthBar.scrollFactor.set();
		add(healthBar);
		healthBar.cameras = [camHUD];

		healthIcon = new HealthIcon(character.healthIcon, false, false, false);
		healthIcon.y = FlxG.height - 150;
		add(healthIcon);
		healthIcon.cameras = [camHUD];

		FlxMouseEvent.globalManager.add(healthIcon,
			(icon) ->
			{
				if (icon.animation.curAnim.numFrames > 1)
					icon.animation.curAnim.curFrame = FlxMath.wrap(++icon.animation.curAnim.curFrame, 0, icon.animation.curAnim.numFrames-1);
				icon.scale.set(0.975 * icon.baseScale, 0.975 * icon.baseScale);
			},
			(icon) -> icon.scale.set(icon.baseScale, icon.baseScale)
		);

		animsTxt.cameras = [camHUD];
		add(animsTxt);

		var tipText:FlxText = new FlxText("Press F1 for Help", 16);
		tipText.cameras = [camHUD];
		tipText.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1);
		tipText.alignment = RIGHT;
		tipText.scrollFactor.set();
		tipText.active = false;
		tipText.setPosition(FlxG.width - tipText.width, FlxG.height - tipText.height);
		add(tipText);

		cameraZoomText = new FlxText(0, 50, 200, "Zoom: 1x");
		cameraZoomText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		cameraZoomText.scrollFactor.set();
		cameraZoomText.borderSize = 1;
		cameraZoomText.cameras = [camHUD];
		add(cameraZoomText.screenCenter(X));

		frameAdvanceText = new FlxText(0, 75, 350, "");
		frameAdvanceText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		frameAdvanceText.scrollFactor.set();
		frameAdvanceText.borderSize = 1;
		frameAdvanceText.cameras = [camHUD];
		add(frameAdvanceText.screenCenter(X));

		// FlxG.mouse.visible = true;
		makeUIMenu();

		updateCharacterPositions();
		reloadAnimList();
		updatePointerPos();
		updateHealthBar();
		character.animation.finish();

		// if (ClientPrefs.data.cacheOnGPU)
		//	Paths.clearUnusedMemory();

		super.create();
		destroySubStates = false;
		helpSubstate = new HelpSubstate();
	}

	function addCharacter(reload = false)
	{
		final isPlayer = (reload ? character.isPlayer : !predictCharacterIsNotPlayer(_char));
		character.loadCharacter(_char, true, false);
		if (!reload /*&& isPlayer != character.editorIsPlayer*/)
		{
			// character.isPlayer = !character.isPlayer;
			// character.flipX = (character.originalFlipX != character.isPlayer);
			if (check_player != null)
				check_player.checked = character.isPlayer;
		}
		character.isPlayer = isPlayer;

		updateCharacterPositions();
		reloadAnimList();
		if (healthBar != null && healthIcon != null)
			updateHealthBar();
	}

	inline function makeLabel(x = 0., y = 0., text:String):FlxText
	{
		final t = new FlxText(x, y, 0, text);
		t.active = false;
		return t;
	}

	function makeUIMenu()
	{
		UI_box = new FlxUITabMenu(null, [
			{name: "Ghost", label: "Ghost"},
			{name: "Settings", label: "Settings"}
		], true);
		UI_box.cameras = [camHUD];

		UI_box.resize(250, 120);
		UI_box.x = FlxG.width - 275;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		UI_characterbox = new FlxUITabMenu(null, [
			{name: "Character", label: "Character"},
			{name: "Animations", label: "Animations"},
		], true);
		UI_characterbox.cameras = [camHUD];

		UI_characterbox.resize(350, 280);
		UI_characterbox.x = UI_box.x - 100;
		UI_characterbox.y = UI_box.y + UI_box.height;
		UI_characterbox.scrollFactor.set();
		add(UI_characterbox);
		add(UI_box);

		addGhostUI();
		addSettingsUI();
		addAnimationsUI();
		addCharacterUI();

		UI_box.selected_tab_id = "Settings";
		UI_characterbox.selected_tab_id = "Character";
	}

	var ghostAlpha:Float = 0.6;
	function addGhostUI()
	{
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Ghost";

		//var hideGhostButton:FlxButton = null;
		var makeGhostButton:FlxButton = new FlxButton(25, 15, "Make Ghost", () ->
		{
			// var anim = anims[curAnim];
			if (character.animation.curAnim == null)
				return;

			var myAnim = anims[curAnim];
			ghost.loadGraphic(character.graphic);
			ghost.frames.frames = character.frames.frames;
			ghost.animation.copyFrom(character.animation);
			ghost.animation.play(character.animation.curAnim.name, true, false, character.animation.curAnim.curFrame);
			ghost.animation.pause();

			ghost.setPosition(character.x, character.y);
			ghost.antialiasing = character.antialiasing;
			ghost.flipX = character.flipX;
			ghost.alpha = ghostAlpha;

			ghost.scale.copyFrom(character.scale);
			ghost.updateHitbox();

			ghost.offset.copyFrom(character.animOffsets.get(character.animation.curAnim.name));
			ghost.visible = true;
			/*hideGhostButton.active = true;
			hideGhostButton.alpha = 1;*/
			trace("created ghost image");
		});

		/*hideGhostButton = new FlxButton(20 + makeGhostButton.width, makeGhostButton.y, "Hide Ghost", () ->
		{
			ghost.visible = false;
			hideGhostButton.active = false;
			hideGhostButton.alpha = 0.6;
		});
		hideGhostButton.active = false;
		hideGhostButton.alpha = 0.6;*/

		var highlightGhost:FlxUICheckBox = new FlxUICheckBox(20 + makeGhostButton.x + makeGhostButton.width, makeGhostButton.y, null, null, "Highlight Ghost", 100);
		highlightGhost.callback = () ->
			ghost.colorTransform.redOffset = ghost.colorTransform.greenOffset = ghost.colorTransform.blueOffset = highlightGhost.checked ? 125 : 0;

		var ghostAlphaSlider:FlxUISlider = new FlxUISlider(this, "ghostAlpha", 10, makeGhostButton.y + 25, 0, 1, 210, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		ghostAlphaSlider.nameLabel.text = "Opacity:";
		ghostAlphaSlider.decimals = 2;
		ghostAlphaSlider.callback = (_) -> ghost.alpha = ghostAlpha;
		ghostAlphaSlider.value = ghostAlpha;

		tab_group.add(makeGhostButton);
		//tab_group.add(hideGhostButton);
		tab_group.add(highlightGhost);
		tab_group.add(ghostAlphaSlider);
		UI_box.addGroup(tab_group);
	}

	var check_player:FlxUICheckBox;
	var charDropDown:DropDownAdvanced;
	var templateCharacter:FlxButton;
	function addSettingsUI()
	{
		final tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Settings";

		check_player = new FlxUICheckBox(10, 60, null, null, "Playable Character", 100);
		check_player.checked = character.isPlayer;
		check_player.callback = () ->
		{
			character.isPlayer = !character.isPlayer;
			// character.flipX = !character.flipX;
			updateCharacterPositions();
			updatePointerPos(false);
		};

		final reloadCharacter = new FlxButton(140, 20, "Reload Char", () ->
		{
			addCharacter(true);
			updatePointerPos();
			reloadCharacterOptions();
			reloadCharacterDropDown();
		});

		templateCharacter = new FlxButton(140, 50, "Load Template", () ->
		{
			final _template:CharacterFile =
			{
				animations: [
					newAnim("idle",		  "BF idle dance"),
					newAnim("singLEFT",	  "BF NOTE LEFT0"),
					newAnim("singDOWN",	  "BF NOTE DOWN0"),
					newAnim("singUP",	  "BF NOTE UP0"),
					newAnim("singRIGHT",  "BF NOTE RIGHT0")
				],
				no_antialiasing: false,
				flip_x: false,
				flip_y: false,
				healthicon: "face",
				image: "characters/BOYFRIEND",
				sing_duration: 4,
				scale: 1,
				healthbar_colors: [161, 161, 161],
				camera_position: [0, 0],
				position: [0, 0]
			};

			character.loadCharacter(_template, true, false);
			character.color = FlxColor.WHITE;
			character.alpha = 1;
			reloadAnimList();
			reloadCharacterOptions();
			updateCharacterPositions();
			updatePointerPos();
			reloadCharacterDropDown();
			updateHealthBar();
		});
		templateCharacter.color = FlxColor.RED;
		templateCharacter.label.color = FlxColor.WHITE;


		charDropDown = new DropDownAdvanced(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray([""], true), (index:String) ->
		{
			final intended = characterList[Std.parseInt(index)];
			if (intended == null || intended.length < 1)
				return;

			var characterPath:String = 'characters/$intended.json';
			var path:String = Paths.getPath(characterPath, TEXT, null, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (Assets.exists(path))
			#end
			{
				_char = intended;
				check_player.checked = character.isPlayer;
				addCharacter();
				reloadCharacterOptions();
				reloadCharacterDropDown();
				updatePointerPos();
			}
			else
			{
				reloadCharacterDropDown();
				FlxG.sound.play(Paths.sound("cancelMenu"));
			}
		});
		reloadCharacterDropDown();
		charDropDown.selectedLabel = _char;

		tab_group.add(makeLabel(charDropDown.x, charDropDown.y - 18, "Character:"));
		tab_group.add(check_player);
		tab_group.add(reloadCharacter);
		tab_group.add(templateCharacter);
		tab_group.add(charDropDown);
		UI_box.addGroup(tab_group);
	}

	var animationDropDown:DropDownAdvanced;
	var animationInputText:UIInputTextAdvanced;
	var animationNameInputText:UIInputTextAdvanced;
	var animationIndicesInputText:UIInputTextAdvanced;
	var animationFramerate:FlxUINumericStepper;
	var animationLoopCheckBox:FlxUICheckBox;
	var animationFlipXCheckBox:FlxUICheckBox;
	var animationFlipYCheckBox:FlxUICheckBox;
	var animationLoopPoint:FlxUINumericStepper;

	function addAnimationsUI()
	{
		final tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Animations";

		animationInputText			= new UIInputTextAdvanced(15, 85, 80, "", 8);
		animationNameInputText		= new UIInputTextAdvanced(animationInputText.x, animationInputText.y + 35, 150, "", 8);
		animationIndicesInputText	= new UIInputTextAdvanced(animationNameInputText.x, animationNameInputText.y + 40, 250, "", 8);
		animationFramerate			= new FlxUINumericStepper(animationInputText.x + 170, animationInputText.y - 50, 1, 24, 0, 240, 0);
		animationLoopCheckBox		= new FlxUICheckBox(animationInputText.x + 170, animationNameInputText.y - 1, null, null, "Looped?", 50);
		animationLoopPoint			= new FlxUINumericStepper(animationLoopCheckBox.x, animationInputText.y, 1, 0, 0);
		animationFlipXCheckBox		= new FlxUICheckBox(animationLoopPoint.x + 85, animationInputText.y - 1, null, null, "Flip X", 40);
		animationFlipYCheckBox		= new FlxUICheckBox(animationFlipXCheckBox.x, animationNameInputText.y - 1, null, null, "Flip Y", 40);

		animationDropDown = new DropDownAdvanced(15, animationInputText.y - 55, FlxUIDropDownMenu.makeStrIdLabelArray([""], true), (pressed:String) ->
		{
			if (character.animationsArray.length == 0)
				return Main.warn("Trying to switch to null animation!");

			final anim:AnimArray = character.animationsArray[Std.parseInt(pressed)];
			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationLoopPoint.value = anim.loop_point;
			animationFramerate.value = anim.fps;
			animationFlipXCheckBox.checked = anim.animflip_x;
			animationFlipYCheckBox.checked = anim.animflip_y;

			final indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
		});

		var addUpdateButton:FlxButton = new FlxButton(70, animationIndicesInputText.y + 60, "Add/Update", () ->
		{
			final str = animationIndicesInputText.text.trim();
			var indices:Array<Int>;
			if (str.contains("...")) // stolen from redar13 (again) >:3
			{
				var split = str.split("...");
				var from = FlxMath.maxInt(0, Std.parseInt(split[0]));
				var to = FlxMath.maxInt(0, Std.parseInt(split[1]));

				var reverse = false;
				if ((reverse = from > to))
				{
					final temp = from;
					from = to;
					to = temp;
				}
				indices = from == to ? [from] : [for (i in from...to+1) i];
				if (reverse)
					indices.reverse();

				animationIndicesInputText.text = indices.join(",");
			}
			else
				indices = str.length == 0 ? [] : flixel.util.FlxStringUtil.toIntArray(str);

			// var lastAnim:String = (character.animationsArray[curAnim] == null) ? "" : character.animationsArray[curAnim].anim;
			var lastOffsets = [0., 0.];
			for (anim in character.animationsArray)
				if (animationInputText.text == anim.anim)
				{
					lastOffsets = anim.offsets;
					if (character.animOffsets.exists(animationInputText.text))
						character.animation.remove(animationInputText.text);

					character.animationsArray.remove(anim);
				}

			var addedAnim = newAnim(animationInputText.text, animationNameInputText.text);
			addedAnim.fps = Math.round(animationFramerate.value);
			addedAnim.loop = animationLoopCheckBox.checked;
			addedAnim.loop_point = Math.round(animationLoopPoint.value);
			addedAnim.indices = indices;
			addedAnim.offsets = lastOffsets;
			addedAnim.animflip_x = animationFlipXCheckBox.checked;
			addedAnim.animflip_y = animationFlipYCheckBox.checked;

			character.generateAnim(addedAnim);
			character.animationsArray.push(addedAnim);

			reloadAnimList();
			curAnim = Std.int(Math.max(0, character.animationsArray.indexOf(addedAnim)));
			character.playAnim(addedAnim.anim, true);
			trace("Added/Updated animation: " + animationInputText.text);
		});

		var removeButton = new FlxButton(180, animationIndicesInputText.y + 60, "Remove", () ->
		{
			if (character.animationsArray.length == 0)
				return Main.warn("No animation to remove!");

			for (anim in character.animationsArray)
				if (animationInputText.text == anim.anim)
				{
					final resetAnim = anim.anim == character.animation.name;
					if (character.animOffsets.exists(anim.anim))
					{
						character.animation.remove(anim.anim);
						character.animationsArray.remove(anim);
						character.animOffsets.get(anim.anim).put();
						character.animOffsets.remove(anim.anim);
					}

					if (resetAnim && character.animationsArray.length > 0)
					{
						character.playAnim(anims[curAnim = FlxMath.wrap(curAnim, 0, anims.length-1)].anim, true);
						updateTextColors();
					}
					else if (character.animationsArray.length == 0)
						character.animation.curAnim = null; // hopefully fixes crash

					reloadAnimList();
					trace("Removed animation: " + animationInputText.text);
					break;
				}
		});
		reloadAnimList();
		animationDropDown.selectedLabel = anims[0] == null ? "" : anims[0].anim;

		tab_group.add(makeLabel(animationDropDown.x, animationDropDown.y - 18, "Animations:"));
		tab_group.add(makeLabel(animationInputText.x, animationInputText.y - 18, "Animation name:"));
		tab_group.add(makeLabel(animationFramerate.x, animationFramerate.y - 18, "Framerate:"));
		tab_group.add(makeLabel(animationNameInputText.x, animationNameInputText.y - 18, "Animation Symbol Name/Tag:"));
		tab_group.add(makeLabel(animationIndicesInputText.x, animationIndicesInputText.y - 18, "ADVANCED - Animation Indices:"));
		tab_group.add(makeLabel(animationLoopPoint.x, animationLoopPoint.y - 18, "Loop Point:"));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(animationFlipXCheckBox);
		tab_group.add(animationFlipYCheckBox);
		tab_group.add(animationLoopPoint);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);
		UI_characterbox.addGroup(tab_group);
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

	function addCharacterUI()
	{
		var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Character";

		imageInputText = new UIInputTextAdvanced(15, 30, 200, character.imageFile, 8);
		var reloadImage = new FlxButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", () ->
		{
			var lastAnim = character.animation.curAnim?.name;
			character.imageFile = imageInputText.text;
			reloadCharacterImage();
			if (character.animation.curAnim != null)
				character.playAnim(lastAnim, true);
		});

		var decideIconColor = new FlxButton(reloadImage.x, reloadImage.y + 30, "Get Icon Color", () ->
			{
				character.healthColor = FlxColor.fromInt(CoolUtil.dominantColor(healthIcon));
				updateHealthBar();
			});

		healthIconInputText = new UIInputTextAdvanced(15, imageInputText.y + 35, 75, healthIcon.char, 8);

		singDurationStepper = new FlxUINumericStepper(15, healthIconInputText.y + 60, 0.1, 4, 0, 999, 1);

		scaleStepper = new FlxUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);

		flipXCheckBox = new FlxUICheckBox(singDurationStepper.x + 75, singDurationStepper.y, null, null, "Flip X", 50);
		flipXCheckBox.checked = character.flipX;
		if (character.isPlayer)
			flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.callback = () ->
		{
			character.originalFlipX = !character.originalFlipX;
			character.flipX = (character.originalFlipX != character.isPlayer);
		};

		flipYCheckBox = new FlxUICheckBox(flipXCheckBox.x + 55, flipXCheckBox.y, null, null, "Flip Y", 40);
		flipYCheckBox.checked = character.flipY;
		flipYCheckBox.callback = () ->
		{
			character.originalFlipY = !character.originalFlipY;
			character.flipY = character.originalFlipY;
		};

		noAntialiasingCheckBox = new FlxUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, null, null, "No Antialiasing", 80);
		noAntialiasingCheckBox.checked = character.noAntialiasing;
		noAntialiasingCheckBox.callback = () ->
		{
			if (!noAntialiasingCheckBox.checked && ClientPrefs.data.antialiasing)
				character.antialiasing = true;
			else
				character.antialiasing = false;

			character.noAntialiasing = noAntialiasingCheckBox.checked;
		};

		positionXStepper = new FlxUINumericStepper(flipXCheckBox.x + 120, flipXCheckBox.y, 10, character.position.x, -9999, 9999, 0);
		positionYStepper = new FlxUINumericStepper(positionXStepper.x + 60, positionXStepper.y, 10, character.position.y, -9999, 9999, 0);

		positionCameraXStepper = new FlxUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, character.cameraOffset.x, -9999, 9999, 0);
		positionCameraYStepper = new FlxUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, character.cameraOffset.y, -9999, 9999, 0);

		var saveCharacterButton = new FlxButton(reloadImage.x, noAntialiasingCheckBox.y + 55, "Save Character", saveCharacter);

		optimizeJsonBox = new FlxUICheckBox(saveCharacterButton.x, saveCharacterButton.y - 25, null, null, "Optimize JSON?", 55);

		healthColorStepperR = new FlxUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, character.healthColor.red, 0, 255, 0);
		healthColorStepperG = new FlxUINumericStepper(singDurationStepper.x + 60, saveCharacterButton.y, 20, character.healthColor.green, 0, 255, 0);
		healthColorStepperB = new FlxUINumericStepper(singDurationStepper.x + 120, saveCharacterButton.y, 20, character.healthColor.blue, 0, 255, 0);

		tab_group.add(makeLabel(15, imageInputText.y - 18, "Image file name:"));
		tab_group.add(makeLabel(15, healthIconInputText.y - 18, "Health icon name:"));
		tab_group.add(makeLabel(15, singDurationStepper.y - 18, "Sing Animation length:"));
		tab_group.add(makeLabel(15, scaleStepper.y - 18, "Scale:"));
		tab_group.add(makeLabel(positionXStepper.x, positionXStepper.y - 18, "Character X/Y:"));
		tab_group.add(makeLabel(positionCameraXStepper.x, positionCameraXStepper.y - 18, "Camera X/Y:"));
		tab_group.add(makeLabel(healthColorStepperR.x, healthColorStepperR.y - 18, "Health bar R/G/B:"));

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

	// тут насрано фу блять
	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id != UIInputTextAdvanced.CHANGE_EVENT && id != FlxUINumericStepper.CHANGE_EVENT)
			return;

		if (sender is UIInputTextAdvanced)
		{
			if (sender == healthIconInputText)
			{
				var lastIcon = healthIcon.char;
				healthIcon.changeIcon(healthIconInputText.text, false, false);
				character.healthIcon = healthIconInputText.text;
				if (lastIcon != healthIcon.char)
					updatePresence();
			}
			else if (sender == imageInputText)
			{
				character.imageFile = imageInputText.text;
			}
		}
		else if (sender is FlxUINumericStepper)
		{
			if (sender == scaleStepper)
			{
				reloadCharacterImage();
				character.jsonScale = sender.value;
				character.scale.set(character.jsonScale, character.jsonScale);
				character.updateHitbox();
				updatePointerPos(false);
			}
			else if (sender == positionXStepper)
			{
				character.position.x = positionXStepper.value;
				updateCharacterPositions();
				updatePointerPos();
			}
			else if (sender == positionYStepper)
			{
				character.position.y = positionYStepper.value;
				updateCharacterPositions();
				updatePointerPos();
			}
			else if (sender == singDurationStepper)
			{
				character.singDuration = singDurationStepper.value;
			}
			else if (sender == positionCameraXStepper)
			{
				character.cameraOffset.x = positionCameraXStepper.value;
				updatePointerPos();
			}
			else if (sender == positionCameraYStepper)
			{
				character.cameraOffset.y = positionCameraYStepper.value;
				updatePointerPos();
			}
			else if (sender == healthColorStepperR)
			{
				character.healthColor.red = Math.round(healthColorStepperR.value);
				updateHealthBar();
			}
			else if (sender == healthColorStepperG)
			{
				character.healthColor.green = Math.round(healthColorStepperG.value);
				updateHealthBar();
			}
			else if (sender == healthColorStepperB)
			{
				character.healthColor.blue = Math.round(healthColorStepperB.value);
				updateHealthBar();
			}
		}
	}

	function reloadCharacterImage()
	{
		var lastAnim = character.animation.curAnim.name;
		var anims:Array<AnimArray> = character.animationsArray.copy();

		character.color = FlxColor.WHITE;
		character.alpha = 1;

		if (Paths.fileExists("images/" + character.imageFile + "/Animation.json", TEXT))
			character.frames = animateatlas.AtlasFrameMaker.construct(character.imageFile);
		else if (Paths.fileExists("images/" + character.imageFile + ".txt", TEXT))
			character.frames = Paths.getPackerAtlas(character.imageFile);
		// else if (Paths.fileExists("images/" + character.imageFile + ".json", TEXT))
		//	character.frames = Paths.getAsepriteAtlas(character.imageFile);
		else
			character.frames = Paths.getSparrowAtlas(character.imageFile);

		for (anim in anims)
			character.generateAnim(anim);

		if (anims.length > 0)
		{
			if (lastAnim == "")
				character.dance();
			else
				character.playAnim(lastAnim, true);
		}
	}

	function reloadCharacterOptions()
	{
		if (UI_characterbox == null)
			return;

		check_player.checked = character.isPlayer;
		imageInputText.text = character.imageFile;
		healthIconInputText.text = character.healthIcon;
		singDurationStepper.value = character.singDuration;
		scaleStepper.value = character.jsonScale;
		flipXCheckBox.checked = character.originalFlipX;
		flipYCheckBox.checked = character.originalFlipY;
		noAntialiasingCheckBox.checked = character.noAntialiasing;
		positionXStepper.value = character.position.x;
		positionYStepper.value = character.position.y;
		positionCameraXStepper.value = character.cameraOffset.x;
		positionCameraYStepper.value = character.cameraOffset.y;
		reloadAnimationDropDown();
		updateHealthBar();
	}

	inline static final ONE_IN_SIXTY = 1 / 60;

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	var undoOffsets:Array<Float> = null;

	static var __mousePos = FlxPoint.get();
	var __dragging = false;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.F3)
		{
			if (FlxG.sound.music.playing)
				FlxG.sound.music.pause();
			else
				FlxG.sound.music.play();
		}

		if (animationInputText.hasFocus || animationNameInputText.hasFocus || animationIndicesInputText.hasFocus || imageInputText.hasFocus || healthIconInputText.hasFocus)
		{
			ClientPrefs.toggleVolumeKeys(false);
			return;
		}
		ClientPrefs.toggleVolumeKeys(true);

		var ctrlMult = 1.;
		var shiftMult = 1;
		var shiftMultBig = 1;
		if (FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if (FlxG.keys.pressed.CONTROL)
			ctrlMult = 0.25;

		// CAMERA CONTROLS
		final CAM_LEFT	= FlxG.keys.pressed.J;
		final CAM_DOWN	= FlxG.keys.pressed.I;

		if (CAM_LEFT || FlxG.keys.pressed.L)
			FlxG.camera.scroll.x += (CAM_LEFT ? -elapsed : elapsed) * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.K || CAM_DOWN)
			FlxG.camera.scroll.y += (CAM_DOWN ? -elapsed : elapsed) * 500 * shiftMult * ctrlMult;

		final lastZoom = FlxG.camera.zoom;
		final ADD_ZOOM = FlxG.keys.pressed.E;
		if (FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL)
			FlxG.camera.zoom = 1;
		else if (ADD_ZOOM || FlxG.keys.pressed.Q)
			FlxG.camera.zoom = FlxMath.bound(FlxG.camera.zoom + (ADD_ZOOM ? elapsed : -elapsed) * FlxG.camera.zoom * shiftMult * ctrlMult, 0.1, 3);
		else if (FlxG.mouse.wheel != 0 && !(charDropDown.dropPanel.visible || animationDropDown.dropPanel.visible))
			FlxG.camera.zoom = FlxMath.bound(FlxG.camera.zoom + FlxG.camera.zoom * FlxG.mouse.wheel * 0.1 * shiftMult * ctrlMult, 0.1, 3);

		if (lastZoom != FlxG.camera.zoom)
			cameraZoomText.text = "Zoom: " + FlxMath.roundDecimal(FlxG.camera.zoom, 2) + "x";

		// CHARACTER CONTROLS
		final ANIM_NEXT = FlxG.keys.justPressed.S;
		final ANIM_PREV = FlxG.keys.justPressed.W;
		var changedAnim = ANIM_PREV || ANIM_NEXT;
		if (anims.length > 1)
		{
			if (ANIM_PREV)
				curAnim--;
			else if (ANIM_NEXT)
				curAnim++;

			if (changedAnim)
			{
				undoOffsets = null;
				curAnim = FlxMath.wrap(curAnim, 0, anims.length-1);
				character.playAnim(anims[curAnim].anim, true);
				updateTextColors();
			}
		}

		final offset = character.animation.curAnim == null ? null : character.animOffsets.get(character.animation.curAnim.name);

		var changedOffset = false;
		var moveKeysP = [FlxG.keys.justPressed.LEFT,	FlxG.keys.justPressed.RIGHT,	FlxG.keys.justPressed.UP,	FlxG.keys.justPressed.DOWN];
		var moveKeys  = [FlxG.keys.pressed.LEFT,		FlxG.keys.pressed.RIGHT,		FlxG.keys.pressed.UP,		FlxG.keys.pressed.DOWN];
		if (moveKeysP.contains(true) && offset != null)
		{
			offset.add(((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig,
					   ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig);
			changedOffset = true;
		}

		if (moveKeys.contains(true) && offset != null)
		{
			if ((holdingArrowsTime += elapsed) > 0.6)
			{
				holdingArrowsElapsed += elapsed;
				while (holdingArrowsElapsed > ONE_IN_SIXTY)
				{
					offset.add(((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig,
							   ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig);
					holdingArrowsElapsed -= ONE_IN_SIXTY;
					changedOffset = true;
				}
			}
		}
		else
			holdingArrowsTime = 0;

		FlxG.mouse.getScreenPosition(camHUD, __mousePos);
		// yeah, this is a mess...
		final inUIBox = FlxMath.pointInCoordinates(__mousePos.x, __mousePos.y, UI_box.x, UI_box.y, UI_box.width, UI_box.height) ||
						FlxMath.pointInCoordinates(__mousePos.x, __mousePos.y, UI_characterbox.x, UI_characterbox.y, UI_characterbox.width, UI_characterbox.height) ||
						(charDropDown.dropPanel.visible &&
							FlxMath.pointInCoordinates(__mousePos.x, __mousePos.y, charDropDown.x, charDropDown.y, charDropDown.dropPanel.width, charDropDown.dropPanel.height)) ||
						(animationDropDown.dropPanel.visible &&
							FlxMath.pointInCoordinates(__mousePos.x, __mousePos.y, animationDropDown.x, animationDropDown.y, animationDropDown.dropPanel.width, animationDropDown.dropPanel.height));
		#if debug
		FlxG.watch.addQuick("inUIBox", inUIBox);
		#end

		if (FlxG.mouse.justPressed && !inUIBox && offset != null)
			fadeUI(__dragging = true);

		if (FlxG.mouse.justMoved)	
		{
			if (FlxG.mouse.pressed)
			{
				if ((!inUIBox || __dragging) && offset != null)
				{
					offset.subtract(FlxG.mouse.deltaScreenX, FlxG.mouse.deltaScreenY);
					changedOffset = true;
				}
			}
			else if (FlxG.mouse.pressedRight)
				FlxG.camera.scroll.subtract(FlxG.mouse.deltaScreenX, FlxG.mouse.deltaScreenY);
		}

		if (FlxG.keys.pressed.CONTROL && offset != null)
		{
			if (FlxG.keys.justPressed.C)
			{
				copiedOffset.copyFrom(offset);
				changedOffset = true;
			}
			else if (FlxG.keys.justPressed.V)
			{
				undoOffsets = [offset.x, offset.y];
				offset.copyFrom(copiedOffset);
				changedOffset = true;
			}
			else if (FlxG.keys.justPressed.R)
			{
				undoOffsets = [offset.x, offset.y];
				offset.set(0, 0);
				changedOffset = true;
			}
			else if (FlxG.keys.justPressed.Z && undoOffsets != null)
			{
				offset.set(undoOffsets[0], undoOffsets[1]);
				changedOffset = true;
			}
		}

		final anim = anims[curAnim];
		if (changedOffset && anim != null && anim.offsets != null && offset != null)
		{
			anim.offsets[0] = offset.x;
			anim.offsets[1] = offset.y;

			final curAnimName = anim.anim;
			final textPos = animsTxt.text.indexOf('$curAnimName: ');
			var breakPos = animsTxt.text.indexOf("\n", textPos);
			if (breakPos == -1)
				breakPos = animsTxt.text.length;

			animsTxt.text = animsTxt.text.replace(animsTxt.text.substring(textPos, breakPos), '$curAnimName: ' + anim.offsets);
			updateTextColors();
			character.addOffset(curAnimName, offset.x, offset.y);
		}

		if (FlxG.mouse.justReleased)
			fadeUI(__dragging = false);

		var txt = "ERROR: No Animation Found";
		var clr = FlxColor.RED;
		if (character.animation.curAnim != null)
		{
			final FRAME_PREV	  = FlxG.keys.justPressed.A;
			final FRAME_PREV_HOLD = FlxG.keys.pressed.A;

			if (FRAME_PREV_HOLD || FlxG.keys.pressed.D)
			{
				if ((holdingFrameTime += elapsed) > 0.5)
					holdingFrameElapsed += elapsed;
			}
			else
				holdingFrameTime = 0;

			if (FlxG.keys.justPressed.SPACE)
				character.playAnim(character.animation.curAnim.name, true);

			var frames = character.animation.curAnim.curFrame;
			var length = character.animation.curAnim.numFrames;

			if (FRAME_PREV || FlxG.keys.justPressed.D || holdingFrameTime > 0.5)
			{
				final isLeft = (holdingFrameTime > 0.5 && FRAME_PREV_HOLD) || FRAME_PREV;
				character.animation.pause();

				if (holdingFrameTime <= 0.5 || holdingFrameElapsed > 0.1)
				{
					frames = FlxMath.wrap(frames + (isLeft ? -shiftMult : shiftMult), 0, length-1);
					character.animation.curAnim.curFrame = frames;
					holdingFrameElapsed -= 0.1;
				}
			}

			txt = 'Frames: ( $frames / ${length-1} )';
			clr = FlxColor.WHITE;
		}
		// if (txt != frameAdvanceText.text)
		frameAdvanceText.text = txt;
		frameAdvanceText.color = clr;

		// OTHER CONTROLS
		if (FlxG.keys.justPressed.F12)
			silhouettes.visible = !silhouettes.visible;

		final F1 = FlxG.keys.justPressed.F1;
		if (F1 || FlxG.keys.justPressed.ESCAPE)
		{
			persistentUpdate = false;
			if (F1)
				openSubState(helpSubstate);
			else if (FlxG.keys.justPressed.ESCAPE)
			{
				// FlxG.mouse.visible = false;
				if (_goToPlayState)
					FlxG.switchState(PlayState.new);
				else
				{
					FlxG.switchState(states.editors.MasterEditorMenu.new);
					FlxG.sound.playMusic(Paths.music("freakyMenu"));
				}
			}
		}
		
	}

	@:access(flixel.addons.ui.FlxInputText.backgroundSprite)
	inline function fadeUI(_in = false)
	{
		UI_box.alpha = UI_characterbox.alpha = _in ? .6 : 1;
		UI_box.color = UI_characterbox.color = _in ? FlxColor.GRAY : FlxColor.WHITE;
		UI_box.active = UI_characterbox.active = !_in;

		// fix some shit (i hate flixel ui)
		templateCharacter.color = _in ? FlxColor.interpolate(FlxColor.GRAY, FlxColor.RED, .6) : FlxColor.RED;

		animationInputText.color = animationNameInputText.color = animationIndicesInputText.color =
		imageInputText.color     = healthIconInputText.color    = charDropDown.header.text.color  =
		animationDropDown.header.text.color = _in ? FlxColor.interpolate(FlxColor.GRAY, FlxColor.BLACK, .6) : FlxColor.BLACK;

		// animationInputText.backgroundSprite.color = animationNameInputText.backgroundSprite.color = animationIndicesInputText.backgroundSprite.color =
		// imageInputText.backgroundSprite.color     = healthIconInputText.backgroundSprite.color    = _in ? FlxColor.interpolate(FlxColor.GRAY, FlxColor.WHITE, .6) : FlxColor.WHITE;
		animationInputText.backgroundSprite.alpha = animationNameInputText.backgroundSprite.alpha = animationIndicesInputText.backgroundSprite.alpha =
		imageInputText.backgroundSprite.alpha     = healthIconInputText.backgroundSprite.alpha    = _in ? .4 : 1;
	}

	static final __point = FlxPoint.get();
	inline function updatePointerPos(snap = true)
	{
		character.getMidpoint(__point);
		if (character.isPlayer)
			__point.add(-100 - character.cameraOffset.x, -100 + character.cameraOffset.y);
		else
			__point.add(150 + character.cameraOffset.x, -100 + character.cameraOffset.y);

		cameraFollowPointer.setPosition(__point.x, __point.y);

		if (snap)
			FlxG.camera.scroll.copyFrom(cameraFollowPointer.getMidpoint(__point).subtract(FlxG.width * 0.5, FlxG.height * 0.5));
	}

	inline function updateHealthBar()
	{
		healthColorStepperR.value = character.healthColor.red;
		healthColorStepperG.value = character.healthColor.green;
		healthColorStepperB.value = character.healthColor.blue;
		healthBar.leftBar.color = healthBar.rightBar.color = character.healthColor;
		healthIcon.changeIcon(character.healthIcon, false, false);
		updatePresence();
	}

	inline function updatePresence()
	{
		#if hxdiscord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", 'Character: $_char', healthIcon.char);
		#end
	}

	inline function reloadAnimList()
	{
		anims = character.animationsArray;
		if (anims.length == 0) // it still crashes :(
			animsTxt.applyMarkup("<r>NO ANIMATIONS!<r>", textMarkup);
		else
		{
			character.playAnim(anims[0].anim, true);
			var newText = "";
			for (anim in anims)
				newText += anim.anim + ": " + anim.offsets + "\n";
			animsTxt.text = newText.substr(0, newText.length-1);
		}
		curAnim = 0;

		updateTextColors();
		if (animationDropDown != null)
			reloadAnimationDropDown();
	}

	inline function updateTextColors()
	{
		if (anims.length == 0)
			return;

		final curAnimName = anims[curAnim].anim;
		var textPos = animsTxt.text.indexOf('$curAnimName: ');
		var breakPos = animsTxt.text.indexOf("\n", textPos);
		if (breakPos == -1)
			breakPos = animsTxt.text.length;

		final t = animsTxt.text.substring(textPos, breakPos);		
		// trace('curAnim: $curAnimName | newText: $t');
		animsTxt.applyMarkup(animsTxt.text.replace(t, '<l>$t<l>'), textMarkup);
	}

	inline function updateCharacterPositions()
	{
		final p = (!character?.isPlayer) || (character == null && predictCharacterIsNotPlayer(_char)) ? dadPosition : bfPosition;
		character.setPosition(p.x + character.position.x, p.y + character.position.y);
	}

	inline function predictCharacterIsNotPlayer(name:String)
	{
		return (name != "bf" && !name.startsWith("bf-") && !name.endsWith("-player") && !name.endsWith("-dead")) ||
				name.endsWith("-opponent") || name.startsWith("gf-") || name.endsWith("-gf") || name == "gf";
	}

	inline function newAnim(anim:String, name:String):AnimArray
	{
		return {
			offsets: [0, 0],
			loop: false,
			fps: 24,
			anim: anim,
			indices: [],
			name: name,
			loop_point: 0,
			animflip_x: false,
			animflip_y: false
		};
	}

	var characterList:Array<String> = [];
	function reloadCharacterDropDown()
	{
		characterList = Mods.mergeAllTextsNamed("data/characterList.txt", Paths.getSharedPath());
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), "characters/"))
			for (file in FileSystem.readDirectory(folder))
				if (file.toLowerCase().endsWith(".json"))
				{
					final charToCheck = file.substr(0, file.length - 5);
					if (!characterList.contains(charToCheck))
						characterList.push(charToCheck);
				}

		if (characterList.length == 0)
			characterList.push("");

		charDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true));
		charDropDown.selectedLabel = _char;
	}

	function reloadAnimationDropDown()
	{
		// Prevents crash
		final animList = (anims == null || anims.length == 0) ? ["NO ANIMATIONS"] : [for (anim in anims) anim.anim];
		animationDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(animList, true));
	}

	override function destroy()
	{
		FlxMouseEvent.globalManager.remove(healthIcon);
		super.destroy();
		helpSubstate.destroy();
		copiedOffset.put();
	}

	// save
	var _file:FileReference;
	function onSaveComplete(_):Void
	{
		if (_file == null)
			return;

		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onSaveCancel(_):Void
	{
		if (_file == null)
			return;

		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onSaveError(_):Void
	{
		if (_file == null)
			return;

		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}

	function saveCharacter()
	{
		if (_file != null)
			return;

		final json:CharacterFile = {
			animations:			character.animationsArray,
			image:				character.imageFile,
			scale:				character.jsonScale,
			sing_duration:		character.singDuration,
			healthicon:			character.healthIcon,

			position:			character.positionArray,
			camera_position:	character.cameraPosition,

			flip_x:				character.originalFlipX,
			flip_y:				character.originalFlipY,
			no_antialiasing:	character.noAntialiasing,
			healthbar_colors:	character.healthColorArray
		};

		final data = haxe.Json.stringify(json, optimizeJsonBox.checked ? null : "\t");

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, '$_char.json');
		}
	}
}

// and thats it
// no lengthy text groups, containing alot of FlxTexts
// no unnecessary background sprite with a graphic of an entire window
// just one simple substate with and ability to exit
// thats all
private class HelpSubstate extends flixel.FlxSubState
{
	inline static final HELP_TEXT = "CAMERA
\nE/Q - Camera Zoom In/Out
\nJ/K/L/I - Move Camera
\nR - Reset Camera Zoom
\n
\nCHARACTER
\nCtrl + R - Reset Current Offset
\nCtrl + C - Copy Current Offset
\nCtrl + V - Paste Copied Offset on Current Animation
\nCtrl + Z - Undo Last Paste or Reset
\nW/S - Previous/Next Animation
\nSpace - Replay Animation
\nArrow Keys/Mouse & Right Click - Move Offset
\nA/D - Frame Advance (Back/Forward)
\n
\nOTHER
\nF12 - Toggle Silhouettes
\nHold Shift - Move Offsets 10x faster and Camera 4x faster
\nHold Control - Move camera 4x slower";

	public function new()
	{
		super(0x99000000);

		final text = new FlxText(HELP_TEXT, 14);
		text.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1);
		text.alignment = CENTER;
		add(text.screenCenter());

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
		if (FlxG.renderTile)
			_bgSprite.cameras = cameras.copy();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		if (Controls.instance.BACK)
		{
			FlxG.state.persistentUpdate = true;
			close();
		}
	}
}
#end
