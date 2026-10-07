"""Pruebas de las fases de la terminal con una conexión serial controlada."""

from collections import deque
from contextlib import redirect_stdout
import io
import unittest
from unittest.mock import patch

import naval_terminal as nt


class PlacementConnection:
    def __init__(self):
        self.frames = deque()
        self.sent = []
        self.placed = set()

    def pending(self):
        return []

    def send(self, kind, payload):
        self.sent.append((kind, tuple(payload)))
        ship = payload[0]
        if len(self.sent) == 1:
            # El anuncio inicial llega después de enviar PLACE y antes de su ACK.
            self.frames.append(nt.Frame(nt.TYPE_PLACEMENT_START, bytes((0, 0))))
        accepted = ship not in self.placed
        self.placed.add(ship)
        self.frames.append(nt.Frame(nt.TYPE_PLACE_RESULT, bytes((ship, int(accepted), 0 if accepted else 4))))

    def receive(self):
        return self.frames.popleft()


class TerminalTests(unittest.TestCase):
    def test_reset_preserves_later_queued_notifications(self):
        connection = nt.SerialConnection("sin_puerto")
        start = nt.Frame(nt.TYPE_PLACEMENT_START, bytes((0, 0)))
        later = nt.Frame(nt.TYPE_PLACEMENT_START, bytes((1, 0)))
        connection._frames.put(start)
        connection._frames.put(later)
        state = nt.GameState(placement_started=True)
        with redirect_stdout(io.StringIO()), self.assertRaises(nt.NewGame):
            nt.check_pending_events(connection, state)
        self.assertEqual(connection.receive(timeout=0.01), later)

    def test_session_waits_for_placement_before_sending_commands(self):
        connection = PlacementConnection()
        connection.frames = deque([
            nt.Frame(nt.TYPE_TURN, bytes((2,))),
            nt.Frame(nt.TYPE_PLACEMENT_START, bytes((1, 0))),
        ])
        state = nt.GameState()
        with redirect_stdout(io.StringIO()):
            nt.wait_initial_placement(connection, state)
        self.assertEqual(connection.sent, [])
        self.assertTrue(state.placement_started)
        self.assertFalse(state.new_game)
        self.assertEqual(state.p1_wins, 1)

    def test_reset_during_first_placement_is_recognized_after_start(self):
        connection = PlacementConnection()
        connection.frames.append(nt.Frame(nt.TYPE_PLACEMENT_START, bytes((0, 0))))
        state = nt.GameState()
        with redirect_stdout(io.StringIO()):
            nt.wait_initial_placement(connection, state)
            nt.handle_frame(nt.Frame(nt.TYPE_PLACEMENT_START, bytes((0, 0))), state)
        self.assertTrue(state.new_game)

    def test_initial_announcement_preserves_pending_placement(self):
        connection = PlacementConnection()
        state = nt.GameState()
        with patch("builtins.input", side_effect=["0", "0", "H", "2", "0", "H", "4", "0", "H"]), redirect_stdout(io.StringIO()):
            nt.placement_phase(connection, state)
        self.assertEqual([payload[0] for _, payload in connection.sent], [0, 1, 2])
        self.assertEqual(sum(cell == "S" for row in state.own_board for cell in row), 9)
        self.assertFalse(state.new_game)

    def test_reset_during_keyboard_entry_prevents_stale_command(self):
        connection = PlacementConnection()
        state = nt.GameState(placement_started=True)
        calls = iter([[], [nt.Frame(nt.TYPE_PLACEMENT_START, bytes((1, 0)))]])
        connection.pending = lambda: next(calls)
        with patch("builtins.input", side_effect=["0", "0", "H"]), redirect_stdout(io.StringIO()), self.assertRaises(nt.NewGame):
            nt.placement_phase(connection, state)
        self.assertEqual(connection.sent, [])
        self.assertEqual((state.p1_wins, state.p2_wins), (1, 0))

    def test_repeated_shot_retries_without_another_turn(self):
        connection = PlacementConnection()
        connection.send = lambda kind, payload: connection.sent.append((kind, tuple(payload)))
        connection.frames = deque([
            nt.Frame(nt.TYPE_TURN, bytes((2,))),
            nt.Frame(nt.TYPE_ERROR, bytes((nt.TYPE_SHOT, 4))),
            nt.Frame(nt.TYPE_SHOT_RESULT, bytes((0, 1, 2))),
            nt.Frame(nt.TYPE_GAME_OVER, bytes((2, 8, 9, 0, 3, 0, 1))),
        ])
        state = nt.GameState(placement_started=True)
        with patch("builtins.input", side_effect=["0", "0", "0", "1"]), redirect_stdout(io.StringIO()):
            nt.battle_phase(connection, state)
        self.assertEqual(connection.sent, [(nt.TYPE_SHOT, (0, 0)), (nt.TYPE_SHOT, (0, 1))])
        self.assertTrue(state.game_over)
        self.assertEqual(state.p2_wins, 1)

    def test_game_reset_starts_another_placement_and_keeps_score(self):
        connection = PlacementConnection()
        connection.frames.append(nt.Frame(nt.TYPE_PLACEMENT_START, bytes((1, 2))))
        state = nt.GameState(placement_started=True, game_over=True)
        with redirect_stdout(io.StringIO()):
            nt.wait_new_game(connection, state)
        self.assertTrue(state.new_game)
        state.reset_boards()
        state.new_game = False
        self.assertFalse(state.game_over)
        self.assertEqual((state.p1_wins, state.p2_wins), (1, 2))


if __name__ == "__main__":
    unittest.main()
