"use strict";

for (const button of document.querySelectorAll("[data-copy]")) {
  button.addEventListener("click", async () => {
    const status = document.getElementById("copy-status");
    try {
      await navigator.clipboard.writeText(button.dataset.copy);
      button.textContent = "Copied";
      status.textContent = "Installation path copied to clipboard.";
      window.setTimeout(() => { button.textContent = "Copy"; }, 2000);
    } catch {
      status.textContent = "Could not copy automatically. Select and copy the path beside this button.";
      button.textContent = "Select path";
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(button.previousElementSibling);
      selection.removeAllRanges();
      selection.addRange(range);
    }
  });
}
