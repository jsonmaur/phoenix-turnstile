export const TurnstileHook = {
  mounted() {
    turnstile.render(this.el)

    this.handleEvent("turnstile:refresh", (event) => {
      if (!event.id || event.id === this.el.id) {
        this.updated()
      }
    })

    this.handleEvent("turnstile:remove", (event) => {
      if (!event.id || event.id === this.el.id) {
        this.destroyed()
      }
    })
  },

  updated() {
    turnstile.reset(this.el)
  },

  destroyed() {
    turnstile.remove(this.el)
  }
}
