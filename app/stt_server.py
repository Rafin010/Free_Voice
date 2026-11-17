"""Local Speech-to-Text HTTP server for FreeVoice (AutoHotkey v2 companion)."""

from __future__ import annotations

import configparser
import io
import json
import os
import threading
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional

import numpy as np
import sounddevice as sd
from faster_whisper import WhisperModel

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.ini"

SAMPLE_RATE = 16000
CHANNELS = 1


def load_config() -> dict[str, str]:
    parser = configparser.ConfigParser()
    defaults = {
        "Mode": "toggle",
        "Language": "auto",
        "Model": "base",
        "Port": "8765",
    }
    if CONFIG_PATH.exists():
        parser.read(CONFIG_PATH, encoding="utf-8")
        if parser.has_section("General"):
            for key in defaults:
                if parser.has_option("General", key):
                    defaults[key] = parser.get("General", key).strip()
    return defaults


class STTEngine:
    """Manages microphone capture and faster-whisper transcription."""

    def __init__(self, model_size: str = "base") -> None:
        self.model_size = model_size
        self._model: Optional[WhisperModel] = None
        self._model_lock = threading.Lock()
        self._model_ready = threading.Event()

        self._rec_lock = threading.Lock()
        self._recording = False
        self._frames: list[np.ndarray] = []
        self._stream: Optional[sd.InputStream] = None

        threading.Thread(target=self._load_model, daemon=True).start()

    def _load_model(self) -> None:
        with self._model_lock:
            if self._model is None:
                self._model = WhisperModel(
                    self.model_size,
                    device="cpu",
                    compute_type="int8",
                )
            self._model_ready.set()

    def reload_model(self, new_model_size: str) -> bool:
        allowed = {"tiny", "base", "small", "medium"}
        target = new_model_size.strip().lower()
        if target not in allowed:
            return False
        if target == self.model_size and self._model is not None:
            return True
        self._model_ready.clear()

        def _worker() -> None:
            with self._model_lock:
                self.model_size = target
                self._model = WhisperModel(
                    self.model_size,
                    device="cpu",
                    compute_type="int8",
                )
                self._model_ready.set()

        threading.Thread(target=_worker, daemon=True).start()
        return True

    def is_ready(self) -> bool:
        return self._model_ready.is_set()

    def is_recording(self) -> bool:
        with self._rec_lock:
            return self._recording

    def start_recording(self) -> bool:
        with self._rec_lock:
            if self._recording:
                return False
            self._frames = []

            def callback(indata: np.ndarray, frames: int, time_info, status) -> None:
                if self._recording:
                    self._frames.append(indata.copy())

            self._stream = sd.InputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype="int16",
                callback=callback,
            )
            self._recording = True
            self._stream.start()
            return True

    def stop_and_transcribe(self, language: str = "auto") -> str:
        with self._rec_lock:
            if not self._recording:
                return ""
            self._recording = False
            stream = self._stream
            self._stream = None
            frames = list(self._frames)
            self._frames = []

        if stream is not None:
            stream.stop()
            stream.close()

        if not frames:
            return ""

        audio_data = np.concatenate(frames, axis=0)
        # Skip very short accidental taps (< 0.15s)
        if len(audio_data) < int(SAMPLE_RATE * 0.15):
            return ""

        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, "wb") as wf:
            wf.setnchannels(CHANNELS)
            wf.setsampwidth(2)  # int16 = 2 bytes
            wf.setframerate(SAMPLE_RATE)
            wf.writeframes(audio_data.tobytes())
        wav_buffer.seek(0)

        self._model_ready.wait()
        with self._model_lock:
            assert self._model is not None
            lang_arg = None if language in ("", "auto") else language
            segments, _ = self._model.transcribe(
                wav_buffer,
                language=lang_arg,
                beam_size=1,
                vad_filter=True,
            )
            text = " ".join(seg.text.strip() for seg in segments if seg.text.strip())
        return " ".join(text.split())


def make_handler(engine: STTEngine, server_ref: dict[str, ThreadingHTTPServer]):
    class RequestHandler(BaseHTTPRequestHandler):
        def _send_json(self, code: int, payload: dict) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:
            if self.path == "/health":
                self._send_json(
                    200,
                    {
                        "status": "ready" if engine.is_ready() else "loading",
                        "recording": engine.is_recording(),
                        "model": engine.model_size,
                    },
                )
                return
            self._send_json(404, {"error": "Not found"})

        def do_POST(self) -> None:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length > 0 else b"{}"
            try:
                data = json.loads(raw.decode("utf-8")) if raw else {}
            except json.JSONDecodeError:
                data = {}

            if self.path == "/start":
                started = engine.start_recording()
                self._send_json(200, {"started": started})
                return

            if self.path == "/stop":
                cfg = load_config()
                language = data.get("language") or cfg.get("Language", "auto")
                text = engine.stop_and_transcribe(language=language)
                self._send_json(200, {"text": text})
                return

            if self.path == "/reload":
                new_model = str(data.get("model", "")).strip()
                ok = engine.reload_model(new_model)
                if ok:
                    self._send_json(200, {"reloading": True, "model": new_model})
                else:
                    self._send_json(400, {"error": "Invalid model name"})
                return

            if self.path == "/shutdown":
                self._send_json(200, {"shutting_down": True})
                threading.Thread(target=server_ref["server"].shutdown, daemon=True).start()
                return

            self._send_json(404, {"error": "Not found"})

        def log_message(self, format: str, *args) -> None:
            # Keep background execution silent
            return

    return RequestHandler


def main() -> None:
    cfg = load_config()
    port = int(cfg.get("Port", "8765"))
    model_size = cfg.get("Model", "base")

    engine = STTEngine(model_size=model_size)
    server_ref: dict[str, ThreadingHTTPServer] = {}
    server = ThreadingHTTPServer(("127.0.0.1", port), make_handler(engine, server_ref))
    server_ref["server"] = server

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
