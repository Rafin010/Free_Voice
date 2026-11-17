const DOWNLOAD_URL = "FreeVoice-Setup.exe";

const DEMO_SAMPLES = [
  "Hello, please send the updated project report before 5 PM.",
  "Notes from today: keep the interface simple, fast, and reliable.",
  "Ready to paste directly into Chrome, VS Code, Word, or Notepad."
];

document.addEventListener("DOMContentLoaded", () => {
  initRevealAnimations();
  initSmoothScroll();
  initDownloadFeedback();
  initHotkeyDemo();
});

function initRevealAnimations() {
  const sections = document.querySelectorAll(".reveal");
  if (!("IntersectionObserver" in window)) {
    sections.forEach((el) => el.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries, obs) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          obs.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.08 }
  );

  sections.forEach((el) => observer.observe(el));
}

function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", (event) => {
      const targetId = anchor.getAttribute("href");
      if (!targetId || targetId === "#") {
        return;
      }
      const target = document.querySelector(targetId);
      if (target) {
        event.preventDefault();
        target.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  });
}

function initDownloadFeedback() {
  const downloadBtn = document.getElementById("download-btn");
  if (!downloadBtn) {
    return;
  }
  if (DOWNLOAD_URL) {
    downloadBtn.setAttribute("href", DOWNLOAD_URL);
  }
  const originalText = downloadBtn.textContent.trim();
  downloadBtn.addEventListener("click", () => {
    downloadBtn.textContent = "Downloading FreeVoice-Setup.exe...";
    window.setTimeout(() => {
      downloadBtn.textContent = originalText;
    }, 2400);
  });
}

function initHotkeyDemo() {
  const triggerBtn = document.getElementById("demo-trigger");
  const btnLabel = document.getElementById("demo-btn-label");
  const pill = document.getElementById("demo-pill");
  const pillText = document.getElementById("demo-pill-text");
  const output = document.getElementById("demo-output");

  if (!triggerBtn || !btnLabel || !pill || !pillText || !output) {
    return;
  }

  let state = "idle";
  let sampleIndex = 0;

  function setDemoState(nextState) {
    state = nextState;
    pill.setAttribute("data-state", nextState);

    if (nextState === "listening") {
      pillText.textContent = "Listening...";
      btnLabel.textContent = "Press ` again to stop";
      output.innerHTML = '<span class="demo-placeholder">Listening continuously until you press ` again...</span>';
    } else if (nextState === "transcribing") {
      pillText.textContent = "Transcribing...";
      btnLabel.textContent = "Transcribing speech...";
    } else {
      pillText.textContent = "Idle";
      btnLabel.textContent = "Click here or press ` key";
    }
  }

  function toggleDemo() {
    if (state === "transcribing") {
      return;
    }
    if (state === "idle") {
      setDemoState("listening");
      return;
    }
    if (state === "listening") {
      setDemoState("transcribing");
      window.setTimeout(() => {
        const text = DEMO_SAMPLES[sampleIndex % DEMO_SAMPLES.length];
        sampleIndex += 1;
        output.textContent = text;
        setDemoState("idle");
      }, 450);
    }
  }

  triggerBtn.addEventListener("click", toggleDemo);

  document.addEventListener("keydown", (event) => {
    if (event.repeat || event.ctrlKey || event.altKey || event.metaKey) {
      return;
    }
    const tag = event.target && event.target.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA") {
      return;
    }
    if (event.code === "Backquote" || event.key === "`") {
      event.preventDefault();
      toggleDemo();
    }
  });
}
