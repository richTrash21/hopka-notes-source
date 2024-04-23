package backend;

extern class MusicBeatStateHelper
{
	inline public static function update(state:IMusicBeatState, ?song:Song):Void
	{
		if (song == null)
			song = PlayState.SONG;

		updateCurStep(state);
		updateBeat(state);

		if (state.lastStep != state.curStep)
		{
			if (state.curStep > 0)
			{
				state.stepHit();
				if (state.curStep % 4 == 0)
					state.beatHit();
			}

			if (song.song != null)
			{
				if (state.lastStep < state.curStep) 
					updateSection(state, song);
				else
					rollbackSection(state, song);
			}
		}
	}

	inline static function updateSection(state:IMusicBeatState, song:Song):Void
	{
		if (state.stepsToDo < 1)
			state.stepsToDo = Math.round(getBeatsOnSection(state.curSection, song) * 4);

		while (state.curStep >= state.stepsToDo)
		{
			state.curSection++;
			state.stepsToDo += Math.round(getBeatsOnSection(state.curSection, song) * 4);
			state.sectionHit();
		}
	}

	inline static function rollbackSection(state:IMusicBeatState, song:Song):Void
	{
		if (state.curStep < 0)
			return;

		final lastSection = state.curSection;
		state.curSection = state.stepsToDo = 0;
		for (i in 0...song.notes.length)
		{
			if (song.notes[i] != null)
			{
				if ((state.stepsToDo += Math.round(getBeatsOnSection(state.curSection, song) * 4)) > state.curStep)
					break;
				
				state.curSection++;
			}
		}

		if (state.curSection > lastSection)
			state.sectionHit();
	}

	inline static function updateCurStep(state:IMusicBeatState):Void
	{
		state.lastStep = state.curStep;
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		final offset = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		state.curDecStep = lastChange.stepTime + offset;
		state.curStep = lastChange.stepTime + Math.floor(offset);
	}

	inline static function updateBeat(state:IMusicBeatState):Void
	{
		state.lastBeat = state.curBeat;
		state.curBeat = Math.floor(state.curStep * 0.25);
		state.curDecBeat = state.curDecStep * 0.25;
	}

	inline static function getBeatsOnSection(section:Int, song:Song):Float
	{
		return song.notes[section]?.sectionBeats ?? 4.0;
	}
}
