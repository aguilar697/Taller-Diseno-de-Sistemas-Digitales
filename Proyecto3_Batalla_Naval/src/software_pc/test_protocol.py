import unittest
from unittest.mock import patch

from naval_terminal import (
    EXPECTED_LENGTHS,
    Frame,
    FrameParser,
    GameState,
    SOF,
    TYPE_BATTLE_START,
    TYPE_ERROR,
    TYPE_GAME_OVER,
    TYPE_INCOMING_SHOT,
    TYPE_PLACE_RESULT,
    TYPE_PLACE_SHIP,
    TYPE_PLACEMENT_START,
    TYPE_SHOT,
    TYPE_SHOT_RESULT,
    TYPE_TURN,
    build_frame,
    handle_frame,
    valid_notification,
)


class BuildFrameTests(unittest.TestCase):
    def test_build_place_ship(self):
        frame = build_frame(TYPE_PLACE_SHIP, (1, 2, 3, 0))
        self.assertEqual(frame, bytes((SOF, TYPE_PLACE_SHIP, 4, 1, 2, 3, 0)))

    def test_build_shot(self):
        frame = build_frame(TYPE_SHOT, (6, 7))
        self.assertEqual(frame, bytes((SOF, TYPE_SHOT, 2, 6, 7)))


class FrameParserTests(unittest.TestCase):
    def test_truncated_frame_expires_before_new_game_announcement(self):
        parser = FrameParser()
        with patch("naval_terminal.time.monotonic", return_value=10.0):
            self.assertEqual(parser.feed(bytes((SOF, TYPE_GAME_OVER, 7, 1))), [])
        with patch("naval_terminal.time.monotonic", return_value=11.0):
            self.assertEqual(parser.feed(build_frame(TYPE_PLACEMENT_START, (0, 0))),
                             [Frame(TYPE_PLACEMENT_START, bytes((0, 0)))])

    def test_fragmented_frame_survives_short_serial_pause(self):
        parser = FrameParser()
        data = build_frame(TYPE_GAME_OVER, (1, 9, 8, 3, 0, 1, 0))
        with patch("naval_terminal.time.monotonic", return_value=10.0):
            self.assertEqual(parser.feed(data[:4]), [])
        with patch("naval_terminal.time.monotonic", return_value=10.1):
            self.assertEqual(parser.feed(b""), [])
        with patch("naval_terminal.time.monotonic", return_value=10.2):
            self.assertEqual(parser.feed(data[4:]), [Frame(TYPE_GAME_OVER, data[3:])])

    def test_complete_frame(self):
        parser = FrameParser()
        frames = parser.feed(build_frame(TYPE_TURN, (2,)))
        self.assertEqual(frames, [Frame(TYPE_TURN, bytes((2,)))])

    def test_byte_by_byte(self):
        parser = FrameParser()
        received = []
        for value in build_frame(TYPE_SHOT, (4, 5)):
            frame = parser.feed_byte(value)
            if frame is not None:
                received.append(frame)
        self.assertEqual(received, [Frame(TYPE_SHOT, bytes((4, 5)))])

    def test_garbage_before_sof(self):
        parser = FrameParser()
        data = bytes((0x00, 0x11, 0xFF, 0x34)) + build_frame(TYPE_BATTLE_START, (1,))
        self.assertEqual(parser.feed(data), [Frame(TYPE_BATTLE_START, bytes((1,)))])

    def test_consecutive_frames(self):
        parser = FrameParser()
        data = build_frame(TYPE_TURN, (1,)) + build_frame(TYPE_SHOT, (3, 6))
        self.assertEqual(
            parser.feed(data),
            [Frame(TYPE_TURN, bytes((1,))), Frame(TYPE_SHOT, bytes((3, 6)))],
        )

    def test_invalid_type(self):
        parser = FrameParser()
        invalid = bytes((SOF, 0x99, 2, 1, 2))
        valid = build_frame(TYPE_TURN, (2,))
        self.assertEqual(parser.feed(invalid + valid), [Frame(TYPE_TURN, bytes((2,)))])

    def test_invalid_length(self):
        parser = FrameParser()
        invalid = bytes((SOF, TYPE_SHOT, 3, 1, 2, 3))
        valid = build_frame(TYPE_BATTLE_START, (1,))
        self.assertEqual(
            parser.feed(invalid + valid),
            [Frame(TYPE_BATTLE_START, bytes((1,)))],
        )

    def test_sof_inside_payload_is_data(self):
        parser = FrameParser()
        frame = build_frame(TYPE_ERROR, (TYPE_SHOT, 4))
        data = build_frame(TYPE_SHOT_RESULT, (SOF, 0, 1)) + frame
        self.assertEqual(
            parser.feed(data),
            [Frame(TYPE_SHOT_RESULT, bytes((SOF, 0, 1))), Frame(TYPE_ERROR, bytes((TYPE_SHOT, 4)))],
        )


class ProtocolAgreementTests(unittest.TestCase):
    """Longitudes de docs/diseno/nivel_3_logica_juego.md, sección 4.6."""

    def test_lengths_match_design(self):
        self.assertEqual(EXPECTED_LENGTHS, {
            TYPE_PLACE_SHIP: 4, TYPE_SHOT: 2, TYPE_PLACE_RESULT: 3,
            TYPE_BATTLE_START: 1, TYPE_TURN: 1, TYPE_SHOT_RESULT: 3,
            TYPE_INCOMING_SHOT: 3, TYPE_GAME_OVER: 7,
            TYPE_PLACEMENT_START: 2, TYPE_ERROR: 2,
        })

    def test_every_fpga_message_is_accepted(self):
        parser = FrameParser()
        frames = [
            build_frame(TYPE_PLACEMENT_START, (0, 0)),
            build_frame(TYPE_PLACE_RESULT, (0, 1, 0)),
            build_frame(TYPE_BATTLE_START, (1,)),
            build_frame(TYPE_TURN, (1,)),
            build_frame(TYPE_INCOMING_SHOT, (2, 3, 1)),
            build_frame(TYPE_SHOT_RESULT, (4, 5, 2)),
            build_frame(TYPE_ERROR, (TYPE_SHOT, 4)),
            build_frame(TYPE_GAME_OVER, (1, 12, 10, 3, 1, 1, 0)),
        ]
        self.assertEqual(len(parser.feed(b"".join(frames))), len(frames))


class HandleFrameTests(unittest.TestCase):
    def test_repeated_shot_asks_again(self):
        state = GameState()
        handle_frame(Frame(TYPE_ERROR, bytes((TYPE_SHOT, 4))), state)
        self.assertTrue(state.retry_shot)

    def test_wrong_turn_does_not_ask_again(self):
        state = GameState()
        handle_frame(Frame(TYPE_ERROR, bytes((TYPE_SHOT, 3))), state)
        self.assertFalse(state.retry_shot)

    def test_game_over_updates_score(self):
        state = GameState()
        handle_frame(Frame(TYPE_GAME_OVER, bytes((2, 9, 11, 1, 3, 4, 5))), state)
        self.assertTrue(state.game_over)
        self.assertEqual((state.p1_wins, state.p2_wins), (4, 5))

    def test_placement_start_signals_new_game(self):
        state = GameState(placement_started=True)
        handle_frame(Frame(TYPE_PLACEMENT_START, bytes((1, 2))), state)
        self.assertTrue(state.new_game)
        self.assertEqual((state.p1_wins, state.p2_wins), (1, 2))

    def test_initial_placement_start_does_not_restart(self):
        state = GameState()
        handle_frame(Frame(TYPE_PLACEMENT_START, bytes((0, 0))), state)
        self.assertFalse(state.new_game)
        self.assertTrue(state.placement_started)

    def test_invalid_coordinates_leave_boards_unchanged(self):
        for message in (TYPE_SHOT_RESULT, TYPE_INCOMING_SHOT):
            state = GameState()
            self.assertFalse(handle_frame(Frame(message, bytes((255, 0, 1))), state))
            self.assertEqual(state.enemy_board, [["?"] * 8 for _ in range(8)])
            self.assertEqual(state.own_board, [["~"] * 8 for _ in range(8)])

    def test_invalid_player_does_not_change_turn(self):
        state = GameState(current_turn=1)
        self.assertFalse(handle_frame(Frame(TYPE_TURN, bytes((3,))), state))
        self.assertEqual(state.current_turn, 1)

    def test_truncated_notification_is_rejected(self):
        self.assertFalse(handle_frame(Frame(TYPE_GAME_OVER, bytes((1, 2))), GameState()))

    def test_invalid_result_is_rejected(self):
        self.assertFalse(valid_notification(Frame(TYPE_SHOT_RESULT, bytes((0, 0, 3)))))

    def test_invalid_placement_acknowledgment_is_rejected(self):
        self.assertFalse(valid_notification(Frame(TYPE_PLACE_RESULT, bytes((3, 1, 0)))))
        self.assertFalse(valid_notification(Frame(TYPE_PLACE_RESULT, bytes((0, 1, 4)))))

    def test_invalid_ship_rejection_echoes_original_identifier(self):
        self.assertTrue(valid_notification(Frame(TYPE_PLACE_RESULT, bytes((255, 0, 3)))))
        self.assertFalse(valid_notification(Frame(TYPE_PLACE_RESULT, bytes((255, 0, 1)))))


if __name__ == "__main__":
    unittest.main()
