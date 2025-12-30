package states.editors;

import flash.geom.Rectangle;
import tjson.TJSON as Json;
import haxe.format.JsonParser;
import haxe.io.Bytes;

import flixel.FlxObject;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUISlider;
import flixel.addons.ui.FlxUITabMenu;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxSort;
import lime.media.AudioBuffer;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.Assets as OpenFlAssets;

import backend.Song;
import backend.Section;
import backend.StageData;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.HealthIcon;
import objects.AttachedSprite;
import objects.Character;
import substates.Prompt;

#if sys
import flash.media.Sound;
import sys.io.File;
import sys.FileSystem;
#end

#if android
import android.flixel.FlxButton;
#else
import flixel.ui.FlxButton;
#end

@:access(flixel.sound.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)

class ChartingState extends MusicBeatState
{
	public static var noteTypeList:Array<String> = ['', 'Alt Animation', 'Hey!', 'Hurt Note', 'GF Sing', 'No Animation'];
	public var ignoreWarnings = false;
	
	// MIDI SYSTEM VARIABLES
	var midiMenu:FlxSpriteGroup;
	var curMidiChannel:Int = 0;
	var midiInverted:Bool = false;

	var _file:FileReference;
	var UI_box:FlxUITabMenu;
	public static var curSec:Int = 0;
	private static var lastSong:String = '';

	var bpmTxt:FlxText;
	var strumLine:FlxSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var _song:SwagSong;
	
	public static var GRID_SIZE:Int = 40;

	override function create()
	{
		if (PlayState.SONG != null) _song = PlayState.SONG;
		else {
			_song = { song: 'Test', notes: [], events: [], bpm: 150.0, needsVoices: true, player1: 'bf', player2: 'dad', gfVersion: 'gf', speed: 1, stage: 'stage' };
			addSection();
		}

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF222222;
		bg.scrollFactor.set();
		add(bg);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * 9), 4);
		add(strumLine);

		var tabs = [{name: "Song", label: 'Song'}, {name: "Section", label: 'Section'}];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(300, 400);
		UI_box.x = 640;
		UI_box.y = 25;
		add(UI_box);

		addSongUI();
		
		#if android
		addVirtualPad(CHART_EDITOR, CHART_EDITOR);
		#end

		super.create();
	}

	function addSongUI():Void
	{
		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";

		var loadMidiBtn:FlxButton = new FlxButton(10, 10, "Midi 2 Chart", function() {
			openMidiMenu();
		});
		tab_group_song.add(loadMidiBtn);

		UI_box.addGroup(tab_group_song);
	}

	override function update(elapsed:Float)
	{
		updateMidiTouch();
		super.update(elapsed);
	}

	function openMidiMenu() {
		if(midiMenu != null) midiMenu.destroy();
		midiMenu = new FlxSpriteGroup();
		
		var bg:FlxSprite = new FlxSprite().makeGraphic(500, 400, 0xEE000000);
		bg.screenCenter();
		midiMenu.add(bg);

		var txt:FlxText = new FlxText(bg.x, bg.y + 20, 500, "MIDI IMPORT", 20);
		txt.setFormat(null, 20, 0xFFFFFF, CENTER);
		midiMenu.add(txt);

		// Botão Canal (Membro 2 e 3)
		var b1 = new FlxSprite(bg.x + 50, bg.y + 80).makeGraphic(400, 50, 0xFFFF4444);
		midiMenu.add(b1);
		var t1 = new FlxText(b1.x, b1.y + 10, 400, "CANAL: " + curMidiChannel, 18);
		t1.alignment = CENTER;
		midiMenu.add(t1);

		// Botão Lado (Membro 4 e 5)
		var b2 = new FlxSprite(bg.x + 50, bg.y + 160).makeGraphic(400, 50, 0xFF4444FF);
		midiMenu.add(b2);
		var t2 = new FlxText(b2.x, b2.y + 10, 400, "LADO: OPPONENT", 18);
		t2.alignment = CENTER;
		midiMenu.add(t2);

		// Botão Iniciar (Membro 6 e 7)
		var b3 = new FlxSprite(bg.x + 50, bg.y + 260).makeGraphic(400, 70, 0xFF44FF44);
		midiMenu.add(b3);
		var t3 = new FlxText(b3.x, b3.y + 20, 400, "CONVERTER", 22);
		t3.alignment = CENTER;
		midiMenu.add(t3);

		add(midiMenu);
	}

	function updateMidiTouch() {
		if (midiMenu != null && midiMenu.visible && FlxG.mouse.justPressed) {
			if (FlxG.mouse.overlaps(midiMenu.members[2])) {
				curMidiChannel = (curMidiChannel + 1) % 16;
				cast(midiMenu.members[3], FlxText).text = "CANAL: " + curMidiChannel;
			}
			if (FlxG.mouse.overlaps(midiMenu.members[4])) {
				midiInverted = !midiInverted;
				cast(midiMenu.members[5], FlxText).text = "LADO: " + (midiInverted ? "PLAYER" : "OPPONENT");
			}
			if (FlxG.mouse.overlaps(midiMenu.members[6])) {
				processMidiToChart();
				midiMenu.visible = false;
			}
		}
	}

	function processMidiToChart() {
		var path:String = 'assets/midi2charts/song.mid';
		#if sys
		if(FileSystem.exists(path)) {
			var bytes:Bytes = File.getBytes(path);
			for (sec in _song.notes) sec.sectionNotes = [];

			var i:Int = 14; 
			while(i < bytes.length - 3) {
				var status = bytes.get(i);
				if ((status & 0xF0) == 0x90) { // Note On
					var pitch = bytes.get(i + 1);
					var vel = bytes.get(i + 2);
					if (vel > 0) {
						var time = (i / bytes.length) * FlxG.sound.music.length;
						var lane = pitch % 4;
						if (midiInverted) lane += 4;
						var secIdx = Std.int(time / (Conductor.stepCrochet * 16));
						if(_song.notes[secIdx] != null) _song.notes[secIdx].sectionNotes.push([time, lane, 0]);
					}
					i += 3;
				} else i++;
			}
			updateGrid();
		}
		#end
	}

	function addSection(lengthInSteps:Int = 16):Void {
		var sec:Section = { sectionNotes: [], lengthInSteps: lengthInSteps, mustHitSection: true };
		_song.notes.push(sec);
	}

	function updateGrid():Void {
		// Recarrega o grid visualmente
		MusicBeatState.resetState();
	}
}
