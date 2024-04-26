package states.editors;

#if !RELESE_BUILD_FR
import flixel.FlxSubState;
import flixel.util.FlxStringUtil;
import flash.geom.Rectangle;
import haxe.Json;
import haxe.io.Bytes;

import flixel.FlxObject;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.ui.FlxButton;

import flixel.util.FlxSort;
import lime.media.AudioBuffer;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;

import backend.Song;
import backend.Section;
import backend.StageData;

import objects.Note;
import objects.StrumNote;
import objects.HealthIcon;
import objects.AttachedSprite;
import objects.Character;

import objects.ui.UIInputTextAdvanced;
import objects.ui.DropDownAdvanced;

import substates.Prompt;

import backend.MusicBeatUIState;

#if sys
import flash.media.Sound;
import sys.FileSystem;
import sys.io.File;
#end

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)

class ChartingState extends MusicBeatUIState
{
	public static var noteTypeList:Array<String> = //Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	[
		'',
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'No Animation'
	];

	public static var GRID_SIZE = 40;
	static var CAM_OFFSET = 360;

	public static var vortex = false;
	public static var quantizations = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];
	public static var quantization:Int = 16;
	public static var curQuant = 3;

	@:allow(debug.DebugInfo)
	static var _song:Song;
	static var _queuedSong:Song;
	static var zoomList = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 24];

	public static var goToPlayState:Bool = false;
	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	public static var curSec = 0;
	public static var lastSection = 0;
	static var lastSong = "";

	public var ignoreWarnings = false;
	var curNoteTypes:Array<String> = [];
	var undos = [];
	var redos = [];
	var eventStuff:Array<Dynamic> =
	[
		['', "Nothing. Yep, that's right."],
		['Dadbattle Spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Philly Glow', "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."],
		['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
		['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
		['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		['Set Property', "Value 1: Variable name\nValue 2: New value\nNOTE: DOESN'T WORK WITH BOOLEANS!!! (nvmd fixed lmao)"],
		['Play Sound', "Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1"]
	];

	var _file:FileReference;
	var UI_box:FlxUITabMenu;
	var bpmTxt:FlxText;

	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var curSong:String = 'Test';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;
	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic> = null;

	var playbackSpeed:Float = 1;

	var vocals:FlxSound;
	var opponentVocals:FlxSound;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:UIInputTextAdvanced;
	var value2InputText:UIInputTextAdvanced;
	var currentSongName:String;

	var zoomTxt:FlxText;
	var curZoom:Int = 2;

	var blockPressWhileTypingOn:Array<UIInputTextAdvanced> = [];
	var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	var blockPressWhileScrolling:Array<DropDownAdvanced> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;

	public var mouseQuant:Bool = false;
	override function create()
	{
		Song.cache.clear();
		Song.exceptions.clear();
		persistentUpdate = true;
		PlayState.chartingMode = true;

		if (_song == null)
			_song = new Song();

		if (PlayState.SONG.song == null && _queuedSong?.song == null)
		{
			Difficulty.resetList();
			_song.load({
				song: 'Test',
				notes: [],
				events: [],
				bpm: 150.0,
				needsVoices: true,
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				speed: 1,
				stage: 'stage'
			});
			addSection();
		}
		else
			_song.copyFrom(_queuedSong?.song == null ? PlayState.SONG : _queuedSong);

		// Paths.clearMemory();
		if (_queuedSong != null)
			_queuedSong.reset();

		#if hxdiscord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, '-', ' '));
		#end

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;

		final bg = new FlxSprite(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		add(gridLayer = new FlxTypedGroup<FlxSprite>());
		add(waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(1, 1, 0x00FFFFFF));

		var eventIcon:FlxSprite = new FlxSprite(-GRID_SIZE - 5, -90, Paths.image('eventArrow'));
		eventIcon.antialiasing = ClientPrefs.data.antialiasing;
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(GRID_SIZE + 10, -100);
		rightIcon.setPosition(GRID_SIZE * 5.2, -100);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		// FlxG.mouse.visible = true;

		currentSongName = Paths.formatToSongPath(_song.song);
		loadSong();
		reloadGridLayer();
		Conductor.bpm = _song.bpm;
		Conductor.mapBPMChanges(_song);
		curSec = CoolUtil.boundInt(curSec, 0, _song.notes.length - 1);

		bpmTxt = new FlxText(1000, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		add(strumLine);

		quant = new AttachedSprite();
		quant.loadGraphic(Paths.image('chart_quant'), true, 27, 21);
		quant.frame = quant.frames.getByIndex(curQuant);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		for (i in 0...8){
			var note:StrumNote = new StrumNote(GRID_SIZE * (i+1), strumLine.y, i % 4, 0);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		dummyArrow.antialiasing = ClientPrefs.data.antialiasing;
		add(dummyArrow);

		UI_box = new FlxUITabMenu(null, [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
			{name: "Data", label: 'Data'}
		], true);

		UI_box.resize(300, 400);
		UI_box.x = 640 + GRID_SIZE * .5;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		var tipTextArray:String = "Press F1 for help";

		var tipText:FlxText = new FlxText(UI_box.x, UI_box.y + UI_box.height + 10, 0, tipTextArray, 14);
		tipText.font = Paths.font("vcr.ttf");
		tipText.scrollFactor.set();
		add(tipText);
		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		addDataUI();
		updateHeads();
		updateWaveform();

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		if(lastSong != currentSongName) changeSection();
		lastSong = currentSongName;

		zoomTxt = new FlxText(10, Main.fpsVar.visible ? 34 : 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.scrollFactor.set();
		add(zoomTxt);

		updateGrid();
		super.create();

		FlxG.camera.scroll.x = strumLine.x + CAM_OFFSET - FlxG.camera.width * 0.5;
		lime.app.Application.current.window.onDropFile.add(loadFromFile); // by Redar13
	}

	// original by redar13
	// safety edit by richtrash21
	inline function loadFromFile(file:String) 
	{
		final split = file.split("\\");
		final modFolder = split[split.length-4];
		// unload mod directory if json was opened from "assets/" or just "mods/"
		var root = Sys.getCwd();
		root = root.substring(root.lastIndexOf("\\")+1, root.lastIndexOf("/"));
		Mods.currentModDirectory = ((modFolder == "assets" || modFolder == "mods") && split[split.length-5] == root) ? null : modFolder;
		trace("(currentModDirectory: " + Mods.currentModDirectory + ' | modFolder: $modFolder | root: $root)');
		loadJson(file, true);
	}

	var check_mute_inst:FlxUICheckBox;
	var check_mute_vocals:FlxUICheckBox;
	var check_mute_vocals_opponent:FlxUICheckBox;
	var check_vortex:FlxUICheckBox;
	var check_warnings:FlxUICheckBox;
	var playSoundBf:FlxUICheckBox;
	var playSoundDad:FlxUICheckBox;
	var optimizeJsonBox:FlxUICheckBox;
	var UI_songTitle:UIInputTextAdvanced;
	var stageDropDown:DropDownAdvanced;
	#if FLX_PITCH var sliderRate:FlxUISlider; #end
	function addSongUI():Void
	{
		UI_songTitle = new UIInputTextAdvanced(10, 10, 70, _song.song, 8);
		UI_songTitle.callback = (t, a) -> _song.song = t;
		blockPressWhileTypingOn.push(UI_songTitle);

		var check_voices = new FlxUICheckBox(10, 25, null, null, "Has voice\ntrack(s)", 80);
		check_voices.checked = _song.needsVoices;
		check_voices.callback = function() _song.needsVoices = check_voices.checked;

		var saveButton:FlxButton = new FlxButton(110, 8, "Save Song", saveLevel);

		var reloadSong:FlxButton = new FlxButton(saveButton.x + 90, saveButton.y, "Reload Audio", function()
		{
			if (check_mute_inst != null)
				check_mute_inst.checked = false;
			if (check_mute_vocals != null)
				check_mute_vocals.checked = false;
			if (check_mute_vocals_opponent != null)
				check_mute_vocals_opponent.checked = false;

			currentSongName = Paths.formatToSongPath(UI_songTitle.text);
			loadSong();
			updateWaveform();
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			FlxG.sound.music.pause();
			if (vocals != null)
				vocals.pause();
			if (opponentVocals != null)
				opponentVocals.pause();
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function() loadJson(_song.song.toLowerCase()),
			null, ignoreWarnings));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			_song.load(Song.parseJSONshit(FlxG.save.data.autosave));
			FlxG.resetState();
		});

		var loadEventJson:FlxButton = new FlxButton(loadAutosaveBtn.x, loadAutosaveBtn.y + 30, 'Load Events', function()
		{
			final songName:String = Paths.formatToSongPath(_song.song);
			final file:String = Paths.json('$songName/events');
			#if sys
			if (#if MODS_ALLOWED FileSystem.exists(Paths.modsJson('$songName/events')) || #end FileSystem.exists(file))
			#else
			if (OpenFlAssets.exists(file))
			#end
			{
				clearEvents();
				final events = Song.loadFromJson('events', songName, false);
				_song.events = _song.events.concat(events.events);
				Song.__pool.push(events);
				changeSection(curSec);
			}
		});

		var saveEvents:FlxButton = new FlxButton(110, reloadSongJson.y, 'Save Events', saveEvents);

		optimizeJsonBox = new FlxUICheckBox(saveEvents.x, loadAutosaveBtn.y, null, null, "Optimize JSON?", 55);

		var clear_events:FlxButton = new FlxButton(320, 310, 'Clear events', () ->
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null,ignoreWarnings))
		);
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(320, clear_events.y + 30, 'Clear notes', () ->
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, () ->
			{
				for (sec in 0..._song.notes.length)
					while (_song.notes[sec].sectionNotes.length != 0)
						_song.notes[sec].sectionNotes.pop();
				updateGrid();
			}, null,ignoreWarnings));
		});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 400, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 2);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);
		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('characters/'), Paths.mods(Mods.currentModDirectory + '/characters/'), Paths.getSharedPath('characters/')];
		for(mod in Mods.getGlobalMods()) directories.push(Paths.mods(mod + '/characters/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath('characters/')];
		#end

		var tempArray:Array<String> = [];
		var characters:Array<String> = Mods.mergeAllTextsNamed('data/characterList.txt', Paths.getSharedPath());
		for (character in characters)
			if(character.trim().length > 0)
				tempArray.push(character);

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if(charToCheck.trim().length > 0 && !charToCheck.endsWith('-dead') && !tempArray.contains(charToCheck)) {
							tempArray.push(charToCheck);
							characters.push(charToCheck);
						}
					}
				}
			}
		}
		#end
		tempArray = [];

		var player1DropDown = new DropDownAdvanced(10, stepperSpeed.y + 45, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player1DropDown.selectedLabel = _song.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new DropDownAdvanced(player1DropDown.x, player1DropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true),
			function(character:String) {
				_song.gfVersion = characters[Std.parseInt(character)];
				updateHeads();
			});
		gfVersionDropDown.selectedLabel = _song.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new DropDownAdvanced(player1DropDown.x, gfVersionDropDown.y + 40, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true),
			function(character:String) {
				_song.player2 = characters[Std.parseInt(character)];
				updateHeads();
			});
		player2DropDown.selectedLabel = _song.player2;
		blockPressWhileScrolling.push(player2DropDown);

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('stages/'), Paths.mods(Mods.currentModDirectory + '/stages/'), Paths.getSharedPath('stages/')];
		for(mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath('stages/')];
		#end

		var stageFile:Array<String> = Mods.mergeAllTextsNamed('data/stageList.txt', Paths.getSharedPath());
		var stages:Array<String> = [];
		for (stage in stageFile) {
			if(stage.trim().length > 0) stages.push(stage);
			tempArray.push(stage);
		}
		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var stageToCheck:String = file.substr(0, file.length - 5);
						if(stageToCheck.trim().length > 0 && !tempArray.contains(stageToCheck)) {
							tempArray.push(stageToCheck);
							stages.push(stageToCheck);
						}
					}
				}
			}
		}
		#end

		if(stages.length < 1) stages.push('stage');

		stageDropDown = new DropDownAdvanced(player1DropDown.x + 140, player1DropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true),
			function(character:String) _song.stage = stages[Std.parseInt(character)]);
		stageDropDown.selectedLabel = _song.stage;
		blockPressWhileScrolling.push(stageDropDown);

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(saveEvents);
		tab_group_song.add(optimizeJsonBox);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(loadEventJson);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		tab_group_song.add(player2DropDown);
		tab_group_song.add(gfVersionDropDown);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(stageDropDown);

		UI_box.addGroup(tab_group_song);
	}

	var stepperBeats:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;

	var sectionToCopy:Int = 0;
	var notesCopied:Array<Dynamic>;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		check_mustHitSection = new FlxUICheckBox(10, 15, null, null, "Must hit section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = _song.notes[curSec].mustHitSection;

		check_gfSection = new FlxUICheckBox(10, check_mustHitSection.y + 22, null, null, "GF section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = _song.notes[curSec].gfSection;

		check_altAnim = new FlxUICheckBox(check_gfSection.x + 120, check_gfSection.y, null, null, "Alt Animation", 100);
		check_altAnim.checked = _song.notes[curSec].altAnim;

		stepperBeats = new FlxUINumericStepper(10, 100, 1, 4, 1, 7, 2);
		stepperBeats.value = getSectionBeats();
		stepperBeats.name = 'section_beats';
		blockPressWhileTypingOnStepper.push(stepperBeats);
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, stepperBeats.y + 30, null, null, 'Change BPM', 100);
		check_changeBPM.checked = _song.notes[curSec].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, check_changeBPM.y + 20, 1, Conductor.bpm, 0, 999, 1);
		stepperSectionBPM.value = check_changeBPM.checked ? _song.notes[curSec].bpm : Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);

		var check_eventsSec:FlxUICheckBox = null;
		var check_notesSec:FlxUICheckBox = null;
		var copyButton:FlxButton = new FlxButton(10, 190, "Copy Section", () ->
		{
			notesCopied.clearArray();
			sectionToCopy = curSec;
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				notesCopied.push(_song.notes[curSec].sectionNotes[i]);
			}

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in _song.events)
			{
				var strumTime:Float = event.strumTime;
				if (endThing > event.strumTime && event.strumTime >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [];
					for (i in 0...event.events.length)
					{
						var eventToPush = event.events[i];
						copiedEventArray.push([eventToPush.name, eventToPush.value1, eventToPush.value2]);
					}
					notesCopied.push([strumTime, -1, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(copyButton.x + 100, copyButton.y, "Paste Section", () ->
		{
			if (notesCopied == null || notesCopied.length == 0)
				return;

			var addToTime:Float = Conductor.stepCrochet * (getSectionBeats() * 4 * (curSec - sectionToCopy));

			for (note in notesCopied)
			{
				var copiedNote:NoteData;
				var newStrumTime:Float = note[0] + addToTime;
				if (note[1] == -1)
				{
					if (!check_eventsSec.checked)
						continue;

					var copiedEventArray:Array<EventData> = [];
					for (i in 0...note[2].length)
					{
						var eventToPush:Array<Dynamic> = note[2][i];
						copiedEventArray.push([eventToPush[0], eventToPush[1], eventToPush[2]]);
					}
					_song.events.push([newStrumTime, copiedEventArray]);
				}
				else
				{
					if (!check_notesSec.checked)
						continue;

					copiedNote = [newStrumTime, note[1], note[2], note[3]];
					// if (note[4] != null)
					//	copiedNote.push(note[4]);

					_song.notes[curSec].sectionNotes.push(copiedNote);
				}
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 100, pasteButton.y, "Clear", function()
		{
			if(check_notesSec.checked) _song.notes[curSec].sectionNotes = [];

			if(check_eventsSec.checked)
			{
				var i:Int = _song.events.length - 1;
				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);
				while(i > -1) {
					var event = _song.events[i];
					if (event != null && endThing > event.strumTime && event.strumTime >= startThing)
						_song.events.remove(event);

					--i;
				}
			}
			updateGrid();
			updateNoteUI();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;
		
		check_notesSec = new FlxUICheckBox(10, clearSectionButton.y + 25, null, null, "Notes", 100);
		check_notesSec.checked = true;
		check_eventsSec = new FlxUICheckBox(check_notesSec.x + 100, check_notesSec.y, null, null, "Events", 100);
		check_eventsSec.checked = true;

		var swapSection:FlxButton = new FlxButton(10, check_notesSec.y + 40, "Swap section", () ->
		{
			for (i in 0..._song.notes[curSec].sectionNotes.length)
			{
				var note = _song.notes[curSec].sectionNotes[i];
				note.noteData = (note.noteData + 4) % 8;
				_song.notes[curSec].sectionNotes[i] = note;
			}
			updateGrid();
		});

		var stepperCopy:FlxUINumericStepper = null;
		var copyLastButton:FlxButton = new FlxButton(10, swapSection.y + 30, "Copy last section", () ->
		{
			var value:Int = Std.int(stepperCopy.value);
			if (value == 0)
				return;

			var daSec = FlxMath.maxInt(curSec, value);
			for (note in _song.notes[daSec - value].sectionNotes)
			{
				_song.notes[daSec].sectionNotes.push([
					note.strumTime + Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value),
					note.noteData,
					note.sustainLength,
					note.noteType
				]);
			}

			var startThing:Float = sectionStartTime(-value);
			var endThing:Float = sectionStartTime(-value + 1);
			for (event in _song.events)
			{
				var strumTime:Float = event.strumTime;
				if (endThing > event.strumTime && event.strumTime >= startThing)
				{
					strumTime += Conductor.stepCrochet * (getSectionBeats(daSec) * 4 * value);
					var copiedEventArray = new Array<Array<String>>();
					for (i in 0...event.events.length)
					{
						var eventToPush = event.events[i];
						copiedEventArray.push([eventToPush.name, eventToPush.value1, eventToPush.value2]);
					}
					_song.events.push([strumTime, copiedEventArray]);
				}
			}
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();
		
		stepperCopy = new FlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		var duetButton:FlxButton = new FlxButton(10, copyLastButton.y + 45, "Duet Notes", function()
		{
			var duetNotes:Array<NoteData> = [
				for (note in _song.notes[curSec].sectionNotes)
					[note.strumTime, note.noteData + (note.noteData > 3 ? -4 : 4), note.sustainLength, note.noteType]
			];
			for (note in duetNotes)
				_song.notes[curSec].sectionNotes.push(note);
			updateGrid();
		});
		var mirrorButton:FlxButton = new FlxButton(duetButton.x + 100, duetButton.y, "Mirror Notes", ()->__mirror__notes());

		tab_group_section.add(new FlxText(stepperBeats.x, stepperBeats.y - 15, 0, 'Beats per Section:'));
		tab_group_section.add(stepperBeats);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(pasteButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(check_notesSec);
		tab_group_section.add(check_eventsSec);
		tab_group_section.add(swapSection);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyLastButton);
		tab_group_section.add(duetButton);
		tab_group_section.add(mirrorButton);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;
	var strumTimeInputText:UIInputTextAdvanced; //I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:DropDownAdvanced;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet * .5, 0, 0, Conductor.stepCrochet * 64);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new UIInputTextAdvanced(10, 65, 180, "0");
		tab_group_note.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		while (key < noteTypeList.length) {
			curNoteTypes.push(noteTypeList[key]);
			key++;
		}

		#if sys
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'custom_notetypes/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
			{
				var fileName:String = file.toLowerCase().trim();
				var wordLen:Int = 4; //length of word ".lua" and ".txt";
				if((#if LUA_ALLOWED fileName.endsWith('.lua') || #end
					#if HSCRIPT_ALLOWED (fileName.endsWith('.hx') && (wordLen = 3) == 3) || #end
					fileName.endsWith('.txt')) && fileName != 'readme.txt')
				{
					var fileToCheck:String = file.substr(0, file.length - wordLen);
					if(!curNoteTypes.contains(fileToCheck))
					{
						curNoteTypes.push(fileToCheck);
						key++;
					}
				}
			}
		#end


		var displayNameList:Array<String> = curNoteTypes.copy();
		for (i in 1...displayNameList.length)
			displayNameList[i] = i + '. ' + displayNameList[i];

		noteTypeDropDown = new DropDownAdvanced(10, 105, FlxUIDropDownMenu.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			currentType = Std.parseInt(character);
			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = curNoteTypes[currentType];
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		tab_group_note.add(new FlxText(10, 10, 0, 'Sustain length:'));
		tab_group_note.add(new FlxText(10, 50, 0, 'Strum time (in miliseconds):'));
		tab_group_note.add(new FlxText(10, 90, 0, 'Note type:'));
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(strumTimeInputText);
		tab_group_note.add(noteTypeDropDown);

		UI_box.addGroup(tab_group_note);
	}

	var eventDropDown:DropDownAdvanced;
	var descText:FlxText;
	var selectedEventText:FlxText;
	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Events';

		#if LUA_ALLOWED
		var eventPushedMap:Map<String, Bool> = [];
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('custom_events/'));
		directories.push(Paths.mods(Mods.currentModDirectory + '/custom_events/'));
		for(mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/custom_events/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if(FileSystem.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if(!eventPushedMap.exists(fileToCheck)) {
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, File.getContent(path)]);
						}
					}
				}
			}
		}
		eventPushedMap.clear();
		eventPushedMap = null;
		#end

		descText = new FlxText(20, 200, 0, eventStuff[0][0]);

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length)
			leEvents.push(eventStuff[i][0]);

		var text:FlxText = new FlxText(20, 30, 0, "Event:");
		tab_group_event.add(text);
		eventDropDown = new DropDownAdvanced(20, 50, FlxUIDropDownMenu.makeStrIdLabelArray(leEvents, true), function(pressed:String) {
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventStuff[selectedEvent][1];
			if (curSelectedNote != null && eventStuff != null) {
				if (curSelectedNote != null && curSelectedNote[2] == null)
					curSelectedNote[1][curEventSelected][0] = eventStuff[selectedEvent][0];

				updateGrid();
			}
		});
		blockPressWhileScrolling.push(eventDropDown);

		var text:FlxText = new FlxText(20, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new UIInputTextAdvanced(20, 110, 260, "");
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(20, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new UIInputTextAdvanced(20, 150, 260, "");
		blockPressWhileTypingOn.push(value2InputText);

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				if(curSelectedNote[1].length < 2)
				{
					_song.events.remove(cast curSelectedNote);
					curSelectedNote = null;
				}
				else
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if(curEventSelected < 0) curEventSelected = 0;
				else if(curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;

				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		tab_group_event.add(removeButton);

		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		tab_group_event.add(addButton);

		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', function() changeEventSelected(-1));
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		tab_group_event.add(moveLeftButton);

		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function() changeEventSelected(1));
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);

		UI_box.addGroup(tab_group_event);
	}

	function changeEventSelected(change:Int = 0)
	{
		if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
		{
			curEventSelected += change;
			if(curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if(curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	inline function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
			point.set(x, y);
	}

	static final __error__sounds = ["lego", "metal", "pikmin", "exe_scream", "tinky_winky_scream"];
	@:noCompletion extern inline function __error__sound()
	{
		FlxG.sound.play(Paths.sound(FlxG.random.getObject(__error__sounds))).pitch = FlxG.random.float(0.9, 1.1);
	}

	var metronome:FlxUICheckBox;
	var mouseScrollingQuant:FlxUICheckBox;
	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;
	var disableAutoScrolling:FlxUICheckBox;
	#if desktop
	var waveformUseInstrumental:FlxUICheckBox;
	var waveformUseVoices:FlxUICheckBox;
	var waveformUseOpponentVoices:FlxUICheckBox;
	#end
	var instVolume:FlxUINumericStepper;
	var voicesVolume:FlxUINumericStepper;
	var opponentVoicesVolume:FlxUINumericStepper;
	function addChartingUI() {
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Charting';

		#if desktop
		if (FlxG.save.data.chart_waveformInst == null) FlxG.save.data.chart_waveformInst = false;
		if (FlxG.save.data.chart_waveformVoices == null) FlxG.save.data.chart_waveformVoices = false;
		if (FlxG.save.data.chart_waveformOpponentVoices == null) FlxG.save.data.chart_waveformOpponentVoices = false;

		waveformUseInstrumental = new FlxUICheckBox(10, 90, null, null, "Waveform for Instrumental", 100);
		waveformUseInstrumental.checked = FlxG.save.data.chart_waveformInst;
		waveformUseInstrumental.callback = () ->
		{
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformOpponentVoices = waveformUseOpponentVoices.checked = false;
			updateWaveform();
		};

		waveformUseVoices = new FlxUICheckBox(waveformUseInstrumental.x + 120, waveformUseInstrumental.y, null, null, "Waveform for\nPlayer Voices", 100);
		waveformUseVoices.checked = FlxG.save.data.chart_waveformVoices;
		waveformUseVoices.callback = () ->
		{
			if (vocals == null)
			{
				__error__sound();
				FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked = false;
				return;
			}
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked = false;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked;
			FlxG.save.data.chart_waveformOpponentVoices = waveformUseOpponentVoices.checked = false;
			updateWaveform();
		};

		waveformUseOpponentVoices = new FlxUICheckBox(waveformUseVoices.x, waveformUseInstrumental.y + 30, null, null, "Waveform for\nOpponent Voices", 100);
		waveformUseOpponentVoices.checked = FlxG.save.data.chart_waveformOpponentVoices;
		waveformUseOpponentVoices.callback = () ->
		{
			if (opponentVocals == null)
			{
				__error__sound();
				FlxG.save.data.chart_waveformOpponentVoices = waveformUseOpponentVoices.checked = false;
				return;
			}
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked = false;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformOpponentVoices = waveformUseOpponentVoices.checked;
			updateWaveform();
		};
		#end

		check_mute_inst = new FlxUICheckBox(10, 290, null, null, "Mute\nInstrumental", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = () -> FlxG.sound.music.volume = check_mute_inst.checked ? 0 : (instVolume == null ? 1 : instVolume.value);
		mouseScrollingQuant = new FlxUICheckBox(10, 200, null, null, "Mouse Scrolling Quantization", 100);
		if (FlxG.save.data.mouseScrollingQuant == null) FlxG.save.data.mouseScrollingQuant = false;
		mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

		mouseScrollingQuant.callback = () ->
		{
			FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = FlxG.save.data.mouseScrollingQuant;
		};

		check_vortex = new FlxUICheckBox(10, 160, null, null, "Vortex Editor (BETA)", 100);
		if (FlxG.save.data.chart_vortex == null) FlxG.save.data.chart_vortex = false;
		check_vortex.checked = FlxG.save.data.chart_vortex;

		check_vortex.callback = () ->
		{
			FlxG.save.data.chart_vortex = check_vortex.checked;
			vortex = FlxG.save.data.chart_vortex;
			reloadGridLayer();
		};

		check_warnings = new FlxUICheckBox(10, 120, null, null, "Ignore Progress Warnings", 100);
		if (FlxG.save.data.ignoreWarnings == null) FlxG.save.data.ignoreWarnings = false;
		check_warnings.checked = FlxG.save.data.ignoreWarnings;

		check_warnings.callback = () ->
		{
			FlxG.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = FlxG.save.data.ignoreWarnings;
		};

		check_mute_vocals = new FlxUICheckBox(check_mute_inst.x, check_mute_inst.y + 30, null, null, "Mute Player\nVocals", 100);
		check_mute_vocals.checked = false;
		check_mute_vocals.callback = () ->
		{
			if (vocals == null)
			{
				__error__sound();
				check_mute_vocals.checked = false;
				return;
			}
			vocals.volume = check_mute_vocals.checked ? 0 : (voicesVolume?.value ?? 1);
		}

		check_mute_vocals_opponent = new FlxUICheckBox(check_mute_inst.x, check_mute_vocals.y + 30, null, null, "Mute Opponent\nVocals", 100);
		check_mute_vocals_opponent.checked = false;
		check_mute_vocals_opponent.callback = () ->
		{
			if (opponentVocals == null)
			{
				__error__sound();
				check_mute_vocals_opponent.checked = false;
				return;
			}
			opponentVocals.volume = check_mute_vocals_opponent.checked ? 0 : (opponentVoicesVolume?.value ?? 1);
		}

		playSoundBf = new FlxUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, null, null, "Boyfriend Notes Sound", 100,
			function() FlxG.save.data.chart_playSoundBf = playSoundBf.checked
		);
		if (FlxG.save.data.chart_playSoundBf == null) FlxG.save.data.chart_playSoundBf = false;
		playSoundBf.checked = FlxG.save.data.chart_playSoundBf;

		playSoundDad = new FlxUICheckBox(playSoundBf.x, check_mute_inst.y + 30, null, null, "Opponent Notes Sound", 100,
			function() FlxG.save.data.chart_playSoundDad = playSoundDad.checked
		);
		if (FlxG.save.data.chart_playSoundDad == null) FlxG.save.data.chart_playSoundDad = false;
		playSoundDad.checked = FlxG.save.data.chart_playSoundDad;

		metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100,
			function() FlxG.save.data.chart_metronome = metronome.checked
		);
		if (FlxG.save.data.chart_metronome == null) FlxG.save.data.chart_metronome = false;
		metronome.checked = FlxG.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, _song.bpm, 1, 1500, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 120, metronome.y, null, null, "Disable Autoscroll (Not Recommended)", 120,
			function() FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked
		);
		if (FlxG.save.data.chart_noAutoScroll == null) FlxG.save.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(metronomeStepper.x, 260, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		voicesVolume = new FlxUINumericStepper(instVolume.x + 90, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals?.volume ?? 1;
		voicesVolume.name = "voices_volume";
		blockPressWhileTypingOnStepper.push(voicesVolume);

		opponentVoicesVolume = new FlxUINumericStepper(voicesVolume.x + 90, instVolume.y, 0.1, 1, 0, 1, 1);
		opponentVoicesVolume.value = opponentVocals?.volume ?? 1;
		opponentVoicesVolume.name = "opponent_voices_volume";
		blockPressWhileTypingOnStepper.push(opponentVoicesVolume);
		
		#if FLX_PITCH
		sliderRate = new FlxUISlider(this, "playbackSpeed", 120, 150, 0.5, 3, 150, null, 5, FlxColor.WHITE, FlxColor.BLACK);
		sliderRate.nameLabel.text = "Playback Rate";
		tab_group_chart.add(sliderRate);
		#end

		if (vocals == null)
		{
			#if desktop
			waveformUseVoices.active = false;
			waveformUseVoices.alpha = 0.5;
			#end
			final text_field:FlxUIInputText = @:privateAccess cast voicesVolume.text_field;
			text_field.backgroundColor = FlxColor.GRAY.getLightened(0.5);
			text_field.fieldBorderColor = FlxColor.GRAY.getDarkened(0.5);
			voicesVolume.active = check_mute_vocals.active = false;
			voicesVolume.alpha = check_mute_vocals.alpha = 0.5;
		}
		
		if (opponentVocals == null)
		{
			#if desktop
			waveformUseOpponentVoices.active = false;
			waveformUseOpponentVoices.alpha = 0.5;
			#end
			final text_field:FlxUIInputText = @:privateAccess cast opponentVoicesVolume.text_field;
			text_field.backgroundColor = FlxColor.GRAY.getLightened(0.5);
			text_field.fieldBorderColor = FlxColor.GRAY.getDarkened(0.5);
			opponentVoicesVolume.active = check_mute_vocals_opponent.active = false;
			opponentVoicesVolume.alpha = check_mute_vocals_opponent.alpha = 0.5;
		}

		tab_group_chart.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, "BPM:"));
		tab_group_chart.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, "Offset (ms):"));
		tab_group_chart.add(new FlxText(instVolume.x, instVolume.y - 15, 0, "Inst Volume"));
		tab_group_chart.add(new FlxText(voicesVolume.x, voicesVolume.y - 25, 0, "Player Voices\nVolume"));
		tab_group_chart.add(new FlxText(opponentVoicesVolume.x, opponentVoicesVolume.y - 25, 0, "Opponent Voices\nVolume"));
		tab_group_chart.add(metronome);
		tab_group_chart.add(disableAutoScrolling);
		tab_group_chart.add(metronomeStepper);
		tab_group_chart.add(metronomeOffsetStepper);
		#if desktop
		tab_group_chart.add(waveformUseInstrumental);
		tab_group_chart.add(waveformUseVoices);
		tab_group_chart.add(waveformUseOpponentVoices);
		#end
		tab_group_chart.add(instVolume);
		tab_group_chart.add(voicesVolume);
		tab_group_chart.add(opponentVoicesVolume);
		tab_group_chart.add(check_mute_inst);
		tab_group_chart.add(check_mute_vocals);
		tab_group_chart.add(check_mute_vocals_opponent);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_warnings);
		tab_group_chart.add(playSoundBf);
		tab_group_chart.add(playSoundDad);
		UI_box.addGroup(tab_group_chart);
	}

	var gameOverCharacterInputText:UIInputTextAdvanced;
	var gameOverSoundInputText:UIInputTextAdvanced;
	var gameOverLoopInputText:UIInputTextAdvanced;
	var gameOverEndInputText:UIInputTextAdvanced;
	var noteSkinInputText:UIInputTextAdvanced;
	var noteSplashesInputText:UIInputTextAdvanced;
	function addDataUI()
	{
		var tab_group_data = new FlxUI(null, UI_box);
		tab_group_data.name = 'Data';


		gameOverCharacterInputText = new UIInputTextAdvanced(10, 25, 150, _song.gameOverChar != null ? _song.gameOverChar : '', 8);
		blockPressWhileTypingOn.push(gameOverCharacterInputText);
		
		gameOverSoundInputText = new UIInputTextAdvanced(10, gameOverCharacterInputText.y + 35, 150, _song.gameOverSound != null ? _song.gameOverSound : '', 8);
		blockPressWhileTypingOn.push(gameOverSoundInputText);
		
		gameOverLoopInputText = new UIInputTextAdvanced(10, gameOverSoundInputText.y + 35, 150, _song.gameOverLoop != null ? _song.gameOverLoop : '', 8);
		blockPressWhileTypingOn.push(gameOverLoopInputText);
		
		gameOverEndInputText = new UIInputTextAdvanced(10, gameOverLoopInputText.y + 35, 150, _song.gameOverEnd != null ? _song.gameOverEnd : '', 8);
		blockPressWhileTypingOn.push(gameOverEndInputText);


		var check_disableNoteRGB:FlxUICheckBox = new FlxUICheckBox(10, 170, null, null, "Disable Note RGB", 100);
		check_disableNoteRGB.checked = (_song.disableNoteRGB == true);
		check_disableNoteRGB.callback = function()
		{
			_song.disableNoteRGB = check_disableNoteRGB.checked;
			updateGrid();
		};


		noteSkinInputText = new UIInputTextAdvanced(10, 280, 150, _song.arrowSkin != null ? _song.arrowSkin : '', 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new UIInputTextAdvanced(noteSkinInputText.x, noteSkinInputText.y + 35, 150, _song.splashSkin != null ? _song.splashSkin : '', 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x + 5, noteSplashesInputText.y + 20, 'Change Notes', function() {
			_song.arrowSkin = noteSkinInputText.text;
			updateGrid();
		});

		
		tab_group_data.add(gameOverCharacterInputText);
		tab_group_data.add(gameOverSoundInputText);
		tab_group_data.add(gameOverLoopInputText);
		tab_group_data.add(gameOverEndInputText);

		tab_group_data.add(check_disableNoteRGB);
		
		tab_group_data.add(reloadNotesButton);
		tab_group_data.add(noteSkinInputText);
		tab_group_data.add(noteSplashesInputText);

		tab_group_data.add(new FlxText(gameOverCharacterInputText.x, gameOverCharacterInputText.y - 15, 0, 'Game Over Character Name:'));
		tab_group_data.add(new FlxText(gameOverSoundInputText.x, gameOverSoundInputText.y - 15, 0, 'Game Over Death Sound (sounds/):'));
		tab_group_data.add(new FlxText(gameOverLoopInputText.x, gameOverLoopInputText.y - 15, 0, 'Game Over Loop Music (music/):'));
		tab_group_data.add(new FlxText(gameOverEndInputText.x, gameOverEndInputText.y - 15, 0, 'Game Over Retry Music (music/):'));

		tab_group_data.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_data.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		UI_box.addGroup(tab_group_data);
	}

	function loadSong():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		final splitP1 = Paths.voices(currentSongName, "-Player") ?? Paths.voices(currentSongName);
		final splitP2 = Paths.voices(currentSongName, "-Opponent");

		if (splitP1 != null)
		{
			if (vocals == null)
			{
				vocals = FlxG.sound.load(splitP1);
				vocals.autoDestroy = false;
			}
			else
				vocals.loadEmbedded(splitP1);
		}

		if (splitP2 != null)
		{
			if (opponentVocals == null)
			{
				opponentVocals = FlxG.sound.load(splitP2);
				opponentVocals.autoDestroy = false;
			}
			else
				opponentVocals.loadEmbedded(splitP2);
		}

		var alpha = 1.0;
		var active = true;
		if (vocals == null)
		{
			if (FlxG.save.data.chart_waveformVoices)
				FlxG.save.data.chart_waveformVoices = false;

			alpha = 0.5;
			active = false;
		}

		#if desktop
		if (waveformUseVoices != null)
		{
			waveformUseVoices.alpha = alpha;
			waveformUseVoices.active = active;
		}
		#end
		if (check_mute_vocals != null)
		{
			check_mute_vocals.alpha = alpha;
			check_mute_vocals.active = active;
		}
		if (voicesVolume != null)
		{
			final text_field:FlxUIInputText = @:privateAccess cast voicesVolume.text_field;
			if (active)
			{
				text_field.backgroundColor = FlxColor.WHITE;
				text_field.fieldBorderColor = FlxColor.BLACK;
			}
			else
			{
				text_field.backgroundColor = FlxColor.GRAY.getLightened(0.5);
				text_field.fieldBorderColor = FlxColor.GRAY.getDarkened(0.5);
			}
			voicesVolume.alpha = alpha;
			voicesVolume.active = active;
		}

		alpha = 1.0;
		active = true;
		if (opponentVocals == null)
		{
			if (FlxG.save.data.chart_waveformOpponentVoices)
				FlxG.save.data.chart_waveformOpponentVoices = false;

			alpha = 0.5;
			active = false;
		}

		#if desktop
		if (waveformUseOpponentVoices != null)
		{
			waveformUseOpponentVoices.alpha = alpha;
			waveformUseOpponentVoices.active = active;
		}
		#end
		if (check_mute_vocals_opponent != null)
		{
			check_mute_vocals_opponent.alpha = alpha;
			check_mute_vocals_opponent.active = active;
		}
		if (opponentVoicesVolume != null)
		{
			final text_field:FlxUIInputText = @:privateAccess cast opponentVoicesVolume.text_field;
			if (active)
			{
				text_field.backgroundColor = FlxColor.WHITE;
				text_field.fieldBorderColor = FlxColor.BLACK;
			}
			else
			{
				text_field.backgroundColor = FlxColor.GRAY.getLightened(0.5);
				text_field.fieldBorderColor = FlxColor.GRAY.getDarkened(0.5);
			}
			opponentVoicesVolume.alpha = alpha;
			opponentVoicesVolume.active = active;
		}

		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;

		var curTime:Float = 0;
		if (_song.notes.length < 2) // First load ever
		{
			trace("first load ever!!");
			final t =  60 / _song.bpm * 4000;
			while (curTime < FlxG.sound.music.length)
			{
				addSection();
				curTime += t;
			}
		}
	}

	var playtesting:Bool = false;
	var playtestingTime:Float = 0;
	var playtestingOnComplete:Void->Void = null;
	override function closeSubState()
	{
		if (playtesting)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = playtestingTime;
			FlxG.sound.music.onComplete = playtestingOnComplete;
			FlxG.sound.music.volume = check_mute_inst?.checked ? 0 : (instVolume?.value ?? 1);

			if (vocals != null)
			{
				vocals.pause();
				vocals.time = playtestingTime;
				vocals.volume = check_mute_vocals?.checked ? 0 : (voicesVolume?.value ?? 1);
			}
			if (opponentVocals != null)
			{
				opponentVocals.pause();
				opponentVocals.time = playtestingTime;
				opponentVocals.volume = check_mute_vocals_opponent?.checked ? 0 : (opponentVoicesVolume?.value ?? 1);
			}

			#if hxdiscord_rpc
			// Updating Discord Rich Presence
			DiscordClient.changePresence("Chart Editor", StringTools.replace(_song.song, "-", " "));
			#end
		}
		persistentUpdate = true;
		super.closeSubState();
	}

	override public function openSubState(subState:FlxSubState)
	{
		persistentUpdate = false;
		super.openSubState(subState);
	}

	function musicOnComplete()
	{
		FlxG.sound.music.pause();
		Conductor.songPosition = 0;

		if (vocals != null)
		{
			vocals.pause();
			vocals.time = 0;
		}
		if (opponentVocals != null)
		{
			opponentVocals.pause();
			opponentVocals.time = 0;
		}

		changeSection();
		curSec = 0;
		updateGrid();
		updateSectionUI();

		if (vocals != null)
			vocals.play();
		if (opponentVocals != null)
			opponentVocals.play();
	}

	extern inline function generateSong()
	{
		FlxG.sound.playMusic(Paths.inst(currentSongName), check_mute_inst?.checked ? 0 : instVolume?.value ?? 0.6/*, false*/);
		FlxG.sound.music.autoDestroy = false;
		FlxG.sound.music.onComplete = musicOnComplete;
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must hit section':
					_song.notes[curSec].mustHitSection = check.checked;

					updateGrid();
					updateHeads();

				case 'GF section':
					_song.notes[curSec].gfSection = check.checked;

					updateGrid();
					updateHeads();

				case 'Change BPM':
					_song.notes[curSec].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
				case "Alt Animation":
					_song.notes[curSec].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var stepper:FlxUINumericStepper = cast sender;
			var val:Float = stepper.value;
			switch(stepper.name)
			{
				case 'section_beats':
					_song.notes[curSec].sectionBeats = val;
					reloadGridLayer();

				case 'song_speed':
					_song.speed = val;

				case 'song_bpm':
					_song.bpm = val;
					Conductor.mapBPMChanges(_song);
					Conductor.bpm = val;
					stepperSusLength.stepSize = Math.ceil(Conductor.stepCrochet * .5);
					updateGrid();

				case 'note_susLength':
					if(curSelectedNote != null && curSelectedNote[2] != null) {
						curSelectedNote[2] = val;
						updateGrid();
					}

				case 'section_bpm':
					_song.notes[curSec].bpm = val;
					updateGrid();

				case 'inst_volume':
					FlxG.sound.music.volume = (check_mute_inst?.checked) ? 0 : val;

				case 'voices_volume':
					if (vocals == null)
					{
						__error__sound();
						voicesVolume.value = 1;
					}
					else
						vocals.volume = (check_mute_vocals?.checked) ? 0 : val;

				case "opponent_voices_volume":
					if (opponentVocals == null)
					{
						__error__sound();
						opponentVoicesVolume.value = 1;
					}
					else
						opponentVocals.volume = (check_mute_vocals_opponent?.checked) ? 0 : val;
			}
		}
		else if(id == UIInputTextAdvanced.CHANGE_EVENT && (sender is UIInputTextAdvanced)) {
			if(sender == noteSplashesInputText) {
				_song.splashSkin = noteSplashesInputText.text;
			}
			else if(sender == noteSkinInputText) {
				_song.arrowSkin = noteSkinInputText.text;
			}
			else if(sender == gameOverCharacterInputText) {
				_song.gameOverChar = gameOverCharacterInputText.text;
			}
			else if(sender == gameOverSoundInputText) {
				_song.gameOverSound = gameOverSoundInputText.text;
			}
			else if(sender == gameOverLoopInputText) {
				_song.gameOverLoop = gameOverLoopInputText.text;
			}
			else if(sender == gameOverEndInputText) {
				_song.gameOverEnd = gameOverEndInputText.text;
			}
			else if(curSelectedNote != null)
			{
				if(sender == value1InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][1] = value1InputText.text;
						updateGrid();
					}
				}
				else if(sender == value2InputText) {
					if(curSelectedNote[1][curEventSelected] != null)
					{
						curSelectedNote[1][curEventSelected][2] = value2InputText.text;
						updateGrid();
					}
				}
				else if(sender == strumTimeInputText) {
					var value:Float = Std.parseFloat(strumTimeInputText.text);
					if(Math.isNaN(value)) value = 0;
					curSelectedNote[0] = value;
					updateGrid();
				}
			}
		}
		else if (id == FlxUISlider.CHANGE_EVENT && (sender is FlxUISlider))
		{
			switch (sender)
			{
				case 'playbackSpeed': playbackSpeed = FlxMath.bound(#if FLX_PITCH Std.int(sliderRate.value) #else 1.0 #end, 0.5, 3);
			}
		}
	}

	var updatedSection:Bool = false;

	function sectionStartTime(add:Int = 0):Float
	{
		var daBPM:Float = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSec + add)
		{
			if(_song.notes[i] != null)
			{
				if (_song.notes[i].changeBPM)
				{
					daBPM = _song.notes[i].bpm;
				}
				daPos += getSectionBeats(i) * (1000 * 60 / daBPM);
			}
		}
		return daPos;
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;
	override function update(elapsed:Float)
	{
		recalculateSteps();

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		// _song.song = UI_songTitle.text;

		strumLineUpdateY();
		for (i in 0...8) strumLineNotes.members[i].y = strumLine.y;

		//FlxG.mouse.visible = true;//cause reasons. trust me
		if(!disableAutoScrolling.checked) {
			if (Math.ceil(strumLine.y) >= gridBG.height)
			{
				if (_song.notes[curSec + 1] == null) addSection();
				changeSection(curSec + 1, false);
			} else if(strumLine.y < -10) {
				changeSection(curSec - 1, false);
			}
		}
		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		final onGrid:Bool = FlxMath.pointInCoordinates(FlxG.mouse.x, FlxG.mouse.y, gridBG.x, gridBG.y, gridBG.width, GRID_SIZE * getSectionBeats() * 4 * zoomList[curZoom]);
		if (onGrid)
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT) dummyArrow.y = FlxG.mouse.y;
			else
			{
				var gridmult = GRID_SIZE / (quantization * .0625); // / 16
				dummyArrow.y = Math.floor(FlxG.mouse.y / gridmult) * gridmult;
			}
		} else dummyArrow.visible = false;

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEachAlive(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
							selectNote(note);
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note);
							curSelectedNote[3] = curNoteTypes[currentType];
							updateGrid();
						}
						else
							deleteNote(note);
					}
				});
			}
			else
			{
				if (onGrid)
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}
		else if (FlxG.mouse.justPressedRight) // https://github.com/ShadowMario/FNF-PsychEngine/pull/13549
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
				curRenderedNotes.forEachAlive((note) -> if (FlxG.mouse.overlaps(note)) selectNote(note));
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				ClientPrefs.toggleVolumeKeys(false);
				blockInput = true;
				break;
			}
		}

		if(!blockInput) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				var leText:FlxUIInputText = cast (stepper.text_field, FlxUIInputText);
				if(leText.hasFocus) {
					ClientPrefs.toggleVolumeKeys(false);
					blockInput = true;
					break;
				}
			}
		}

		if(!blockInput) {
			ClientPrefs.toggleVolumeKeys(true);
			for (dropDownMenu in blockPressWhileScrolling) {
				if(dropDownMenu.dropPanel.visible) {
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.F1)
			{
				persistentUpdate = false;
				openSubState(new ChartingHelpSubstate());
			}
			else if (FlxG.keys.justPressed.ESCAPE)
			{
				persistentUpdate = false;
				FlxG.sound.music.pause();
				if (vocals != null)
					vocals.pause();
				if (opponentVocals != null)
					opponentVocals.pause();

				autosaveSong();
				PlayState.SONG.copyFrom(_song);
				playtesting = true;
				playtestingTime = Conductor.songPosition;
				playtestingOnComplete = FlxG.sound.music.onComplete;
				openSubState(new states.editors.EditorPlayState(playbackSpeed, vocals, opponentVocals));
			}
			else if (FlxG.keys.justPressed.ENTER)
			{
				persistentUpdate = false;
				autosaveSong();
				// FlxG.mouse.visible = false;
				FlxG.sound.music.stop();
				if (vocals != null)
					vocals.stop();
				if (opponentVocals != null)
					opponentVocals.stop();

				StageData.loadDirectory(_song);
				PlayState.SONG.copyFrom(_song);
				LoadingState.loadAndSwitchState(PlayState.new);
			}

			if (curSelectedNote != null && curSelectedNote[1] > -1)
			{
				final E = FlxG.keys.justPressed.E;
				if (E || FlxG.keys.justPressed.Q)
					changeNoteSustain(E ? Conductor.stepCrochet : -Conductor.stepCrochet);
			}


			if (FlxG.keys.justPressed.BACKSPACE) {
				FlxG.sound.music.onComplete = null;
				persistentUpdate = false;
				// Protect against lost data when quickly leaving the chart editor.
				autosaveSong();
				PlayState.chartingMode = false;
				FlxG.switchState(states.editors.MasterEditorMenu.new);
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				// FlxG.mouse.visible = false;
				return;
			}

			// так сталин велел!!!
			if (FlxG.keys.justPressed.H)
			{
				final sec = _song.notes[curSec];
				final check = !sec.mustHitSection;
				if (check_mustHitSection != null)
					check_mustHitSection.checked = check;
				sec.mustHitSection = check;
				updateGrid();
				updateHeads();
			}
			if (FlxG.keys.justPressed.M)
			{
				__mirror__notes();
			}

			if (FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL)
				undo();

			if (FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL)
			{
				--curZoom;
				updateZoom();
			}
			if (FlxG.keys.justPressed.X && curZoom < zoomList.length-1)
			{
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB) // лмао кекв
				UI_box.selected_tab = FlxMath.wrap(UI_box.selected_tab + (FlxG.keys.pressed.SHIFT ? -1 : 1), 0, UI_box.numTabs-1);

			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if (vocals != null)
						vocals.pause();
					if (opponentVocals != null)
						opponentVocals.pause();
				}
				else
				{
					FlxG.sound.music.play();
					if (vocals != null)
					{
						vocals.play();
						// vocals.pause();
						vocals.time = FlxG.sound.music.time;
						// vocals.play();
					}
					if (opponentVocals != null)
					{
						opponentVocals.play();
						// opponentVocals.pause();
						opponentVocals.time = FlxG.sound.music.time;
						// opponentVocals.play();
					}
				}
			}

			if (!FlxG.keys.pressed.ALT && FlxG.keys.justPressed.R)
				resetSection(FlxG.keys.pressed.SHIFT);

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				if (!mouseQuant)
					FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * .8);
				else
				{
					var snap = quantization * .25;
					var increase = 1 / snap;
					FlxG.sound.music.time = Conductor.beatToSeconds(CoolUtil.quantize(curDecBeat, snap) + (FlxG.mouse.wheel > 0 ? -increase : increase));
				}
				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				if (opponentVocals != null)
				{
					opponentVocals.pause();
					opponentVocals.time = FlxG.sound.music.time;
				}
			}

			//ARROW VORTEX SHIT NO DEADASS



			final W = FlxG.keys.pressed.W;
			if (W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();
				final daTime = 700 * FlxG.elapsed * (FlxG.keys.pressed.CONTROL ? 0.25 : FlxG.keys.pressed.SHIFT ? 4 : 1);
				FlxG.sound.music.time += W ? -daTime : daTime;

				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				if (opponentVocals != null)
				{
					opponentVocals.pause();
					opponentVocals.time = FlxG.sound.music.time;
				}
			}

			if(!vortex)
			{
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();
					updateCurStep();
					final snap = quantization * .25;
					final increase = 1 / snap;
					FlxG.sound.music.time = Conductor.beatToSeconds(CoolUtil.quantize(curDecBeat, snap) + (FlxG.keys.pressed.UP ? -increase : increase));
				}
			}

			final style = FlxG.keys.pressed.SHIFT ? 3 : currentType;
			final conductorTime = Conductor.songPosition; //+ sectionStartTime();Conductor.songPosition / Conductor.stepCrochet;

			//AWW YOU MADE IT SEXY <3333 THX SHADMAR

			if (!blockInput)
			{
				final add:Int = FlxG.keys.justPressed.RIGHT ? 1 : FlxG.keys.justPressed.LEFT ? -1 : 0;
				if (add != 0)
				{
					curQuant = FlxMath.wrap(curQuant + add, 0, quantizations.length-1);
					quantization = quantizations[curQuant];
					quant.frame = quant.frames.getByIndex(FlxMath.minInt(curQuant, quant.frames.numFrames-4));
				}
			}
			if (vortex && !blockInput)
			{
				final controlArray:Array<Bool> = [FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
											   FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT];

				if(controlArray.contains(true))
					for (i in 0...controlArray.length)
						if(controlArray[i])
							doANoteThing(conductorTime, i, style);

				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN  )
				{
					FlxG.sound.music.pause();
					updateCurStep();

					final beat:Float = curDecBeat;
					final snap:Float = quantization * .25;
					final increase:Float = 1 / snap;

					final fuck:Float = CoolUtil.quantize(beat, snap) + (FlxG.keys.pressed.UP ? -increase : increase);
					final feces:Float = Conductor.beatToSeconds(fuck);
					FlxTween.tween(FlxG.sound.music, {time:feces}, 0.1, {ease:FlxEase.circOut});
					if (vocals != null)
					{
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
					}
					if (opponentVocals != null)
					{
						opponentVocals.pause();
						opponentVocals.time = FlxG.sound.music.time;
					}

					final dastrum = curSelectedNote == null ? 0 : curSelectedNote[0];
					final secStart:Float = sectionStartTime();
					final datime = (feces - secStart) - (dastrum - secStart); // idk math find out why it doesn't work on any other section other than 0
					if (curSelectedNote != null)
					{
						final controlArray:Array<Bool> = [FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
													   FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT];

						if(controlArray.contains(true))
						{
							for (i in 0...controlArray.length)
								if(controlArray[i])
									if(curSelectedNote[1] == i) curSelectedNote[2] += datime - curSelectedNote[2] - Conductor.stepCrochet;

							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			final shiftThing:Int = FlxG.keys.pressed.SHIFT ? 4 : 1;

			if (FlxG.keys.justPressed.D) changeSection(curSec + shiftThing);
			if (FlxG.keys.justPressed.A) changeSection(curSec <= 0 ? _song.notes.length-1 : curSec - shiftThing);
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			for (i in 0...blockPressWhileTypingOn.length)
				if(blockPressWhileTypingOn[i].hasFocus)
					blockPressWhileTypingOn[i].hasFocus = false;
		}

		strumLineNotes.visible = quant.visible = vortex;

		if(FlxG.sound.music.time < 0)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length)
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;
		strumLineUpdateY();
		for (i in 0...8)
		{
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		#if FLX_PITCH
		// PLAYBACK SPEED CONTROLS //
		final holdingShift = FlxG.keys.pressed.SHIFT;
		final holdingLB = FlxG.keys.pressed.LBRACKET;
		final holdingRB = FlxG.keys.pressed.RBRACKET;
		final pressedLB = FlxG.keys.justPressed.LBRACKET;
		final pressedRB = FlxG.keys.justPressed.RBRACKET;

		if (!holdingShift && pressedLB || holdingShift && holdingLB) playbackSpeed -= 0.01;
		if (!holdingShift && pressedRB || holdingShift && holdingRB) playbackSpeed += 0.01;
		if (FlxG.keys.pressed.ALT && (pressedLB || pressedRB || holdingLB || holdingRB)) playbackSpeed = 1;

		FlxG.sound.music.pitch = playbackSpeed;
		if (vocals != null)
			vocals.pitch = playbackSpeed;
		if (opponentVocals != null)
			opponentVocals.pitch = playbackSpeed;
		#end

		inline function fromatFloat(f:Float):String
		{
			var s = FlxMath.roundDecimal(f, 2).string();
			var dot = s.indexOf(".");
			if (dot == -1)
			{
				dot = s.length;
				s += ".";
			}
			while (s.substr(dot+1, 2).length < 2)
				s += "0";
			return s;
		}

		final curTime:Float = Conductor.songPosition * .001;
		final maxTime:Float = FlxG.sound.music.length * .001;
		bpmTxt.text = // fromated time yaayyy!!!
		FlxStringUtil.formatTime(curTime, true) + " / " + FlxStringUtil.formatTime(maxTime, true) +
		"\n[" + fromatFloat(curTime) + " / " + fromatFloat(maxTime) + "]\n" +
		"\nSection: " + curSec +
		"\nBeat: " + fromatFloat(curDecBeat) +
		"\nStep: " + fromatFloat(curDecStep) +
		"\n\nBeat Snap: " + quantization + "th";

		final playedSound:Array<Bool> = [false, false, false, false]; //Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive(function(note:Note) {
			note.alpha = 1;
			if(curSelectedNote != null) {
				var noteDataToCheck:Int = note.noteData;
				if(noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;

				if (curSelectedNote[0] == note.strumTime && ((curSelectedNote[2] == null && noteDataToCheck < 0) || (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
				{
					colorSine += elapsed;
					final colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999); //Alpha can't be 100% or the color won't be updated for some reason, guess i will die
				}
			}

			if(note.strumTime <= Conductor.songPosition) {
				note.alpha = 0.4;
				if(note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1) {
					var data:Int = note.noteData % 4;
					var noteDataToCheck:Int = note.noteData;
					if(noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
						strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
						strumLineNotes.members[noteDataToCheck].resetAnim = ((note.sustainLength * .001) + 0.15) / playbackSpeed;
					if(!playedSound[data]) {
						if(note.hitsoundChartEditor && ((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress)))
						{
							final soundToPlay = _song.player1 == 'gf' ? 'GF_' + Std.string(data + 1) : note.hitsound; //Easter egg
							FlxG.sound.play(Paths.sound(soundToPlay)).pan = note.noteData < 4? -0.3 : 0.3; //would be coolio
							playedSound[data] = true;
						}

						data = note.noteData;
						if(note.mustPress != _song.notes[curSec].mustHitSection)
						{
							data += 4;
						}
					}
				}
			}
		});

		if(metronome.checked && lastConductorPos != Conductor.songPosition) {
			final metroInterval:Float = 60 / metronomeStepper.value;
			final metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) * .001);
			final lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) * .001);
			if(metroStep != lastMetroStep) {
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
				//trace('Ticked');
			}
		}
		lastConductorPos = Conductor.songPosition;
		super.update(elapsed);
	}

	extern inline function __mirror__notes()
	{
		for (note in _song.notes[curSec].sectionNotes)
			note.noteData = 3 - (note.noteData % 4) + (note.noteData > 3 ? 4 : 0);
		updateGrid();
	}

	function updateZoom()
	{
		final daZoom = zoomList[curZoom];
		zoomTxt.text = "Zoom: " + (daZoom < 1 ? Math.round(1 / daZoom) + " / 1" : '1 / $daZoom');
		reloadGridLayer();
	}

	override function destroy()
	{
		while (Note.globalRgbShaders.length != 0)
			Note.globalRgbShaders.pop();

		if (vocals != null)
		{
			vocals.autoDestroy = true;
			vocals.stop();
			vocals = null;
		}
		if (opponentVocals != null)
		{
			opponentVocals.autoDestroy = true;
			opponentVocals.stop();
			opponentVocals = null;
		}
		backend.NoteTypesConfig.clearNoteTypesData();
		lime.app.Application.current.window.onDropFile.remove(loadFromFile);
		super.destroy();
	}

	var lastSecBeats:Float = 0;
	var lastSecBeatsNext:Float = 0;
	var columns:Int = 9;
	function reloadGridLayer() {
		gridLayer.clear();
		gridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats() * 4 * zoomList[curZoom]));
		gridBG.antialiasing = false;
		gridBG.scale.set(GRID_SIZE, GRID_SIZE);
		gridBG.updateHitbox();

		#if desktop
		if (FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformOpponentVoices)
			updateWaveform();
		#end

		var leHeight:Int = Std.int(gridBG.height);
		var foundNextSec:Bool = false;
		if(sectionStartTime(1) <= FlxG.sound.music.length)
		{
			nextGridBG = FlxGridOverlay.create(1, 1, columns, Std.int(getSectionBeats(curSec + 1) * 4 * zoomList[curZoom]));
			nextGridBG.antialiasing = false;
			nextGridBG.scale.set(GRID_SIZE, GRID_SIZE);
			nextGridBG.updateHitbox();
			leHeight = Std.int(gridBG.height + nextGridBG.height);
			foundNextSec = true;
		}
		else nextGridBG = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
		nextGridBG.y = gridBG.height;
		
		gridLayer.add(nextGridBG);
		gridLayer.add(gridBG);

		if(foundNextSec)
		{
			final gridBlack:FlxSprite = new FlxSprite(0, gridBG.height).makeGraphic(1, 1, FlxColor.BLACK);
			gridBlack.setGraphicSize(Std.int(GRID_SIZE * 9), Std.int(nextGridBG.height));
			gridBlack.updateHitbox();
			gridBlack.antialiasing = false;
			gridBlack.alpha = 0.4;
			gridLayer.add(gridBlack);
		}

		final gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + gridBG.width - (GRID_SIZE * 4)).makeGraphic(1, 1, FlxColor.BLACK);
		gridBlackLine.setGraphicSize(2, leHeight);
		gridBlackLine.updateHitbox();
		gridBlackLine.antialiasing = false;
		gridLayer.add(gridBlackLine);

		for (i in 1...4) {
			final beatsep:FlxSprite = new FlxSprite(gridBG.x, (GRID_SIZE * (4 * curZoom)) * i).makeGraphic(1, 1, 0x44FF0000);
			beatsep.scale.x = gridBG.width;
			beatsep.updateHitbox();
			if(vortex) gridLayer.add(beatsep);
		}

		final gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE).makeGraphic(1, 1, FlxColor.BLACK);
		gridBlackLine.setGraphicSize(2, leHeight);
		gridBlackLine.updateHitbox();
		gridBlackLine.antialiasing = false;
		gridLayer.add(gridBlackLine);
		updateGrid();

		lastSecBeats = getSectionBeats();
		(sectionStartTime(1) > FlxG.sound.music.length) ? lastSecBeatsNext = 0 : getSectionBeats(curSec + 1);
	}

	extern inline function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) / zoomList[curZoom] % (Conductor.stepCrochet * 16)) / (getSectionBeats() * .25);
		FlxG.camera.scroll.y = strumLine.y - FlxG.camera.height * 0.5;
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];

	var lastWaveformHeight:Int = 0;
	function updateWaveform() {
		#if desktop
		if(waveformPrinted) {
			final width:Int = Std.int(GRID_SIZE * 8);
			final height:Int = Std.int(gridBG.height);
			if(lastWaveformHeight != height && waveformSprite.pixels != null)
			{
				waveformSprite.pixels.dispose();
				waveformSprite.pixels.disposeImage();
				waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
				lastWaveformHeight = height;
			}
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if(!(FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices || FlxG.save.data.chart_waveformOpponentVoices)) {
			//trace('Epic fail on the waveform lol');
			return;
		}

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		final steps:Int = Math.round(getSectionBeats() * 4);
		final st:Float = sectionStartTime();
		final et:Float = st + (Conductor.stepCrochet * steps);

		final sound = if (FlxG.save.data.chart_waveformOpponentVoices)
						  opponentVocals;
					  else if (FlxG.save.data.chart_waveformVoices)
						  vocals;
					  else
						  FlxG.sound.music;

		if (sound._sound != null && sound._sound.__buffer != null)
			wavData = waveformData(
				sound._sound.__buffer,
				sound._sound.__buffer.data.toBytes(),
				st,
				et,
				1,
				wavData,
				Std.int(gridBG.height)
			);

		// Draws
		final gSize:Int = Std.int(GRID_SIZE * 8);
		final hSize:Int = Std.int(gSize * .5);

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		final size:Float = 1;

		final leftLength:Int = (
			wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length
		);

		final rightLength:Int = (
			wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length
		);

		final length:Int = leftLength > rightLength ? leftLength : rightLength;

		for (i in 0...length) {
			final shit = gSize * 0.8928571428571428; // / 1.12
			lmin = FlxMath.bound(((i < wavData[0][0].length && i >= 0) ? wavData[0][0][i] * shit : 0), -hSize, hSize) * .5;
			lmax = FlxMath.bound(((i < wavData[0][1].length && i >= 0) ? wavData[0][1][i] * shit : 0), -hSize, hSize) * .5;

			rmin = FlxMath.bound(((i < wavData[1][0].length && i >= 0) ? wavData[1][0][i] * shit : 0), -hSize, hSize) * .5;
			rmax = FlxMath.bound(((i < wavData[1][1].length && i >= 0) ? wavData[1][1][i] * shit : 0), -hSize, hSize) * .5;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		final khz:Float = (buffer.sampleRate * .001);
		final channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		final samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		final samplesPerRow:Float = samples / steps;
		final samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 * .5) byte -= 65535;

				var sample:Float = (byte * .000015259021896696422); // / 65535

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 * .5) byte -= 65535;

					sample = (byte * .000015259021896696422); // / 65535

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				final lRMin:Float = Math.abs(lmin) * multiply;
				final lRMax:Float = lmax * multiply;

				final rRMin:Float = Math.abs(rmin) * multiply;
				final rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2) {
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else {
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += Math.ceil(value);
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	function recalculateSteps(add:Float = 0)
	{
		var lastChange:BPMChangeEvent = null;
		for (i in 0...Conductor.bpmChangeMap.length)
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];

		if (lastChange == null)
			lastChange = {stepTime: 0, songTime: 0, bpm: 0};
		curDecStep = lastChange.stepTime + (FlxG.sound.music.time - lastChange.songTime + add) / Conductor.stepCrochet;
		curStep = Math.floor(curDecStep);
		updateBeat();
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSec = 0;
		}

		if (vocals != null)
		{
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}
		if (opponentVocals != null)
		{
			opponentVocals.pause();
			opponentVocals.time = FlxG.sound.music.time;
		}
		updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		var waveformChanged:Bool = false;
		if (_song.notes[sec] != null)
		{
			curSec = sec;
			if (updateMusic)
			{
				FlxG.sound.music.pause();
				FlxG.sound.music.time = sectionStartTime();
				if (vocals != null)
				{
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				if (opponentVocals != null)
				{
					opponentVocals.pause();
					opponentVocals.time = FlxG.sound.music.time;
				}
				updateCurStep();
			}

			if (getSectionBeats() != lastSecBeats || (sectionStartTime(1) > FlxG.sound.music.length ? 0 : getSectionBeats(curSec + 1)) != lastSecBeatsNext)
			{
				reloadGridLayer();
				waveformChanged = true;
			}
			else
				updateGrid();

			updateSectionUI();
		}
		else
			changeSection();

		Conductor.songPosition = FlxG.sound.music.time;
		if (!waveformChanged)
			updateWaveform();
	}

	inline function updateSectionUI():Void
	{
		final sec = _song.notes[curSec];
		stepperBeats.value = getSectionBeats();
		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		updateHeads();
	}

	inline function updateHeads():Void
	{
		var healthIconP1 = loadHealthIconFromCharacter(_song.player2);
		var healthIconP2 = loadHealthIconFromCharacter(_song.player1);
		if (_song.notes[curSec].mustHitSection)
		{
			final tmp = healthIconP1;
			healthIconP1 = healthIconP2;
			healthIconP2 = tmp;
		}
		if (_song.notes[curSec].gfSection)
			healthIconP1 = _song.gfVersion.isNullOrEmpty() ? "gf" : _song.gfVersion;

		leftIcon.changeIcon(healthIconP1);
		rightIcon.changeIcon(healthIconP2);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);
	}

	inline function loadHealthIconFromCharacter(char:String):String
	{
		return Character.resolveCharacterData(char).healthicon;
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null) {
			if(curSelectedNote[2] != null) {
				stepperSusLength.value = curSelectedNote[2];
				if(curSelectedNote[3] != null) {
					currentType = curNoteTypes.indexOf(curSelectedNote[3]);
					noteTypeDropDown.selectedLabel = currentType > 0 ? '${currentType}. ${curSelectedNote[3]}' : '';
				}
			} else {
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if(selected > 0 && selected < eventStuff.length)
					descText.text = eventStuff[selected][1];

				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
			}
			strumTimeInputText.text = '' + curSelectedNote[0];
		}
	}

	function updateGrid():Void
	{
		curRenderedNotes.forEachAlive(function(spr:Note) spr.destroy());
		curRenderedNotes.clear();
		curRenderedSustains.forEachAlive(function(spr:FlxSprite) spr.destroy());
		curRenderedSustains.clear();
		curRenderedNoteType.forEachAlive(function(spr:FlxText) spr.destroy());
		curRenderedNoteType.clear();
		nextRenderedNotes.forEachAlive(function(spr:Note) spr.destroy());
		nextRenderedNotes.clear();
		nextRenderedSustains.forEachAlive(function(spr:FlxSprite) spr.destroy());
		nextRenderedSustains.clear();

		if (_song.notes[curSec].changeBPM && _song.notes[curSec].bpm > 0)
		{
			Conductor.bpm = _song.notes[curSec].bpm;
			//trace('BPM of this section:');
		}
		else
		{
			// get last bpm
			var daBPM:Float = _song.bpm;
			for (i in 0...curSec)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.bpm = daBPM;
		}

		// CURRENT SECTION
		final beats:Float = getSectionBeats();
		var i:Array<Dynamic>;
		for (n in _song.notes[curSec].sectionNotes)
		{
			i = n;
			final note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note, beats));
			}

			if(i[3] != null && note.noteType != null && note.noteType.length > 0) {
				final typeInt:Int = curNoteTypes.indexOf(i[3]);
				final theType:String = typeInt < 0 ? '?' : '$typeInt';

				final daText:AttachedFlxText = new AttachedFlxText(0, 0, 100, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -32;
				daText.yAdd = 6;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
			note.mustPress = _song.notes[curSec].mustHitSection;
			if(i[1] > 3) note.mustPress = !note.mustPress;
		}

		// CURRENT EVENTS
		final startThing:Float = sectionStartTime();
		final endThing:Float = sectionStartTime(1);
		for (n in _song.events)
		{
			i = n;
			if(endThing > i[0] && i[0] >= startThing)
			{
				final note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);

				final text:String = note.eventLength > 1
					? note.eventLength + ' Events:\n' + note.eventName
					: 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: ' + note.eventVal2;

					final daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -410;
				daText.borderSize = 1;
				if(note.eventLength > 1) daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
				//trace('test: ' + i[0], 'startThing: ' + startThing, 'endThing: ' + endThing);
			}
		}

		// NEXT SECTION
		final beats:Float = getSectionBeats(1);
		if(curSec < _song.notes.length-1) {
			for (i in _song.notes[curSec+1].sectionNotes)
			{
				final note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
					nextRenderedSustains.add(setupSusNote(note, beats));
			}
		}

		// NEXT EVENTS
		final startThing:Float = sectionStartTime(1);
		final endThing:Float = sectionStartTime(2);
		for (n in _song.events)
		{
			i = n;
			if(endThing > i[0] && i[0] >= startThing)
			{
				final note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var daNoteInfo = i[1];
		final daStrumTime = i[0];
		final daSus:Dynamic = i[2];

		final note:Note = new Note(daStrumTime, daNoteInfo % 4, null, null, true);
		if(daSus != null) { //Common note
			if(!Std.isOfType(i[3], String)) //Convert old note type to new note type format
				i[3] = curNoteTypes[i[3]];
			if(i.length > 3 && (i[3] == null || i[3].length < 1))
				i.remove(i[3]);
			note.sustainLength = daSus;
			note.noteType = i[3];
		} else { //Event note
			note.loadGraphic(Paths.image('eventArrow'));
			note.rgbShader.enabled = false;
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if(i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.noteData = -1;
			daNoteInfo = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
		if(isNextSection && _song.notes[curSec].mustHitSection != _song.notes[curSec+1].mustHitSection) {
			if(daNoteInfo > 3)		note.x -= GRID_SIZE * 4;
			else if(daSus != null)	note.x += GRID_SIZE * 4;
		}

		final beats:Float = getSectionBeats(isNextSection ? 1 : 0);
		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime(), beats);
		if(note.y < -150) note.y = -150;
		return note;
	}

	function getEventName(names:Array<Dynamic>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if(addedOne) retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	function setupSusNote(note:Note, beats:Float):FlxSprite {
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet * 16, 0, GRID_SIZE * 16 * zoomList[curZoom]) + (GRID_SIZE * zoomList[curZoom]) - GRID_SIZE * .5);
		final minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] * .5) + GRID_SIZE * .5);
		if(height < minHeight) height = minHeight;
		return new FlxSprite(note.x + (GRID_SIZE * 0.5) - 4, note.y + GRID_SIZE * .5).makeGraphic(8, height < 1 ? 1 : height); //Prevents error of invalid height
	}

	private function addSection(sectionBeats:Float = 4):Void
	{
		_song.notes.push(new Section({
			sectionBeats: sectionBeats,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			// typeOfSection: 0,
			altAnim: false
		}));
	}

	function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;

		if(noteDataToCheck > -1)
		{
			if(note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;
			var i:Array<Dynamic>;
			for (n in _song.notes[curSec].sectionNotes)
			{
				i = n;
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in _song.events)
			{
				if(i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
					break;
				}
			}
		}
		changeEventSelected();

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;
		if(noteDataToCheck > -1 && note.mustPress != _song.notes[curSec].mustHitSection) noteDataToCheck += 4;

		if(note.noteData > -1) //Normal Notes
		{
			for (i in _song.notes[curSec].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					if(i == curSelectedNote) curSelectedNote = null;
					_song.notes[curSec].sectionNotes.remove(i);
					break;
				}
			}
		}
		else //Events
		{
			for (i in _song.events)
			{
				if(i[0] == note.strumTime)
				{
					if(i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					_song.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	public function doANoteThing(cs, d, style){
		var delnote = false;
		if(strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1,strumLine.y+1)) && note.noteData == d%4)
				{
					if(!delnote) deleteNote(note);
					delnote = true;
				}
			});
		}

		if (!delnote) addNote(cs, d, style);
	}
	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length) _song.notes[daSection].sectionNotes = [];
		updateGrid();
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null):Void
	{
		var noteStrum = getStrumTime(dummyArrow.y * (getSectionBeats() * .25), false) + sectionStartTime();
		var noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var daType = currentType;
		final noteSus = 0;

		if (strum != null) noteStrum = strum;
		if (data != null) noteData = data;
		if (type != null) daType = type;

		if(noteData > -1)
		{
			_song.notes[curSec].sectionNotes.push([noteStrum, noteData, noteSus, curNoteTypes[daType]]);
			curSelectedNote = _song.notes[curSec].sectionNotes[_song.notes[curSec].sectionNotes.length - 1];
		}
		else
		{
			final event = eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
			final text1 = value1InputText.text;
			final text2 = value2InputText.text;
			_song.events.push([noteStrum, [[event, text1, text2]]]);
			curSelectedNote = _song.events[_song.events.length - 1];
			curEventSelected = 0;
		}
		changeEventSelected();

		if (FlxG.keys.pressed.CONTROL && noteData > -1) _song.notes[curSec].sectionNotes.push([noteStrum, (noteData + 4) % 8, noteSus, curNoteTypes[daType]]);

		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();
	}

	// will figure this out l8r
	function redo()
	{
		//_song = redos[curRedoIndex];
	}

	function undo()
	{
		//redos.push(_song);
		undos.pop();
		//_song.notes = undos[undos.length - 1];
		///trace(_song.notes);
		//updateGrid();
	}

	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		final leZoom:Float = doZoomCalc ? zoomList[curZoom] : 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height * leZoom, 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		final leZoom:Float = doZoomCalc ? zoomList[curZoom] : 1;
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height * leZoom);
	}
	
	function getYfromStrumNotes(strumTime:Float, beats:Float):Float
	{
		final value:Float = strumTime / (beats * 4 * Conductor.stepCrochet);
		return GRID_SIZE * beats * 4 * zoomList[curZoom] * value + gridBG.y;
	}

	function getNotes():Array<Dynamic>
	{
		return [for (i in _song.notes) i.sectionNotes];
	}

	var missingText:FlxText;
	var missingTextTimer:FlxTimer;
	function loadJson(song:String, altLoad = false):Void
	{
		// shitty null fix, i fucking hate it when this happens
		// make it look sexier if possible
		try
		{
			if (_queuedSong == null)
				_queuedSong = new Song();
			if (altLoad)
			{
				_queuedSong.load(Song.onLoadJson(Song.parseJSONshit(StringTools.trim(#if sys File.getContent(song) #else lime.utils.Assets.getText(song) #end))));
			}
			else
			{
				final diff = Difficulty.getString();
				var name = song.toLowerCase();
				if (diff != null && diff != Difficulty.getDefault())
					name += '-$diff';
				Song.loadFromJson(name, song.toLowerCase(), _queuedSong, false);
			}
			FlxG.resetState();
		}
		catch (e)
		{
			trace('ERROR! $e');

			var errorStr:String = e.toString();
			if (errorStr.startsWith("[file_contents,assets/data/"))
				errorStr = "Missing file: " + errorStr.substring(27, errorStr.length-1); //Missing chart
			
			if (missingText == null)
			{
				missingText = new FlxText(50, 0, FlxG.width - 100, "", 24);
				missingText.font = Paths.font("vcr.ttf");
				missingText.scrollFactor.set();
				missingText.alignment = CENTER;
				add(missingText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK));
			}
			if (missingTextTimer != null)
				missingTextTimer.cancel();

			missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			missingText.screenCenter(Y);
			missingText.visible = true;

			missingTextTimer = new FlxTimer().start(5, (_) ->
			{
				missingTextTimer = null;
				missingText.visible = false;
				// remove(missingText);
				// missingText.destroy();
			});
			FlxG.sound.play(Paths.sound("cancelMenu"));
		}
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = haxe.Json.stringify({"song": _song});
		FlxG.save.flush();
	}

	function clearEvents() {
		_song.events = [];
		updateGrid();
	}

	private function saveLevel()
	{
		FlxG.sound.music.pause();
		if (vocals != null)
			vocals.pause();
		if (opponentVocals != null)
			opponentVocals.pause();
		if (_song.events != null && _song.events.length > 1)
			_song.events.sort(sortByTime);

		final data:String = haxe.Json.stringify({"song": _song}, !optimizeJsonBox.checked ? "\t" : null);
		if (!data.isNullOrEmpty())
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), Paths.formatToSongPath(_song.song) + ".json");
		}
	}

	inline function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveEvents()
	{
		FlxG.sound.music.pause();
		if (vocals != null)
			vocals.pause();
		if (opponentVocals != null)
			opponentVocals.pause();
		if (_song.events != null && _song.events.length > 1)
			_song.events.sort(sortByTime);

		final data:String = haxe.Json.stringify({"song": {events: _song.events}}, !optimizeJsonBox.checked ? "\t" : null);
		if (!data.isNullOrEmpty())
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
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
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}

	@:noCompletion inline function updateBeat():Void
	{
		curBeat = Math.floor(curDecBeat = curDecStep * .25);
	}

	@:noCompletion function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		final shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	@:noCompletion inline function getSectionBeats(?section:Null<Int> = null)
	{
		return _song?.notes[section ?? curSec]?.sectionBeats ?? 4; 
	}
}

private class ChartingHelpSubstate extends FlxSubState
{
	inline static final HELP_TEXT = "CONTROLS
W/S or Mouse Wheel - Change Conductor's strum time
A/D - Go to the previous/next section
Left/Right - Change Snap
Up/Down - Change Conductor's Strum Time with Snapping
Left Bracket / Right Bracket - Change Song Playback Rate (SHIFT to go Faster)
ALT + Left Bracket / Right Bracket - Reset Song Playback Rate
Hold Shift to move 4x faster
Right click (or Hold Control and click) on an arrow to select it
H - Flip \"Must hit section\" flag on\\off
M - Mirror notes
Z/X - Zoom in/out
TAB - Next UI tab (Hold Shift to go to the previous tab)
Esc - Test your chart inside Chart Editor
Enter - Play your chart
Q/E - Decrease/Increase Note Sustain Length
Space - Stop/Resume song";

	public function new()
	{
		super(0x99000000);
		final text = new FlxText(HELP_TEXT, 14);
		text.setBorderStyle(OUTLINE_FAST, FlxColor.BLACK, 1);
		text.alignment = CENTER;
		text.scrollFactor.set();
		add(text.screenCenter());
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

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true)
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}
#end
