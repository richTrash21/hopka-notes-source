package backend;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxStringUtil;
import flixel.FlxState;

class MusicBeatState extends FlxTransitionableState implements IMusicBeatState
{
	// TRANS RIGHTS!!!!
	public static final transTime:Float = 0.45; // uniform transition time
	public static final substatesToTrans:Array<String> = ['PauseSubState', 'CustomSubstate']; // substates that transition can land onto

	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var controls(get, never):Controls;
	private function get_controls():Controls return Controls.instance;

	override function create() {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		super.create();

		if(!FlxTransitionableState.skipNextTransOut)
			openSubState(new CustomFadeTransition(transTime, true));

		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;
	}

	public static var timePassedOnState:Float = 0;
	override function update(elapsed:Float)
	{
		final oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if(curStep > 0) stepHit();
			if(PlayState.SONG != null)
				(oldStep < curStep) ? updateSection() : rollbackSection();
		}

		if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		
		stagesFunc(function(stage:BaseStage) stage.update(elapsed));

		super.update(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		final lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		final shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(?nextState:FlxState)
	{
		if(nextState == null || nextState == FlxG.state)
		{
			resetState();
			return;
		}

		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState()
	{
		if (FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(?nextState:FlxState)
	{
		if (nextState == null) nextState = FlxG.state;

		getStateWithSubState().openSubState(new CustomFadeTransition(transTime, false));
		CustomFadeTransition.finishCallback = function() nextState == FlxG.state ? FlxG.resetState() : FlxG.switchState(nextState);
	}

	public static function getState():FlxState
		return cast FlxG.state;

	public static function getSubState():FlxState
		return cast FlxG.state.subState;

	public static function getStateWithSubState():FlxState
		return (FlxG.state.subState != null && substatesToTrans.contains(FlxStringUtil.getClassName(FlxG.state.subState, true)))
			? getSubState()
			: getState();

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage)
		{
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0) beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		stagesFunc(function(stage:BaseStage)
		{
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	public function sectionHit():Void
	{
		stagesFunc(function(stage:BaseStage)
		{
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = (PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) ? PlayState.SONG.notes[curSection].sectionBeats : 4;
		return val == null ? 4 : val;
	}
}
