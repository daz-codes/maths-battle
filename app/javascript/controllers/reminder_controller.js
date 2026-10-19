import { Controller } from "@hotwired/stimulus"

// Daily reminders on the settings page. Turning them on asks to show notifications, subscribes this device
// to push and sends the subscription with the time picked (RemindersController). On an iPhone or iPad, web
// push only works once the app is on the Home Screen and opened from there
export default class extends Controller {
  static targets = [ "time", "on", "off", "status" ]
  static values = { key: String, url: String, on: Boolean }

  async connect() {
    if (!this.supported) {
      this.onTarget.disabled = true
      this.timeTarget.disabled = true
      return this.say(/iPhone|iPad|iPod/.test(navigator.userAgent)
        ? "To get reminders on an iPhone or iPad, add MatheMinute to your Home Screen, then open it from there."
        : "This browser can't show reminders.")
    }
    const subscription = await this.currentSubscription()
    this.showOn(this.onValue && Boolean(subscription) && Notification.permission === "granted")
  }

  get supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  async turnOn() {
    if (await Notification.requestPermission() !== "granted") {
      return this.say("Notifications are blocked for MatheMinute. Allow them in your device's settings, then try again.")
    }
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription() ||
        await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: fromBase64Url(this.keyValue) })
      await this.saveTime(subscription)
    } catch {
      this.say("Reminders couldn't be turned on. Try again.")
    }
  }

  async changeTime() {
    const subscription = await this.currentSubscription()
    if (this.offTarget.hidden || !subscription) return

    try {
      await this.saveTime(subscription)
    } catch {
      this.say("The new time couldn't be saved. Try again.")
    }
  }

  async turnOff() {
    try {
      await this.send("DELETE")
      await (await this.currentSubscription())?.unsubscribe()
      this.showOn(false)
      this.say("Reminders are off.")
    } catch {
      this.say("Reminders couldn't be turned off. Try again.")
    }
  }

  async saveTime(subscription) {
    await this.send("PATCH", { minute: Number(this.timeTarget.value), subscription: subscription.toJSON() })
    this.showOn(true)
    this.say(`You'll get a reminder at ${this.timeTarget.selectedOptions[0].text} on days you haven't played yet.`)
  }

  async send(method, body) {
    const response = await fetch(this.urlValue, {
      method,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: body && JSON.stringify(body)
    })
    if (!response.ok) throw new Error(`Reminder not saved: ${response.status}`)
  }

  async currentSubscription() {
    return (await navigator.serviceWorker.ready).pushManager.getSubscription()
  }

  showOn(on) {
    this.onTarget.hidden = on
    this.offTarget.hidden = !on
  }

  say(message) {
    this.statusTarget.textContent = message
  }
}

// The server's public key, as push subscriptions want it
function fromBase64Url(text) {
  const base64 = (text + "=".repeat((4 - text.length % 4) % 4)).replace(/-/g, "+").replace(/_/g, "/")
  return Uint8Array.from(atob(base64), character => character.charCodeAt(0))
}
