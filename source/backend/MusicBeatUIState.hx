package backend;

import flixel.addons.transition.FlxTransitionableState;
import flixel.FlxState;

import backend.MusicBeatState;

/**
	An exact copy of MusicBeatState, but extending FlxUIState (whitch was originaly a MusicBeatState thing lmao)
 **/
class MusicBeatUIState extends flixel.addons.ui.FlxUIState implements IMusicBeatState
{
	var curSection:Int = 0;
	var stepsToDo:Int = 0;

	var curStep:Int = 0;
	var curBeat:Int = 0;

	var curDecStep:Float = 0;
	var curDecBeat:Float = 0;

	public var controls(get, never):Controls;

	public function new() { super(); }

	override function create()
	{
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		super.create();

		if (!FlxTransitionableState.skipNextTransOut)
			openSubState(new CustomFadeTransition(MusicBeatState.transTime, true));

		FlxTransitionableState.skipNextTransOut = false;
	}

	override function update(elapsed:Float)
	{
		final oldStep = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();

		// if (FlxG.save.data != null)
		//	FlxG.save.data.fullscreen = FlxG.fullscreen;

		super.update(elapsed);
	}

	function updateSection():Void
	{
		if (stepsToDo < 1)
			stepsToDo = 16;

		while (curStep >= stepsToDo)
		{
			curSection++;
			stepsToDo += 16;
			sectionHit();
		}
	}

	function rollbackSection():Void
	{
		if (curStep < 0)
			return;

		final lastSection = curSection;
		curSection = stepsToDo = 0;

		if (curSection > lastSection)
			sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		final shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void {}
	public function sectionHit():Void {}

	@:noCompletion inline function get_controls():Controls
	{
		return Controls.instance;
	}
}
