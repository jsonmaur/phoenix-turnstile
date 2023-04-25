function callbackEvent(self, name, eventName) {
  return (payload) => {
    const events = self.el.dataset.events || ""

    if (events.split(",").indexOf(name) > -1) {
      self.pushEventTo(self.el, `turnstile:${eventName || name}`, payload)
    }
  }
}

export const TurnstileHook = {
  mounted() {
    turnstile.render(this.el, {
      callback: callbackEvent(this, "success"),
      "error-callback": callbackEvent(this, "error"),
      "expired-callback": callbackEvent(this, "expired"),
      "before-interactive-callback": callbackEvent(this, "beforeInteractive", "before-interactive"),
      "after-interactive-callback": callbackEvent(this, "afterInteractive", "after-interactive"),
      "unsupported-callback": callbackEvent(this, "unsupported"),
      "timeout-callback": callbackEvent(this, "timeout")
    })

    this.handleEvent("turnstile:refresh", (event) => {
      if (!event.id || event.id === this.el.id) {
        turnstile.reset(this.el)
      }
    })

    this.handleEvent("turnstile:remove", (event) => {
      if (!event.id || event.id === this.el.id) {
        turnstile.remove(this.el)
      }
    })
  }
}
