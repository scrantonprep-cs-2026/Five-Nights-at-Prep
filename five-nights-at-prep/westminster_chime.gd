class_name WestminsterChime
extends RefCounted

## Keep the uploaded recording and its import settings unchanged.
const SOURCE_PATH = "res://addons/DUFA WESTMINSTER CHIME LONGCASE GRANDFATHER CLOCK - sodaclublad.mp3"
const SOURCE = preload(SOURCE_PATH)

## Each player owns its loop setting; menu looping must never leak into 6 AM.
static func make_stream(looped: bool) -> AudioStreamMP3:
	var stream: AudioStreamMP3 = SOURCE.duplicate() as AudioStreamMP3
	stream.loop = looped
	stream.loop_offset = 0.0
	return stream
