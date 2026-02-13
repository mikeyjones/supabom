// LiveView configuration
// The phoenix.min.js and phoenix_live_view.min.js files are loaded before this script
// and provide the global Phoenix and LiveView objects

(function() {
  // Get CSRF token from meta tag
  let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

  // Create LiveSocket using global objects
  let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
    longPollFallbackMs: 2500,
    params: {_csrf_token: csrfToken}
  });

  // Connect the LiveSocket
  liveSocket.connect();

  // Expose liveSocket on window for web console debug logs
  window.liveSocket = liveSocket;

  // Handle flash close
  document.addEventListener("DOMContentLoaded", function() {
    document.querySelectorAll("[role=alert][data-flash]").forEach(function(el) {
      el.addEventListener("click", function() {
        el.setAttribute("hidden", "");
      });
    });
  });
})();
