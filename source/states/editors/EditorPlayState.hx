package states.editors;

import objects.PopupSprite;
#if !RELESE_BUILD_FR
import flixel.util.FlxStringUtil;
import backend.Section.SwagSection;
import backend.Rating;

import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;

import flixel.util.FlxSort;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

class EditorPlayState extends MusicBeatSubstate
{
	// Borrowed from original PlayState
	var finishTimer:FlxTimer = null;
	var noteKillOffset:Float = 350;
	var spawnTime:Float = 2000;
	var startingSong:Bool = true;

	var playbackRate:Float = 1;
	var vocals:FlxSound;
	var inst:FlxSound;
	
	var notes:FlxTypedGroup<Note>;
	var unspawnNotes:Array<Note> = [];
	var ratingsData:Array<Rating> = Rating.loadDefault();
	
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var opponentStrums:FlxTypedGroup<StrumNote>;
	var playerStrums:FlxTypedGroup<StrumNote>;
	var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	
	var combo:Int = 0;
	var scoreGroup:FlxTypedGroup<PopupSprite>;
	
	var songHits:Int = 0;
	var songMisses:Int = 0;
	var songLength:Float = 0;
	var songSpeed:Float = 1;
	
	var totalPlayed:Int = 0;
	var totalNotesHit:Float = 0.0;
	var ratingPercent:Float;
	var ratingFC:String;
	
	var showComboNum:Bool = true;
	var showRating:Bool = true;

	// Originals
	var startOffset:Float = 0;
	var startPos:Float = 0;
	var timerToStart:Float = 0;

	var scoreTxt:FlxText;
	var dataTxt:FlxText;

	public function new(playbackRate:Float)
	{
		super();
		
		/* setting up some important data */
		this.playbackRate = playbackRate;
		this.startPos = Conductor.songPosition;

		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames * .016666666666666666) * 1000 * playbackRate; // / 60
		Conductor.songPosition -= startOffset;
		startOffset = Conductor.crochet;
		timerToStart = startOffset;
		
		/* borrowed from PlayState */
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		cachePopUpScore();
		if(ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');

		/* setting up Editor PlayState stuff */
		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.color = 0xFF101010;
		bg.alpha = 0.9;
		add(bg);
		
		/**** NOTES ****/
		add(strumLineNotes = new FlxTypedGroup());
		add(scoreGroup = new FlxTypedGroup()).ID = 0;
		add(grpNoteSplashes = new FlxTypedGroup());

		grpNoteSplashes.add(__splashFactory()).precache();

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();
		
		generateStaticArrows(0);
		generateStaticArrows(1);
		
		scoreTxt = new FlxText(10, FlxG.height - 30, FlxG.width - 20, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		add(scoreTxt);
		
		dataTxt = new FlxText(10, 580, FlxG.width - 20, "Section: 0", 20);
		dataTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		dataTxt.scrollFactor.set();
		dataTxt.borderSize = 1.25;
		add(dataTxt);

		var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press ESC to Go Back to Chart Editor', 16);
		tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 2;
		tipText.scrollFactor.set();
		add(tipText);
		// FlxG.mouse.visible = false;
		
		generateSong(PlayState.SONG.song);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		
		#if hxdiscord_rpc
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence('Playtesting on Chart Editor', PlayState.SONG.song, null, true, songLength);
		#end
		RecalculateRating();
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
		{
			endSong();
			FlxG.state.persistentUpdate = true;
			super.update(elapsed);
			return;
		}
		
		if (startingSong)
		{
			timerToStart -= elapsed * 1000;
			Conductor.songPosition = startPos - timerToStart;
			if (timerToStart < 0)
				startSong();
		}
		else
			Conductor.songPosition += elapsed * 1000 * playbackRate;

		if (unspawnNotes[0] != null)
		{
			var time = spawnTime * playbackRate;
			if (songSpeed < 1)
				time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1)
				time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes.shift();
				notes.insert(0, dunceNote).spawned = true;
			}
		}

		keysCheck();
		if(notes.length > 0)
		{
			// var fakeCrochet:Float = 60 / PlayState.SONG.bpm * 1000;
			notes.forEachAlive(function(daNote:Note)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
				if(!daNote.mustPress) strumGroup = opponentStrums;

				var strum:StrumNote = strumGroup.members[daNote.noteData];
				daNote.followStrumNote(strum, /*fakeCrochet,*/ songSpeed / playbackRate);

				if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
					opponentNoteHit(daNote);

				if(daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

				// Kill extremely late notes and cause misses
				if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
				{
					if (daNote.mustPress && !daNote.ignoreNote && (daNote.tooLate || !daNote.wasGoodHit))
						noteMiss(daNote);

					daNote.active = false;
					daNote.visible = false;

					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}
			});
		}
		
		final curTime:Float = (Conductor.songPosition - ClientPrefs.data.noteOffset) * .001;
		final maxTime:Float = songLength * .001;
		// \n[${CoolUtil.floorDecimal(curTime, 2)} / ${CoolUtil.floorDecimal(maxTime, 2)}]
		dataTxt.text = 'Time: ${FlxStringUtil.formatTime(curTime, true)} / ${FlxStringUtil.formatTime(maxTime, true)}\nSection: $curSection\nBeat: $curBeat\nStep: $curStep';
		super.update(elapsed);
	}
	
	var lastStepHit:Int = -1;
	override function stepHit()
	{
		if (FlxG.sound.music.time >= -ClientPrefs.data.noteOffset)
		{
			final maxDelay = 20 * playbackRate;
			final realTime = Conductor.songPosition - Conductor.offset;
			if (Math.abs(FlxG.sound.music.time - realTime) > maxDelay || (PlayState.SONG.needsVoices && Math.abs(vocals.time - realTime) > maxDelay))
				resyncVocals();
		}
		super.stepHit();

		if(curStep == lastStepHit) return;
		lastStepHit = curStep;
	}

	var lastBeatHit:Int = -1;
	override function beatHit()
	{
		if(lastBeatHit >= curBeat) return;
		notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		super.beatHit();
		lastBeatHit = curBeat;
	}
	
	override function sectionHit()
	{
		if (PlayState.SONG.notes[curSection] != null)
			if (PlayState.SONG.notes[curSection].changeBPM)
				Conductor.bpm = PlayState.SONG.notes[curSection].bpm;

		super.sectionHit();
	}

	override function destroy()
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		// FlxG.mouse.visible = true;
		super.destroy();
	}
	
	function startSong():Void
	{
		startingSong = false;
		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		FlxG.sound.music.time = startPos;
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong;
		vocals.volume = 1;
		vocals.time = startPos;
		vocals.play();

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
	}

	// Borrowed from PlayState
	function generateSong(dataPath:String)
	{
		songSpeed = PlayState.SONG.speed;
		var songSpeedType:String = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative": songSpeed = PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant": songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);

		var songData = PlayState.SONG;
		Conductor.bpm = songData.bpm;

		vocals = new FlxSound();
		if (songData.needsVoices) vocals.loadEmbedded(Paths.voices(songData.song));
		vocals.volume = 0;

		#if FLX_PITCH vocals.pitch = playbackRate; #end
		FlxG.sound.list.add(vocals);

		inst = new FlxSound().loadEmbedded(Paths.inst(songData.song));
		FlxG.sound.list.add(inst);
		FlxG.sound.music.volume = 0;

		notes = new FlxTypedGroup<Note>();
		add(notes);

		// NEW SHIT
		for (section in songData.notes)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				if(daStrumTime < startPos) continue;

				var daNoteData:Int = Std.int(songNotes[1] % 4);
				var gottaHitNote:Bool = songNotes[1] > 3 ? !section.mustHitSection : section.mustHitSection;
				var oldNote:Note = unspawnNotes.length > 0 ? unspawnNotes[Std.int(unspawnNotes.length - 1)] : null;

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote, this);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				swagNote.noteType = !Std.isOfType(songNotes[3], String) ? ChartingState.noteTypeList[songNotes[3]] : songNotes[3]; //Backward compatibility + compatibility with Week 7 charts
				swagNote.scrollFactor.set();

				var susLength:Float = swagNote.sustainLength / Conductor.stepCrochet;
				unspawnNotes.push(swagNote);

				var floorSus:Int = Math.floor(susLength);
				if(floorSus > 0) {
					for (susNote in 0...floorSus+1)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote), daNoteData, oldNote, true, this);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1]<4));
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						swagNote.tail.push(sustainNote);
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						
						sustainNote.correctionOffset = swagNote.height * .5;
						if(!PlayState.isPixelStage)
						{
							if(oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight / playbackRate;
								oldNote.updateHitbox();
							}

							if(ClientPrefs.data.downScroll) sustainNote.correctionOffset = 0;
						}

						if (sustainNote.mustPress)				sustainNote.x += FlxG.width * 0.5; // general offset
						else if (ClientPrefs.data.middleScroll)	sustainNote.x += daNoteData > 1 ? FlxG.width * 0.5 + 335 : 310;
					}
				}

				if (swagNote.mustPress)					swagNote.x += FlxG.width * 0.5; // general offset
				else if (ClientPrefs.data.middleScroll)	swagNote.x += daNoteData > 1 ? FlxG.width * 0.5 + 335 : 310;
			}
		}

		unspawnNotes.sort(Note.sortByTime);
	}
	
	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			babyArrow.alpha = targetAlpha;
			babyArrow.scrollFactor.set(); // whoopsie

			if (player == 1) playerStrums.add(babyArrow);
			else
			{
				if(ClientPrefs.data.middleScroll) babyArrow.x += i > 1 ? FlxG.width * 0.5 + 335 : 310;
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	public function finishSong():Void
	{
		if(ClientPrefs.data.noteOffset <= 0) endSong();
		else finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset * .001, (_) -> endSong());
	}

	public function endSong()
	{
		vocals.pause();
		vocals.destroy();
		if(finishTimer != null)
		{
			finishTimer.cancel();
			finishTimer.destroy();
		}
		close();
	}

	private function cachePopUpScore()
	{
		for (rating in ratingsData) Paths.image(rating.image);
		for (i in 0...10) Paths.image('num$i');
	}

	inline static function __ratingFactory():PopupSprite
	{
		final s = PlayState.__ratingFactory();
		s.scrollFactor.set();
		return s; 
	}

	inline static function __numScoreFactory():PopupScore
	{
		final s = PlayState.__numScoreFactory();
		s.scrollFactor.set();
		return s;
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);

		vocals.volume = 1;
		var placement:Float = FlxG.width * 0.35;
		var score:Int = 350;
		var antialias:Bool = ClientPrefs.data.antialiasing;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if(daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if(!note.ratingDisabled)
		{
			songHits++;
			totalPlayed++;
			RecalculateRating(false);
		}

		// доволен??🙄🙄
		if (!ClientPrefs.data.enableCombo || ClientPrefs.data.hideHud || (!showRating && !showComboNum))
			return;

		final placement = FlxG.width * 0.35;
		var scaleMult   = 0.7;
		var numScale    = 0.5;

		final noStacking = !ClientPrefs.data.comboStacking;
		if (noStacking)
			scoreGroup.forEachAlive((spr) -> spr.kill());

		if (showRating)
		{
			final rating = scoreGroup.recycle(PopupSprite, __ratingFactory, true);
			rating.loadGraphic(Paths.image(daRating.image));
			rating.x = placement - 40 + ClientPrefs.data.comboOffset[0];
			rating.screenCenter(Y).y -= 60 + ClientPrefs.data.comboOffset[1];
			rating.setScale(scaleMult);
			rating.updateHitbox();
			rating.setAngleVelocity(-rating.velocity.x, rating.velocity.x);
			scoreGroup.add(rating);

			rating.fadeTime = Conductor.crochet * 0.001;
			rating.fadeSpeed = 5;
			rating.order = scoreGroup.ID++;
			rating.scrollFactor.set();
		}

		if (showComboNum)
		{
			final digits = combo < 1000 ? 3 : CoolUtil.getDigits(combo);
			final seperatedScore = [for (i in 0...digits) Math.floor(combo / Math.pow(10, (digits - 1) - i)) % 10];
			for (i => v in seperatedScore)
			{
				final numScore = scoreGroup.recycle(PopupScore, __numScoreFactory, true);
				numScore.loadGraphic(Paths.image('num$v'));
				numScore.x = placement + (45 * i) - 90 + ClientPrefs.data.comboOffset[2];
				numScore.screenCenter(Y).y += 80 - ClientPrefs.data.comboOffset[3];

				numScore.setScale(numScale);
				numScore.updateHitbox();
				numScore.offset.add(FlxG.random.float(-1, 1), FlxG.random.float(-1, 1));
				numScore.angularVelocity = -numScore.velocity.x;
				scoreGroup.add(numScore);

				numScore.fadeTime = Conductor.crochet * 0.001;
				numScore.fadeSpeed = 5;
				numScore.order = scoreGroup.ID++;
			}
		}
		scoreGroup.sort(CoolUtil.sortByOrder);
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(PlayState.keysArray, eventKey);
		if (!controls.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
	}

	private function keyPressed(key:Int)
	{
		if (key > -1 && notes.length > 0)
		{
			//more accurate hit time for the ratings?
			var lastTime:Float = Conductor.songPosition;
			if(Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time;

			// heavily based on my own code LOL if it aint broke dont fix it
			var pressNotes:Array<Note> = [];
			var notesStopped:Bool = false;

			var sortedNotesList:Array<Note> = [];
			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate &&
					!daNote.wasGoodHit && !daNote.isSustainNote && !daNote.blockHit)
				{
					if(daNote.noteData == key)
						sortedNotesList.push(daNote);
				}
			});

			if (sortedNotesList.length > 0) {
				sortedNotesList.sort(PlayState.sortHitNotes);
				for (epicNote in sortedNotesList)
				{
					for (doubleNote in pressNotes) {
						if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
							doubleNote.kill();
							notes.remove(doubleNote, true);
							doubleNote.destroy();
						} else
							notesStopped = true;
					}

					// eee jack detection before was not super good
					if (!notesStopped) {
						goodNoteHit(epicNote);
						pressNotes.push(epicNote);
					}

				}
			}
			//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
			Conductor.songPosition = lastTime;
		}

		var spr:StrumNote = playerStrums.members[key];
		if(spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(PlayState.keysArray, eventKey);
		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		var spr:StrumNote = playerStrums.members[key];
		if(spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
	}
	
	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in PlayState.keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i])
					keyPressed(i);

		// rewritten inputs???
		notes.forEachAlive(function(daNote:Note)
		{
			// hold note functions
			if (daNote.isSustainNote && holdArray[daNote.noteData] && daNote.canBeHit
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit)
				goodNoteHit(daNote);
		});

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i])
					keyReleased(i);
	}

	
	function opponentNoteHit(note:Note):Void
	{
		if (PlayState.SONG.needsVoices)
			vocals.volume = 1;

		var strum:StrumNote = opponentStrums.members[Std.int(Math.abs(note.noteData))];
		if(strum != null) {
			strum.playAnim('confirm', true);
			strum.resetAnim = Conductor.stepCrochet * 1.25 * .001 / playbackRate;
		}
		note.hitByOpponent = true;

		if (!note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			note.wasGoodHit = true;
			if (ClientPrefs.data.hitsoundVolume > 0 && !note.hitsoundDisabled)
				FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

			if(note.hitCausesMiss) {
				noteMiss(note);
				if(!note.noteSplashData.disabled && !note.isSustainNote)
					spawnNoteSplashOnNote(note);

				if (!note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote)
			{
				combo++;
				if(combo > 9999) combo = 9999;
				popUpScore(note);
			}

			var spr:StrumNote = playerStrums.members[note.noteData];
			if(spr != null) spr.playAnim('confirm', true);
			vocals.volume = 1;

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}
	
	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});

		// score and data
		songMisses++;
		totalPlayed++;
		RecalculateRating(true);
		vocals.volume = 0;
		combo = 0;
	}

	function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) spawnNoteSplash(strum.x, strum.y, note.noteData, note);
		}
	}

	static final __splashFactory = () -> { final s = new NoteSplash(); s.scrollFactor.set(); return s; };
	inline function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note)
	{
		grpNoteSplashes.add(grpNoteSplashes.recycle(NoteSplash, __splashFactory)).setupNoteSplash(x, y, data, note);
	}
	
	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		//vocals.pause();

		//FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time;
		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = Conductor.songPosition;
			#if FLX_PITCH vocals.pitch = playbackRate; #end
		}
		//vocals.play();
	}

	function RecalculateRating(badHit:Bool = false) {
		if(totalPlayed != 0) //Prevent divide by 0
			ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));

		fullComboUpdate();
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
	}

	function updateScore(miss:Bool = false)
	{
		scoreTxt.text = 'Hits: $songHits | Misses: $songMisses | Rating: ' + (totalPlayed == 0 ? "?" : CoolUtil.floorDecimal(ratingPercent * 100, 2) + '% - $ratingFC');
	}
	
	function fullComboUpdate()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = 'Clear';
		if(songMisses < 1)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else if (songMisses < 10) ratingFC = 'SDCB';
	}
}
#end
