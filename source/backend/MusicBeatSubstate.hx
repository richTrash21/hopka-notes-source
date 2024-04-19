package backend;

class MusicBeatSubstate extends flixel.FlxSubState implements IMusicBeatState
{
	var curSection:Int = 0;
	var stepsToDo:Int = 0;

	var lastBeat:Float = 0;
	var lastStep:Float = 0;

	var curStep:Int = 0;
	var curBeat:Int = 0;

	var curDecStep:Float = 0;
	var curDecBeat:Float = 0;
	final controls = Controls.instance;

	override function update(elapsed:Float)
	{
		if (!persistentUpdate)
			MusicBeatState.timePassedOnState += elapsed;

		final oldStep = curStep;
		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if (curStep > 0)
				stepHit();
			if (PlayState.SONG.song != null)
			{
				if (oldStep < curStep)
					updateSection()
				else
					rollbackSection();
			}
		}

		super.update(elapsed);
	}

	override function tryUpdate(elapsed:Float)
	{
		if (CoolUtil.__update__state__check(this))
			update(elapsed);

		if (_requestSubStateReset)
		{
			_requestSubStateReset = false;
			resetSubState();
		}
		if (subState != null)
			subState.tryUpdate(elapsed);
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void {}
	public function sectionHit():Void {}

	@:noCompletion function updateSection():Void
	{
		if (stepsToDo < 1)
			stepsToDo = Math.round(getBeatsOnSection() * 4);

		while (curStep >= stepsToDo)
		{
			curSection++;
			stepsToDo += Math.round(getBeatsOnSection() * 4);
			sectionHit();
		}
	}

	@:noCompletion function rollbackSection():Void
	{
		if (curStep < 0)
			return;

		final lastSection = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] == null)
				continue;

			stepsToDo += Math.round(getBeatsOnSection() * 4);
			if (stepsToDo > curStep)
				break;
			
			curSection++;
		}

		if (curSection > lastSection)
			sectionHit();
	}

	@:noCompletion function updateBeat():Void
	{
		curBeat = Math.floor(curStep * .25);
		curDecBeat = curDecStep * .25;
	}

	@:noCompletion function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		final shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}
	
	@:noCompletion inline function getBeatsOnSection()
	{
		return PlayState.SONG?.notes[curSection]?.sectionBeats ?? 4;
	}
}
