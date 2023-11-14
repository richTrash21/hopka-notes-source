package backend;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxStringUtil;
import flixel.FlxState;

import backend.MusicBeatState;

/**
	An exact copy of MusicBeatState, but extending FlxUIState (whitch was originaly a MusicBeatState thing lmao)
 **/
class MusicBeatUIState extends flixel.addons.ui.FlxUIState
{
	// TRANS RIGHTS!!!!
	static final transTime:Float = MusicBeatState.transTime; // uniform transition time
	static final substatesToTrans:Array<String> = MusicBeatState.substatesToTrans; // substates that transition can land onto

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
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0) stepHit();

		if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;

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

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(nextState:FlxState = null) {
		if(nextState == null) nextState = FlxG.state;
		if(nextState == FlxG.state)
		{
			resetState();
			return;
		}

		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState() {
		if(FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(nextState:FlxState = null)
	{
		if(nextState == null) nextState = FlxG.state;

		getStateWithSubState().openSubState(new CustomFadeTransition(transTime, false));
		CustomFadeTransition.finishCallback = function() nextState == FlxG.state ? FlxG.resetState() : FlxG.switchState(nextState);
	}

	public static function getState():MusicBeatUIState
		return cast (FlxG.state, MusicBeatUIState);

	public static function getSubState():MusicBeatSubstate
		return cast (FlxG.state.subState, MusicBeatSubstate);

	public static function getStateWithSubState()
		return (FlxG.state.subState != null && substatesToTrans.contains(FlxStringUtil.getClassName(FlxG.state.subState, true)))
			? getSubState()
			: getState();

	public function stepHit():Void { if (curStep % 4 == 0) beatHit(); }
	public function beatHit():Void {}
	public function sectionHit():Void {}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		return val == null ? 4 : val;
	}
}
