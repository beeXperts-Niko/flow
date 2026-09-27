(function () {
  "use strict";

  var dialog = document.getElementById("lightbox");
  if (!dialog || typeof dialog.showModal !== "function") {
    return;
  }

  var image = dialog.querySelector(".lightbox-image");
  var caption = dialog.querySelector(".lightbox-caption");
  var closeButton = dialog.querySelector(".lightbox-close");
  var lastTrigger = null;

  function open(link) {
    var thumb = link.querySelector("img");
    image.src = link.getAttribute("href");
    image.alt = thumb ? thumb.alt : "";
    caption.textContent = link.getAttribute("data-caption") || "";
    lastTrigger = link;
    dialog.showModal();
    dialog.scrollTop = 0;
  }

  document.querySelectorAll("a[data-lightbox]").forEach(function (link) {
    link.addEventListener("click", function (event) {
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) {
        return;
      }
      event.preventDefault();
      open(link);
    });
  });

  closeButton.addEventListener("click", function () {
    dialog.close();
  });

  dialog.addEventListener("click", function (event) {
    if (event.target === dialog) {
      dialog.close();
    }
  });

  dialog.addEventListener("close", function () {
    image.removeAttribute("src");
    if (lastTrigger) {
      lastTrigger.focus();
    }
  });
})();
