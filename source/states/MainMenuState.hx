package states;

import backend.WeekData;
import backend.Achievements;

import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;

import objects.AchievementPopup;
import states.editors.MasterEditorMenu;
import options.OptionsState;

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '0.7.1h'; 
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;
	private var camGame:FlxCamera;
	private var camAchievement:FlxCamera;
	
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		'awards',
		'credits',
		#if MODS_ALLOWED 'mods', #end
		'options'
	];

	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var logo:FlxSprite;

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		camGame = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		persistentUpdate = persistentDraw = true;

		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, 0.1);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, 0.1);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (i in 0...optionShit.length)
		{
			var offset:Float = 200; 
			var menuItem:FlxSprite = new FlxSprite(0, (i * 135) + offset);
			menuItem.antialiasing = ClientPrefs.data.antialiasing;
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle', optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItems.add(menuItem);
			menuItem.scrollFactor.set(0, 0);
			menuItem.updateHitbox();
		}

		// LOGO PEQUENA ACIMA DO STORY MODE
		logo = new FlxSprite().loadGraphic(Paths.image('logo'));
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.setGraphicSize(Std.int(logo.width * 0.25));
		logo.updateHitbox();
		logo.screenCenter(X);
		logo.y = menuItems.members[0].y - logo.height - 30;
		logo.scrollFactor.set(0, 0);
		add(logo);

		changeItem();

		#if android
		addVirtualPad(UP_DOWN, A_B_E);
		#end

		super.create();
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (!selectedSomethin)
		{
			// TOQUE NOS BOTÕES E NA LOGO
			if(FlxG.mouse.overlaps(logo) && FlxG.mouse.justPressed) {
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			menuItems.forEach(function(spr:FlxSprite) {
				if(FlxG.mouse.overlaps(spr)) {
					if(curSelected != spr.ID) {
						curSelected = spr.ID;
						changeItem();
						FlxG.sound.play(Paths.sound('scrollMenu'));
					}
					if(FlxG.mouse.justPressed) {
						selectOption();
					}
				}
			});

			if (controls.UI_UP_P) { changeItem(-1); FlxG.sound.play(Paths.sound('scrollMenu')); }
			if (controls.UI_DOWN_P) { changeItem(1); FlxG.sound.play(Paths.sound('scrollMenu')); }
			if (controls.BACK) {
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}
			if (controls.ACCEPT) { selectOption(); }
		}

		super.update(elapsed);
	}

	function selectOption()
	{
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		if(ClientPrefs.data.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);

		menuItems.forEach(function(spr:FlxSprite) {
			if (curSelected != spr.ID) {
				FlxTween.tween(spr, {alpha: 0}, 0.4, {ease: FlxEase.quadOut, onComplete: function(twn:FlxTween) { spr.kill(); }});
			} else {
				FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker) {
					var daChoice:String = optionShit[curSelected];
					switch (daChoice) {
						case 'story_mode': MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay': MusicBeatState.switchState(new FreeplayState());
						case 'mods': MusicBeatState.switchState(new ModsMenuState());
						case 'awards': MusicBeatState.switchState(new AchievementsMenuState());
						case 'credits': MusicBeatState.switchState(new CreditsState());
						case 'options': MusicBeatState.switchState(new OptionsState());
					}
				});
			}
		});
	}

	function changeItem(huh:Int = 0)
	{
		curSelected += huh;
		if (curSelected >= menuItems.length) curSelected = 0;
		if (curSelected < 0) curSelected = menuItems.length - 1;

		menuItems.forEach(function(spr:FlxSprite) {
			spr.animation.play('idle');
			spr.updateHitbox();
			if (spr.ID == curSelected) {
				spr.animation.play('selected');
				spr.centerOffsets();
			}
		});
	}

	// EFEITO DE BUMPING NA LOGO
	override function beatHit()
	{
		super.beatHit();
		if(logo != null) {
			logo.scale.set(0.28, 0.28);
			FlxTween.tween(logo.scale, {x: 0.25, y: 0.25}, 0.2, {ease: FlxEase.quadOut});
		}
	}
}
