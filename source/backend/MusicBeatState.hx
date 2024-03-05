package backend;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.typeLimit.NextState;
import flixel.FlxState;

class MusicBeatState extends FlxTransitionableState implements IMusicBeatState
{
	// TRANS RIGHTS!!!!
	public static final transTime:Float = 0.45; // uniform transition time
	// substates that transition can land onto
	public static final substatesToTrans:Array<Class<flixel.FlxSubState>> = [substates.PauseSubState, substates.GameOverSubstate, psychlua.CustomSubstate];

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
			openSubState(new CustomFadeTransition(transTime * 1.1, true));

		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;
	}

	public static var timePassedOnState:Float = 0;
	override function update(elapsed:Float)
	{
		final oldStep = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if (curStep > 0)
				stepHit();

			if (PlayState.SONG != null)
			{
				if (oldStep < curStep) 
					updateSection();
				else
					rollbackSection();
			}
		}

		// if (FlxG.save.data != null)
		//	FlxG.save.data.fullscreen = FlxG.fullscreen;
		
		stagesFunc((stage) -> stage.update(elapsed));
		super.update(elapsed);
	}

	private function updateSection():Void
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

	private function rollbackSection():Void
	{
		if (curStep < 0)
			return;

		final lastSection = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				if ((stepsToDo += Math.round(getBeatsOnSection() * 4)) > curStep)
					break;
				
				curSection++;
			}
		}

		if (curSection > lastSection)
			sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep * 0.25);
		curDecBeat = curDecStep * 0.25;
	}

	private function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		final shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(?nextState:NextState)
	{
		if (nextState == null || nextState == FlxG.state)
		{
			resetState();
			return;
		}

		FlxTransitionableState.skipNextTransIn ? FlxG.switchState(nextState) : startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState()
	{
		FlxTransitionableState.skipNextTransIn ? FlxG.resetState() : startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(?nextState:NextState)
	{
		getStateWithSubState().openSubState(new CustomFadeTransition(transTime, false));
		CustomFadeTransition.finishCallback = nextState == null ? FlxG.resetState : FlxG.switchState.bind(nextState);
	}

	inline public static function getState():FlxState
	{
		return cast FlxG.state;
	}

	inline public static function getSubState():FlxState
	{
		return cast FlxG.state.subState;
	}

	inline public static function getStateWithSubState():FlxState
	{
		if (FlxG.state.subState == null || !substatesToTrans.contains(Type.getClass(FlxG.state.subState)))
			return getState();

		return getSubState();
	}

	public function stepHit():Void
	{
		stagesFunc((stage) ->
		{
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		stagesFunc((stage) ->
		{
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	public function sectionHit():Void
	{
		stagesFunc((stage) ->
		{
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:StageFunction)
	{
		for (stage in stages)
			if (stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection():Float
	{
		return PlayState.SONG?.notes[curSection]?.sectionBeats ?? 4;
	}

	@:noCompletion inline function get_controls():Controls
	{
		return Controls.instance;
	}
}

typedef StageFunction = BaseStage->Void