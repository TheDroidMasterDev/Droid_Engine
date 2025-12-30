package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUI;
import flixel.ui.FlxButton;
import haxe.io.Bytes;
import backend.Song;
import backend.Section;
import backend.Conductor;
import backend.Paths;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

class ChartingState extends MusicBeatState
{
    var _song:SwagSong;
    var UI_box:FlxUITabMenu;
    var midiMenu:FlxSpriteGroup;
    var curMidiChannel:Int = 0;

    override function create() {
        _song = PlayState.SONG;
        
        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF222222;
        add(bg);

        var tabs = [{name: "Song", label: 'Song'}];
        UI_box = new FlxUITabMenu(null, tabs, true);
        UI_box.resize(300, 200);
        UI_box.x = FlxG.width - 350;
        add(UI_box);

        addSongUI();
        super.create();
    }

    function addSongUI() {
        var tab_group = new FlxUI(null, UI_box);
        tab_group.name = "Song";
        
        var btn = new FlxButton(10, 20, "Import MIDI", function() {
            openMidiMenu();
        });
        tab_group.add(btn);
        UI_box.addGroup(tab_group);
    }

    function openMidiMenu() {
        if(midiMenu != null) midiMenu.destroy();
        midiMenu = new FlxSpriteGroup();
        
        var box = new FlxSprite().makeGraphic(500, 300, FlxColor.BLACK);
        box.screenCenter();
        box.alpha = 0.8;
        midiMenu.add(box);

        var txt = new FlxText(box.x, box.y + 50, 500, "TOQUE AQUI PARA\nPROCESSAR .Droid_Engine/midi2charts/song.mid", 20);
        txt.alignment = CENTER;
        midiMenu.add(txt);
        add(midiMenu);
    }

    override function update(elapsed:Float) {
        if (midiMenu != null && midiMenu.visible && FlxG.mouse.justPressed) {
            if (FlxG.mouse.overlaps(midiMenu)) {
                processMidiToChart();
                midiMenu.visible = false;
            }
        }
        super.update(elapsed);
    }

    function processMidiToChart() {
        #if sys
        var rootPath:String = '/storage/emulated/0/.Droid_Engine/midi2charts/song.mid';
        var internalPath:String = Paths.getPreloadPath('midi2charts/song.mid');
        var path:String = FileSystem.exists(rootPath) ? rootPath : internalPath;

        if (FileSystem.exists(path)) {
            var bytes:Bytes = File.getBytes(path);
            for (sec in _song.notes) sec.sectionNotes = [];

            var i:Int = 14; 
            while(i < bytes.length - 3) {
                var status = bytes.get(i);
                if ((status & 0xF0) == 0x90) { 
                    var pitch = bytes.get(i + 1);
                    var vel = bytes.get(i + 2);
                    if (vel > 0) {
                        var time = (i / bytes.length) * FlxG.sound.music.length;
                        var lane = pitch % 4;
                        var secIdx = Std.int(time / (Conductor.stepCrochet * 16));
                        if(_song.notes[secIdx] != null) _song.notes[secIdx].sectionNotes.push([time, lane, 0]);
                    }
                    i += 3;
                } else i++;
            }
            FlxG.resetState();
        }
        #end
    }
}
