package states;

import backend.WeekData;
import backend.Highscore;
import flixel.group.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;

class StoryMenuState extends MusicBeatState
{
	private static var curSelected:Int = 0;
	private static var curDifficulty:Int = 1;

	var scoreText:FlxText;
	var diffText:FlxText;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	
	private var grpWeekText:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;
	var menuItems:Array<String> = [];

	override function create()
	{
		Paths.clearStoredMemory();
		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);

		// 1. Fundo do Menu Principal (Substituindo o Amarelo)
		bg = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		grpWeekText = new FlxTypedGroup<Alphabet>();
		add(grpWeekText);

		// 2. Criar a lista de semanas (Até 9 por lista)
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			
			if (!isLocked) {
				var weekThing:Alphabet = new Alphabet(0, (i * 70) + 150, "Week " + i, true);
				weekThing.targetY = i;
				weekThing.ID = i;
				weekThing.screenCenter(X);
				grpWeekText.add(weekThing);
				menuItems.push(WeekData.weeksList[i]);
			}
		}

		// 3. Ajustador de Dificuldade no Topo
		scoreText = new FlxText(10, 10, 0, "SCORE: 0", 36);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		add(scoreText);

		diffText = new FlxText(0, 50, 0, "< NORMAL >", 32);
		diffText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		diffText.screenCenter(X);
		add(diffText);

		// Setas para a dificuldade (Toque)
		leftArrow = new FlxSprite(diffText.x - 60, diffText.y);
		leftArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrow.animation.addByPrefix('idle', "arrow left");
		leftArrow.animation.play('idle');
		add(leftArrow);

		rightArrow = new FlxSprite(diffText.x + diffText.width + 20, diffText.y);
		rightArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		rightArrow.animation.addByPrefix('idle', "arrow right");
		rightArrow.animation.play('idle');
		add(rightArrow);

		changeSelection();
		changeDifficulty();

		#if android
		addVirtualPad(UP_DOWN, A_B);
		#end

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (!movedBack && !selectedWeek)
		{
			// SENSIBILIDADE AO TOQUE - LISTA
			grpWeekText.forEach(function(spr:Alphabet) {
				if(FlxG.mouse.overlaps(spr)) {
					if(curSelected != spr.ID) {
						curSelected = spr.ID;
						changeSelection();
					}
					if(FlxG.mouse.justPressed) selectWeek();
				}
			});

			// SENSIBILIDADE AO TOQUE - DIFICULDADE
			if(FlxG.mouse.overlaps(leftArrow) && FlxG.mouse.justPressed) changeDifficulty(-1);
			if(FlxG.mouse.overlaps(rightArrow) && FlxG.mouse.justPressed) changeDifficulty(1);

			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);
			if (controls.UI_LEFT_P) changeDifficulty(-1);
			if (controls.UI_RIGHT_P) changeDifficulty(1);
			if (controls.ACCEPT) selectWeek();
			if (controls.BACK) {
				movedBack = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		curSelected += change;
		if (curSelected < 0) curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length) curSelected = 0;

		var bullShit:Int = 0;
		for (item in grpWeekText.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;
			item.alpha = (item.ID == curSelected) ? 1 : 0.6;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateText();
	}

	function changeDifficulty(change:Int = 0)
	{
		curDifficulty += change;
		if (curDifficulty < 0) curDifficulty = Difficulty.list.length - 1;
		if (curDifficulty >= Difficulty.list.length) curDifficulty = 0;

		diffText.text = "< " + Difficulty.getString(curDifficulty).toUpperCase() + " >";
		diffText.screenCenter(X);
		leftArrow.x = diffText.x - 60;
		rightArrow.x = diffText.x + diffText.width + 20;
	}

	var selectedWeek:Bool = false;
	var movedBack:Bool = false;

	function selectWeek()
	{
		if (!weekIsLocked(menuItems[curSelected])) {
			selectedWeek = true;
			FlxG.sound.play(Paths.sound('confirmMenu'));
			grpWeekText.members[curSelected].alpha = 1;
			
			PlayState.storyPlaylist = WeekData.weeksLoaded.get(menuItems[curSelected]).songs.map(s -> s[0]);
			PlayState.isStoryMode = true;
			PlayState.storyDifficulty = curDifficulty;
			PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + '-' + Difficulty.getString(curDifficulty).toLowerCase(), PlayState.storyPlaylist[0].toLowerCase());
			
			LoadingState.loadAndSwitchState(new PlayState());
		}
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && !Highscore.weekCompleted.exists(leWeek.weekBefore));
	}

	function updateText() {
		scoreText.text = "WEEK SCORE: " + Highscore.getWeekScore(menuItems[curSelected], curDifficulty);
	}
}
