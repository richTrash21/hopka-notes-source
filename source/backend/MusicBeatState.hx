package backend;

class MusicBeatState extends BaseState implements IMusicBeatState
{
	public var curSection = 0;
	public var stepsToDo = 0;

	public var curStep = 0;
	public var curBeat = 0;
	public var curDecStep = 0.0;
	public var curDecBeat = 0.0;

	public var lastBeat = -1;
	public var lastStep = -1;

	public var stages = new Array<BaseStage>();

	override public function update(elapsed:Float)
	{
		MusicBeatStateHelper.update(this);
		stagesFunc((stage) -> stage.update(elapsed));
		super.update(elapsed);
	}

	public function stepHit():Void
	{
		stagesFunc((stage) ->
		{
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});
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

	override public function destroy()
	{
		if (stages != null)
		{
			for (stage in stages)
				if (stage != null)
					stage.destroy();
			stages = null;
		}
		super.destroy();
	}

	extern inline function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if (stage != null && stage.exists && stage.active)
				func(stage);
	}
}
