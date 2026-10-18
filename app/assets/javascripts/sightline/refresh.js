// Reloads Sightline's Health page every data-sl-refresh seconds, while the tab is visible.
(() => {
  const page = document.querySelector("[data-sl-refresh]");
  const seconds = Number(page && page.dataset.slRefresh);
  if (!seconds) return;
  setInterval(() => { if (document.visibilityState === "visible") location.reload(); }, seconds * 1000);
})();
