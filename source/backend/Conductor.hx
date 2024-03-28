package backend;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var bpm(default, set):Float = 100;
	public static var crochet:Float = 60 / bpm * 1000; // beats in milliseconds
	public static var stepCrochet:Float = crochet * .25; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var offset:Float = 0;

	//public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = 0; // is calculated in create(), is safeFrames in milliseconds

	public static var bpmChangeMap = new Array<BPMChangeEvent>();

	public static function judgeNote(arr:Array<Rating>, diff = 0.):Rating // die
	{
		for (i in 0...arr.length-1) // skips last window (Shit)
			if (diff <= arr[i].hitWindow)
				return arr[i];

		return arr[arr.length - 1];
	}

	inline public static function getCrotchetAtTime(time:Float):Float
	{
		return getBPMFromSeconds(time).stepCrochet * 4;
	}

	public static function getBPMFromSeconds(time:Float):BPMChangeEvent
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
			if (time >= Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];

		return lastChange;
	}

	public static function getBPMFromStep(step:Float):BPMChangeEvent
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
			if (Conductor.bpmChangeMap[i].stepTime <= step)
				lastChange = Conductor.bpmChangeMap[i];

		return lastChange;
	}

	public static function beatToSeconds(beat:Float):Float
	{
		// TODO: make less shit and take BPM into account PROPERLY
		final step = beat * 4;
		final lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm * 0.016666666666666666) * .25) * 1000; // / 60
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
		return getStep(time) * .25;
	}

	inline public static function getBeatRounded(time:Float):Int
	{
		return Math.floor(getStepRounded(time) * .25);
	}

	public static function mapBPMChanges(song:Song)
	{
		while (bpmChangeMap.length != 0)
			bpmChangeMap.pop();

		var curBPM = song.bpm;
		var totalSteps = 0;
		var totalPos = 0.;
		for (i in 0...song.notes.length)
		{
			if (song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				final event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM) * 0.25
				};
				bpmChangeMap.push(event);
			}

			final deltaSteps = Math.round(getSectionBeats(song, i) * 4);
			totalSteps += deltaSteps;
			totalPos += (60 / curBPM * 250) * deltaSteps;
		}
		trace('new BPM map BUDDY $bpmChangeMap');
	}

	inline static function getSectionBeats(song:Song, section:Int)
	{
		return song?.notes[section]?.sectionBeats ?? 4;
	}

	inline public static function calculateCrochet(bpm:Float)
	{
		return 60 / bpm * 1000;
	}

	@:noCompletion static function set_bpm(newBPM:Float):Float
	{
		stepCrochet = (crochet = calculateCrochet(newBPM)) * .25;
		return bpm = newBPM;
	}
}