package backend;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.typeLimit.NextState;
import flixel.FlxState;

class MusicBeatState extends FlxState /*FlxTransitionableState*/ implements IMusicBeatState
{
	// TRANS RIGHTS!!!!
	// public static final transTime = .45; // uniform transition time
	// substates that transition can land onto
	// public static final substatesToTrans:Array<Class<flixel.FlxSubState>> = [substates.PauseSubState, substates.GameOverSubstate, psychlua.CustomSubstate];

	public static var timePassedOnState = 0.;

	@:access(flixel.FlxState._constructor)
	public static function switchState(?nextState:NextState)
	{
		if (nextState == null || nextState == FlxG.state._constructor)
			return resetState();

		if (FlxTransitionableState.skipNextTransIn)
			FlxG.switchState(nextState);
		else
			startTransition(nextState);

		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState()
	{
		if (FlxTransitionableState.skipNextTransIn)
			FlxG.resetState();
		else
			startTransition();

		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(?nextState:NextState)
	{
		Main.transition.start(nextState, StateTransition.transTime, false);
	}

	/*inline public static function getState():FlxState
	{
		return FlxG.state;
	}

	inline public static function getSubState():FlxState
	{
		return FlxG.state.subState;
	}*/

	// thx redar
	// UPD: dont need this anymore lmao
	// inline static function stateOrSubState():FlxState
	// {
	//	return (FlxG.state.subState != null /*&& substatesToTrans.contains(Type.getClass(FlxG.state.subState))*/) ? getSubState() : getState();
	// }

	var curSection:Int = 0;
	var stepsToDo:Int = 0;

	var curStep:Int = 0;
	var curBeat:Int = 0;

	var curDecStep:Float = 0;
	var curDecBeat:Float = 0;

	public var controls(get, never):Controls;
	public var stages:Array<BaseStage> = [];

	// public function new() { super(); }

	override public function create()
	{
		#if MODS_ALLOWED
		Mods.updatedOnState = false;
		#end
		timePassedOnState = 0;
	}

	override public function update(elapsed:Float)
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
		
		stagesFunc((stage) -> stage.update(elapsed));
		super.update(elapsed);
	}

	// transition is not substate anymore so had to change this a bit
	override function tryUpdate(elapsed:Float)
	{
		if (CoolUtil.updateStateCheck(this))
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
		stagesFunc((stage) ->
		{
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

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

	inline function stagesFunc(func:BaseStage->Void)
	{
		if (stages.length != 0)
			for (stage in stages)
				if (stage != null && stage.exists && stage.active)
					func(stage);
	}

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
		curSection = stepsToDo = 0;
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

	@:noCompletion function updateBeat():Void
	{
		curBeat = Math.floor(curStep * 0.25);
		curDecBeat = curDecStep * 0.25;
	}

	@:noCompletion function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		final shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	@:noCompletion inline function getBeatsOnSection():Float
	{
		return PlayState.SONG?.notes[curSection]?.sectionBeats ?? 4;
	}

	@:noCompletion inline function get_controls():Controls
	{
		return Controls.instance;
	}
}
