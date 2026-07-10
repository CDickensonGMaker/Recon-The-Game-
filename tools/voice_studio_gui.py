"""voice_studio_gui.py - native desktop GUI for the free Piper voice generator.

A real window: type a line, pick a voice + treatment, hit Speak (hear it) or Save.
Uses the Piper voices in tools/tts/piper/ + audio_dsp.py radio processing. tkinter +
winsound are built into Python on Windows - no install. Launch: double-click
voice_studio_gui.bat, or `python tools/voice_studio_gui.py`.
"""
from __future__ import annotations
import os, sys, tempfile, threading
import tkinter as tk
from tkinter import ttk, filedialog

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voice_studio as VS  # noqa: E402
import audio_dsp as D      # noqa: E402

try:
    import winsound
    def _play(p: str) -> None:
        winsound.PlaySound(p, winsound.SND_FILENAME | winsound.SND_ASYNC)
except Exception:
    import subprocess
    def _play(p: str) -> None:
        subprocess.Popen(["powershell", "-NoProfile", "-c",
                          f"(New-Object System.Media.SoundPlayer '{p}').PlaySync()"])

BG, FG, ACC = "#1a1c17", "#c7d0b8", "#8ba36b"

class App:
    def __init__(self, root: tk.Tk):
        self.root = root
        root.title("RECONgame VOICE STUDIO")
        root.configure(bg=BG)
        root.geometry("620x360")
        self._tmp = os.path.join(tempfile.gettempdir(), "vo_gui.wav")

        tk.Label(root, text="CALL FOR FIRE  //  VOICE STUDIO", bg=BG, fg=ACC,
                 font=("Consolas", 14, "bold")).pack(pady=(12, 2))
        tk.Label(root, text="free  -  Piper neural TTS + audio_dsp radio processing", bg=BG,
                 fg="#6d7560", font=("Consolas", 9)).pack()

        top = tk.Frame(root, bg=BG); top.pack(pady=10)
        tk.Label(top, text="voice", bg=BG, fg=FG, font=("Consolas", 10)).grid(row=0, column=0, padx=6)
        self.voice = tk.StringVar(value=("ryan" if "ryan" in VS.voices() else (VS.voices() or [""])[0]))
        ttk.Combobox(top, textvariable=self.voice, values=VS.voices(), width=16,
                     state="readonly").grid(row=0, column=1, padx=6)
        tk.Label(top, text="treatment", bg=BG, fg=FG, font=("Consolas", 10)).grid(row=0, column=2, padx=6)
        self.profile = tk.StringVar(value="radio")
        ttk.Combobox(top, textvariable=self.profile, values=list(VS.PROFILES), width=10,
                     state="readonly").grid(row=0, column=3, padx=6)

        self.text = tk.Text(root, height=4, width=64, bg="#23261f", fg=FG,
                            insertbackground=FG, font=("Consolas", 12), wrap="word",
                            relief="flat", padx=8, pady=8)
        self.text.pack(pady=8)
        self.text.insert("1.0", "All stations, this is Recon Two-Four. Fire mission, over.")
        self.text.bind("<Control-Return>", lambda e: self.speak())

        btns = tk.Frame(root, bg=BG); btns.pack(pady=6)
        self._mk(btns, "▶  SPEAK  (Ctrl+Enter)", self.speak).pack(side="left", padx=6)
        self._mk(btns, "\U0001f4be  SAVE…", self.save).pack(side="left", padx=6)

        self.status = tk.Label(root, text="ready", bg=BG, fg="#6d7560", font=("Consolas", 9))
        self.status.pack(pady=(8, 0))

    def _mk(self, parent, label, cmd):
        return tk.Button(parent, text=label, command=cmd, bg=ACC, fg=BG,
                         activebackground="#a6bd85", font=("Consolas", 11, "bold"),
                         relief="flat", padx=14, pady=6, cursor="hand2")

    def _line(self) -> str:
        return self.text.get("1.0", "end").strip()

    def _gen_async(self, done):
        line = self._line()
        if not line:
            self.status.config(text="type a line first"); return
        self.status.config(text="generating…")
        def run():
            try:
                y = VS.generate(line, self.voice.get(), self.profile.get())
                self.root.after(0, lambda: done(y))
            except Exception as ex:
                self.root.after(0, lambda: self.status.config(text=f"error: {ex}"))
        threading.Thread(target=run, daemon=True).start()

    def speak(self):
        def done(y):
            D.write_wav(self._tmp, y); _play(self._tmp)
            self.status.config(text=f"played  [{self.voice.get()} / {self.profile.get()}]")
        self._gen_async(done)

    def save(self):
        p = filedialog.asksaveasfilename(defaultextension=".wav", filetypes=[("WAV", "*.wav")])
        if not p:
            return
        def done(y):
            D.write_wav(p, y); self.status.config(text=f"saved  {p}")
        self._gen_async(done)

if __name__ == "__main__":
    r = tk.Tk()
    App(r)
    r.mainloop()
