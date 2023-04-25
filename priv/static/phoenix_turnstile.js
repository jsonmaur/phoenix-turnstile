export const TurnstileHook = {
  mounted() {
    turnstile.render(this.el)

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
