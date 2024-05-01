package backend;

class Conductor
{
	public static var bpm(default, set) = 100.0;
	public static var crochet = 60.0 / bpm * 1000.0; // beats in milliseconds
	public static var stepCrochet = crochet * 0.25; // steps in milliseconds
	public static var songPosition = 0.0;
	public static var offset = 0.0;

	public static var safeZoneOffset = 0.0; // is calculated in create(), is safeFrames in milliseconds
	public static var bpmChangeMap = new Array<BPMChangeEvent>();

	public static function judgeNote(arr:Array<Rating>, diff = 0.0):Rating // die
	{
		for (i in 0...arr.length-1) // skips last window (Shit)
			if (diff <= arr[i].hitWindow)
				return arr[i];

		return arr[arr.length - 1];
	}

	inline public static function getCrotchetAtTime(time:Float):Float
	{
		return getBPMFromSeconds(time).stepCrochet * 4.0;
	}

	public static function getBPMFromSeconds(time:Float):BPMChangeEvent
	{
		var lastChange:BPMChangeEvent = null;
		for (i => change in bpmChangeMap)
			if (time >= change.songTime)
				lastChange = change;

		return lastChange ?? {stepTime: 0, songTime: 0.0, bpm: bpm, stepCrochet: stepCrochet};
	}

	public static function getBPMFromStep(step:Float):BPMChangeEvent
	{
		var lastChange:BPMChangeEvent = null;
		for (i => change in bpmChangeMap)
			if (change.stepTime <= step)
				lastChange = change;

		return lastChange ?? {stepTime: 0, songTime: 0.0, bpm: bpm, stepCrochet: stepCrochet};
	}

	public static function beatToSeconds(beat:Float):Float
	{
		// TODO: make less shit and take BPM into account PROPERLY
		final step = beat * 4.0;
		final lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm * 0.016666666666666666) * 0.25) * 1000.0; // / 60
	}

	public static function getStep(time:Float):Float
	{
		final lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float):Float
	{
		final lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	inline public static function getBeat(time:Float):Float
	{
		return getStep(time) * 0.25;
	}

	inline public static function getBeatRounded(time:Float):Int
	{
		return Math.floor(getStepRounded(time) * 0.25);
	}

	public static function mapBPMChanges(song:Song)
	{
		while (bpmChangeMap.length != 0)
			bpmChangeMap.pop();

		var curBPM = song.bpm;
		var totalSteps = 0;
		var totalPos = 0.0;
		for (i in 0...song.notes.length)
		{
			if (song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				bpmChangeMap.push({
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM) * 0.25
				});
			}

			final deltaSteps = Math.round(getSectionBeats(song, i) * 4.0);
			totalSteps += deltaSteps;
			totalPos += (60.0 / curBPM * 250.0) * deltaSteps;
		}
		GameLog.notice('new BPM map BUDDY $bpmChangeMap');
	}

	inline static function getSectionBeats(song:Song, section:Int):Float
	{
		return song?.notes[section]?.sectionBeats ?? 4.0;
	}

	inline public static function calculateCrochet(bpm:Float):Float
	{
		return 60.0 / bpm * 1000.0;
	}

	@:noCompletion static function set_bpm(newBPM:Float):Float
	{
		stepCrochet = (crochet = calculateCrochet(newBPM)) * 0.25;
		return bpm = newBPM;
	}
}

@:publicFields @:structInit class BPMChangeEvent
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Null<Float>;
}
