#!/usr/bin/env python3
import gi
gi.require_version("Playerctl", "2.0")
from gi.repository import Playerctl, GLib
from gi.repository.Playerctl import Player
import argparse
import logging
import sys
import signal
import os
from typing import List
import json

logger = logging.getLogger(__name__)

def signal_handler(sig, frame):
    sys.stdout.write("\n")
    sys.stdout.flush()
    sys.exit(0)

class PlayerManager:
    def __init__(self, player_name=None, exclude_list=[]):
        self.manager = Playerctl.PlayerManager()
        self.loop = GLib.MainLoop()
        self.manager.connect("name-appeared", self.on_player_appeared)
        self.manager.connect("player-vanished", self.on_player_vanished)

        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)

        self.selected_player = player_name
        self.excluded_player = exclude_list.split(',') if exclude_list else []

        self.init_players()

    def init_players(self):
        for p in self.manager.props.player_names:
            if p.name in self.excluded_player:
                continue
            if self.selected_player and self.selected_player != p.name:
                continue
            self.init_player(p)

    def init_player(self, player_obj):
        player = Player.new_from_name(player_obj)
        player.connect("playback-status", self.on_playback_status_changed)
        player.connect("metadata", self.on_metadata_changed)
        self.manager.manage_player(player)
        self.on_metadata_changed(player, player.props.metadata)

    def run(self):
        self.loop.run()

    def get_players(self) -> List[Player]:
        return self.manager.props.players

    def write_output(self, text):
        """Just output the text without icon"""
        output = {
            "text": text,
            "class": "custom-spotify",
        }
        sys.stdout.write(json.dumps(output) + "\n")
        sys.stdout.flush()

    def clear_output(self):
        sys.stdout.write("\n")
        sys.stdout.flush()

    def get_first_playing_player(self):
        players = self.get_players()
        for player in reversed(players):
            if player.props.status == "Playing":
                return player
        return players[0] if players else None

    def show_most_important_player(self):
        current_player = self.get_first_playing_player()
        if current_player:
            self.on_metadata_changed(current_player, current_player.props.metadata)
        else:
            self.clear_output()

    def on_playback_status_changed(self, player, status, *_):
        self.on_metadata_changed(player, player.props.metadata)

    def on_metadata_changed(self, player, metadata, *_):
        artist = player.get_artist() or ""
        title = player.get_title() or ""
        artist = artist.replace("&", "&amp;")
        title = title.replace("&", "&amp;")

        track_info = ""
        try:
            trackid = metadata.get("mpris:trackid", "")
            if player.props.player_name == "spotify" and ":ad:" in trackid:
                track_info = "Advertisement"
            else:
                track_info = f"{artist} - {title}" if artist else title
        except Exception:
            track_info = f"{artist} - {title}" if artist else title

        current_playing = self.get_first_playing_player()
        if not current_playing or current_playing.props.player_name == player.props.player_name:
            self.write_output(track_info)

    def on_player_appeared(self, _, player_obj):
        if player_obj.name in self.excluded_player:
            return
        if not self.selected_player or player_obj.name == self.selected_player:
            self.init_player(player_obj)

    def on_player_vanished(self, _, player):
        self.show_most_important_player()


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="count", default=0)
    parser.add_argument("-x", "--exclude", help="Comma-separated list of excluded players")
    parser.add_argument("--player", help="Player to monitor")
    parser.add_argument("--enable-logging", action="store_true")
    return parser.parse_args()


def main():
    args = parse_arguments()

    if args.enable_logging:
        logfile = os.path.join(os.path.dirname(os.path.realpath(__file__)), "media-player.log")
        logging.basicConfig(filename=logfile, level=logging.DEBUG,
                            format="%(asctime)s %(name)s %(levelname)s:%(lineno)d %(message)s")
    logger.setLevel(max((3 - args.verbose) * 10, 0))

    manager = PlayerManager(player_name=args.player, exclude_list=args.exclude)
    manager.run()


if __name__ == "__main__":
    main()
