/* ============================================================
   8 West Ventures, LLC — site interactions
   Analytics canary source synchronized with
   Seckcey/8west_hostgator_account_all commit
   ee70e2c098b004414b5018248f6bace86ffc295b.
   ============================================================ */
(function () {
  "use strict";

  var CONTACT_EMAIL = "support@8westventures.com";
  var ANALYTICS_SCRIPT = "https://analytics.8westventures.com/script.js";
  var ANALYTICS_WEBSITE_ID = "508def7a-17a5-4510-a49b-a90c0cdafe76";
  var ANALYTICS_ENVIRONMENT = "production";
  var analyticsQueue = [];

  function flushAnalyticsQueue() {
    if (!window.umami || typeof window.umami.track !== "function") return;

    while (analyticsQueue.length) {
      var item = analyticsQueue.shift();
      try {
        window.umami.track(item.name, item.data);
      } catch (_) {
        // Analytics must never interrupt site behavior.
      }
    }
  }

  function trackEvent(name, data) {
    var eventData = data || {};
    eventData.environment = ANALYTICS_ENVIRONMENT;

    if (window.umami && typeof window.umami.track === "function") {
      try {
        window.umami.track(name, eventData);
      } catch (_) {
        // Analytics must fail open.
      }
      return;
    }

    if (analyticsQueue.length < 20) {
      analyticsQueue.push({ name: name, data: eventData });
    }
  }

  function loadAnalytics() {
    if (document.querySelector('script[data-website-id="' + ANALYTICS_WEBSITE_ID + '"]')) return;

    var script = document.createElement("script");
    script.async = true;
    script.src = ANALYTICS_SCRIPT;
    script.setAttribute("data-website-id", ANALYTICS_WEBSITE_ID);
    script.setAttribute("data-domains", "8westventures.com,www.8westventures.com");
    script.setAttribute("data-exclude-search", "true");
    script.setAttribute("data-exclude-hash", "true");
    script.addEventListener("load", flushAnalyticsQueue);
    document.head.appendChild(script);
  }

  function sourceArea(anchor) {
    if (anchor.closest(".hero")) return "hero";
    if (anchor.closest(".site-header")) return "primary_navigation";
    if (anchor.closest("#portfolio")) return "portfolio";
    if (anchor.closest("#intranet")) return "intranet_section";
    if (anchor.closest("#contact")) return "contact";
    if (anchor.closest(".site-footer")) return "footer";
    return "page";
  }

  function trackApprovedLink(anchor) {
    var href = anchor.getAttribute("href") || "";
    var area = sourceArea(anchor);

    if (href === "#contact" && anchor.closest(".hero")) {
      trackEvent("consultation_button_clicked", {
        source_area: "hero",
        destination: "contact"
      });
      return;
    }

    if (/^https:\/\/(?:www\.)?8westit\.com\/?/i.test(href)) {
      trackEvent("portfolio_link_clicked", {
        portfolio_name: "8_west_it",
        destination_category: "portfolio_company",
        source_area: area
      });
      return;
    }

    if (/^https:\/\/ggitsecuritycom\.sharepoint\.com\/sites\/8WestVenturesLLC/i.test(href)) {
      trackEvent("intranet_link_clicked", {
        source_area: area
      });
      return;
    }

    if (/^mailto:/i.test(href)) {
      trackEvent("contact_email_clicked", {
        source_area: area
      });
      return;
    }

    if (/^#[a-z0-9_-]+$/i.test(href)) {
      trackEvent("navigation_clicked", {
        target_section: href.slice(1).toLowerCase(),
        source_area: area
      });
    }
  }

  loadAnalytics();

  document.addEventListener("click", function (event) {
    var target = event.target;
    var anchor = target && target.closest ? target.closest("a[href]") : null;
    if (anchor) trackApprovedLink(anchor);
  });

  /* ---- Current year in footer ---- */
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  /* ---- Sticky header state ---- */
  var header = document.getElementById("siteHeader");
  function onScroll() {
    if (window.scrollY > 40) header.classList.add("scrolled");
    else header.classList.remove("scrolled");
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---- Mobile nav toggle ---- */
  var toggle = document.getElementById("navToggle");
  var nav = document.getElementById("primaryNav");
  function closeNav() {
    nav.classList.remove("open");
    toggle.classList.remove("open");
    toggle.setAttribute("aria-expanded", "false");
  }
  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("open");
      toggle.classList.toggle("open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    nav.querySelectorAll("a").forEach(function (a) {
      a.addEventListener("click", closeNav);
    });
  }

  /* ---- Reveal on scroll ---- */
  var revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add("visible"); });
  }

  /* ---- Contact form ---- */
  var form = document.getElementById("contactForm");
  var statusEl = document.getElementById("formStatus");
  var submitBtn = document.getElementById("submitBtn");
  var formStarted = false;

  function setStatus(msg, type) {
    statusEl.textContent = msg;
    statusEl.className = "form-status" + (type ? " " + type : "");
  }

  function markFormStarted(event) {
    if (formStarted || !form || !form.contains(event.target)) return;

    var field = event.target;
    if (!field || field.type === "hidden" || field.type === "submit" || field.name === "botcheck") return;

    formStarted = true;
    trackEvent("contact_form_started", {
      form_type: "contact",
      source_area: "contact"
    });
  }

  function mailtoFallback(data) {
    var subject = encodeURIComponent("Website inquiry from " + (data.name || "a visitor"));
    var bodyLines = [
      "Name: " + (data.name || ""),
      "Email: " + (data.email || ""),
      "Company: " + (data.company || "—"),
      "",
      data.message || ""
    ];
    var body = encodeURIComponent(bodyLines.join("\n"));
    window.location.href = "mailto:" + CONTACT_EMAIL + "?subject=" + subject + "&body=" + body;
  }

  if (form) {
    form.addEventListener("focusin", markFormStarted);
    form.addEventListener("input", markFormStarted);

    form.addEventListener("submit", function (e) {
      e.preventDefault();

      // Honeypot: if filled, silently drop.
      if (form.botcheck && form.botcheck.checked) return;

      if (!form.checkValidity()) {
        form.reportValidity();
        return;
      }

      var data = {
        name: form.name.value.trim(),
        email: form.email.value.trim(),
        company: form.company.value.trim(),
        message: form.message.value.trim()
      };

      var accessKey = form.access_key ? form.access_key.value.trim() : "";
      var keyConfigured = accessKey && accessKey !== "YOUR_WEB3FORMS_ACCESS_KEY";

      // No service key configured yet → fall back to the visitor's mail client.
      if (!keyConfigured) {
        setStatus("Opening your email app…", "");
        mailtoFallback(data);
        return;
      }

      // Submit to Web3Forms → forwards to support@8westventures.com
      submitBtn.disabled = true;
      var original = submitBtn.textContent;
      submitBtn.textContent = "Sending…";
      setStatus("", "");

      var payload = new FormData(form);

      fetch("https://api.web3forms.com/submit", {
        method: "POST",
        headers: { Accept: "application/json" },
        body: payload
      })
        .then(function (res) { return res.json(); })
        .then(function (json) {
          if (json.success) {
            trackEvent("contact_form_submitted", {
              form_type: "contact",
              result: "success"
            });
            form.reset();
            setStatus("Thank you — your message has been sent. We'll be in touch soon.", "success");
          } else {
            trackEvent("contact_form_failed", {
              form_type: "contact",
              error_class: "provider_rejected"
            });
            setStatus("Something went wrong. Please email " + CONTACT_EMAIL + " directly.", "error");
          }
        })
        .catch(function () {
          trackEvent("contact_form_failed", {
            form_type: "contact",
            error_class: "network_error"
          });
          setStatus("Network error. Please email " + CONTACT_EMAIL + " directly.", "error");
        })
        .finally(function () {
          submitBtn.disabled = false;
          submitBtn.textContent = original;
        });
    });
  }
})();
