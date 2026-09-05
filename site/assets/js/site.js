// Progressive enhancement only. Without this file the page still reads: the
// theme follows the system, the table of contents is simply absent, and the
// dependency line is selectable by hand.
(function () {
  "use strict";

  var root = document.documentElement;

  /* ---------- theme ---------- */

  var ORDER = ["auto", "light", "dark"];
  var LABEL = { auto: "Auto", light: "Light", dark: "Dark" };

  // Shared with the other project pages under this domain; see the note in
  // the layout's head script.
  var KEY = "rllvm-theme";

  var toggle = document.querySelector("[data-theme-toggle]");
  var label = document.querySelector("[data-theme-label]");

  function paint(theme) {
    root.dataset.theme = theme;
    if (label) label.textContent = LABEL[theme];
    if (toggle) toggle.setAttribute("aria-label", "Theme: " + LABEL[theme]);
  }

  if (toggle) {
    var stored = null;
    try {
      stored = localStorage.getItem(KEY);
    } catch (e) {}
    paint(ORDER.indexOf(stored) > -1 ? stored : "auto");

    toggle.addEventListener("click", function () {
      var next = ORDER[(ORDER.indexOf(root.dataset.theme) + 1) % ORDER.length];
      paint(next);
      try {
        if (next === "auto") localStorage.removeItem(KEY);
        else localStorage.setItem(KEY, next);
      } catch (e) {}
    });
  }

  /* ---------- copy the dependency line ---------- */

  document.querySelectorAll("[data-copy]").forEach(function (button) {
    if (!navigator.clipboard) return;
    button.addEventListener("click", function () {
      navigator.clipboard.writeText(button.dataset.copy).then(function () {
        var was = button.textContent;
        button.textContent = "Copied";
        setTimeout(function () {
          button.textContent = was;
        }, 1600);
      });
    });
  });

  /* ---------- table of contents ---------- */

  // Built from the rendered headings rather than from the markdown, so the
  // anchors always match the ids kramdown actually emitted.
  var rail = document.querySelector(".rail");
  var nav = document.querySelector("[data-toc]");
  var headings = document.querySelectorAll(".prose h2[id], .prose h3[id]");

  if (rail && nav && headings.length > 2) {
    headings.forEach(function (heading) {
      var link = document.createElement("a");
      link.href = "#" + heading.id;
      link.textContent = heading.textContent;
      if (heading.tagName === "H3") link.className = "sub";
      nav.appendChild(link);
    });
    rail.hidden = false;

    var links = {};
    nav.querySelectorAll("a").forEach(function (link) {
      links[link.getAttribute("href").slice(1)] = link;
    });

    var current = null;
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          if (current) current.removeAttribute("aria-current");
          current = links[entry.target.id];
          if (current) current.setAttribute("aria-current", "true");
        });
      },
      { rootMargin: "-4rem 0px -70% 0px" }
    );

    headings.forEach(function (heading) {
      observer.observe(heading);
    });
  }
})();
