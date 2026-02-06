// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.CopyToClipboard = {
  mounted() {
    this.handleEvent("copy-to-clipboard", ({text}) => {
      navigator.clipboard.writeText(text).then(() => {
        setTimeout(() => {
          this.pushEvent("reset_copy", {})
        }, 2000)
      })
    })
  }
}

Hooks.PlayerCache = {
  mounted() {
    // Wait for the element to be fully connected before loading data
    // This ensures the LiveView WebSocket connection is established
    const sessionId = this.el.dataset.sessionId
    
    // Only proceed if we have a valid session ID
    if (!sessionId || sessionId === "" || sessionId === "null" || sessionId === "undefined") {
      console.log("PlayerCache: No valid session ID found, skipping cache load")
      return
    }
    
    console.log("PlayerCache: Loading cached data for session", sessionId)
    
    // Load cached player data on mount
    const cachedName = localStorage.getItem("sideout_player_name") || ""
    const cancellationTokens = JSON.parse(localStorage.getItem("sideout_cancellation_tokens") || "{}")
    const cancellationToken = cancellationTokens[sessionId] || null
    
    console.log("PlayerCache: Found cached name:", cachedName)
    console.log("PlayerCache: Found cancellation token:", cancellationToken ? "yes" : "no")
    
    // Send cached data to server
    this.pushEvent("load_cached_data", {
      name: cachedName,
      cancellation_token: cancellationToken
    })
    
    // Handle save name command from server
    this.handleEvent("save_player_name", ({name}) => {
      console.log("PlayerCache: Saving player name:", name)
      if (name && name.trim() !== "") {
        localStorage.setItem("sideout_player_name", name.trim())
      }
    })
    
    // Handle save cancellation token command from server
    this.handleEvent("save_cancellation_token", ({session_id, token}) => {
      console.log("PlayerCache: Saving cancellation token for session", session_id)
      const tokens = JSON.parse(localStorage.getItem("sideout_cancellation_tokens") || "{}")
      tokens[session_id] = token
      localStorage.setItem("sideout_cancellation_tokens", JSON.stringify(tokens))
      console.log("PlayerCache: Tokens after save:", tokens)
    })
    
    // Handle clear cancellation token command from server
    this.handleEvent("clear_cancellation_token", ({session_id}) => {
      console.log("PlayerCache: Clearing cancellation token for session", session_id)
      const tokens = JSON.parse(localStorage.getItem("sideout_cancellation_tokens") || "{}")
      delete tokens[session_id]
      localStorage.setItem("sideout_cancellation_tokens", JSON.stringify(tokens))
      console.log("PlayerCache: Tokens after clear:", tokens)
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

