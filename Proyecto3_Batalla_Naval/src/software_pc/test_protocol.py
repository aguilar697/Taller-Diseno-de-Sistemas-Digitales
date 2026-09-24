import unittest

from naval_terminal import (
    Frame,
    FrameParser,
    SOF,
    TYPE_BATTLE_START,
    TYPE_PLACE_SHIP,
    TYPE_SHOT,
    TYPE_TURN,
    build_frame,
)


class BuildFrameTests(unittest.TestCase):
    def test_build_place_ship(self):
        frame = build_frame(TYPE_PLACE_SHIP, (1, 2, 3, 0))
        self.assertEqual(frame, bytes((SOF, TYPE_PLACE_SHIP, 4, 1, 2, 3, 0)))

    def test_build_shot(self):
        frame = build_frame(TYPE_SHOT, (6, 7))
        self.assertEqual(frame, bytes((SOF, TYPE_SHOT, 2, 6, 7)))


class FrameParserTests(unittest.TestCase):
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
        data = bytes((0x00, 0x11, 0xFF, 0x34)) + build_frame(TYPE_BATTLE_START)
        self.assertEqual(parser.feed(data), [Frame(TYPE_BATTLE_START, b"")])

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
        valid = build_frame(TYPE_BATTLE_START)
        self.assertEqual(
            parser.feed(invalid + valid),
            [Frame(TYPE_BATTLE_START, b"")],
        )


if __name__ == "__main__":
    unittest.main()
