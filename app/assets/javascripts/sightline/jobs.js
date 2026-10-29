// Jobs' two scripts, in place of Mission Control – Jobs' own, whose import map would clash with the app's.
// A plain script with no imports, so it works whatever the app loads, Turbo or not.
(() => {
  const page = document.documentElement;
  // Turbo runs the body's scripts again on every visit; the listeners below are added once.
  if (page.dataset.slJobs) return;
  page.dataset.slJobs = "on";

  // A filter applies as soon as it changes, as Mission Control's "form" controller does.
  document.addEventListener("change", (event) => {
    const form = event.target.closest && event.target.closest('form[data-controller~="form"]');
    if (form) form.requestSubmit();
  });

  // Deleting asks first. When the app runs Turbo, Turbo asks instead.
  document.addEventListener("submit", (event) => {
    const question = event.target.dataset && event.target.dataset.turboConfirm;
    if (question && !window.Turbo && !window.confirm(question)) event.preventDefault();
  });
})();
