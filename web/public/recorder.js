// Explicit foreground-only browser audio capture. No speech service is contacted.
export class LocalRecorder {
  constructor({ onState = () => {}, onStop = () => {} } = {}) {
    this.onState = onState;
    this.onStop = onStop;
    this.stream = null;
    this.recorder = null;
    this.chunks = [];
    this.bytes = 0;
    this.stopping = false;
    this.seconds = 0;
  }
  async start() {
    if (this.recorder) throw Error("This recording has already started.");
    if (
      !navigator.mediaDevices?.getUserMedia ||
      typeof MediaRecorder === "undefined"
    )
      throw Error(
        "Audio recording is unavailable in this browser. Use a typed note or paste a transcript.",
      );
    this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    if (this.stopping) {
      this.stream.getTracks().forEach((track) => track.stop());
      throw Error("Recording was cancelled.");
    }
    try {
      const mime = [
        "audio/webm;codecs=opus",
        "audio/mp4",
        "audio/ogg;codecs=opus",
        "audio/webm",
      ].find((type) => MediaRecorder.isTypeSupported(type));
      this.recorder = new MediaRecorder(
        this.stream,
        mime ? { mimeType: mime } : {},
      );
      this.recorder.addEventListener("dataavailable", (event) => {
        if (event.data.size) {
          this.chunks.push(event.data);
          this.bytes += event.data.size;
          if (this.bytes > 15 * 1024 * 1024) this.stop();
        }
      });
      this.recorder.addEventListener(
        "stop",
        () => {
          clearInterval(this.timer);
          this.stream?.getTracks().forEach((track) => track.stop());
          const blob = new Blob(this.chunks, {
            type: this.recorder.mimeType || "audio/webm",
          });
          this.onState("stopped", this.seconds);
          this.onStop(blob);
        },
        { once: true },
      );
      this.recorder.addEventListener("error", () => this.stop());
      this.visibility = () => {
        if (document.visibilityState !== "visible") this.stop();
      };
      this.unload = () => this.stop();
      document.addEventListener("visibilitychange", this.visibility);
      window.addEventListener("pagehide", this.unload);
      this.recorder.start(1000);
      this.onState("recording", 0);
      this.timer = setInterval(() => {
        if (this.recorder.state === "recording") this.seconds++;
        this.onState(this.recorder.state, this.seconds);
        if (this.seconds >= 600) this.stop();
      }, 1000);
    } catch (error) {
      this.stream.getTracks().forEach((track) => track.stop());
      throw error;
    }
  }
  pause() {
    if (this.recorder?.state === "recording") {
      this.recorder.pause();
      this.onState("paused", this.seconds);
    }
  }
  resume() {
    if (this.recorder?.state === "paused") {
      this.recorder.resume();
      this.onState("recording", this.seconds);
    }
  }
  stop() {
    if (this.stopping) return;
    this.stopping = true;
    clearInterval(this.timer);
    document.removeEventListener("visibilitychange", this.visibility);
    window.removeEventListener("pagehide", this.unload);
    if (this.recorder && this.recorder.state !== "inactive")
      this.recorder.stop();
    else this.stream?.getTracks().forEach((track) => track.stop());
  }
}
