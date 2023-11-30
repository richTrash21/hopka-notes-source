package states.stages;

import objects.ExtendedSprite;

class StageWeek1 extends BaseStage
{
	override function create()
	{
		final bg:ExtendedSprite = new ExtendedSprite(-600, -200, 'stageback');
		bg.scrollFactor.set(0.9, 0.9);
		add(bg);

		final stageFront:ExtendedSprite = new ExtendedSprite(-650, 600, 'stagefront');
		stageFront.setScale(1.1);
		stageFront.updateHitbox();
		add(stageFront);

		if (ClientPrefs.data.lowQuality) return; // fuck it

		for (i in 0...2)
		{
			final stageLight:ExtendedSprite = new ExtendedSprite(i == 0 ? -125 : 1225, -100, 'stage_light');
			stageLight.scrollFactor.set(0.9, 0.9);
			stageLight.setScale(1.1);
			stageLight.updateHitbox();
			if (i == 1) stageLight.flipX = true;
			add(stageLight);
		}

		final stageCurtains:ExtendedSprite = new ExtendedSprite(-500, -300, 'stagecurtains');
		stageCurtains.scrollFactor.set(1.3, 1.3);
		stageCurtains.setScale(0.9);
		stageCurtains.updateHitbox();
		add(stageCurtains);
	}
}