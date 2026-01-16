import consumer from "./consumer"

export function subscribeToExport(exportId, callbacks) {
  return consumer.subscriptions.create(
    { channel: "ReportExportChannel", export_id: exportId },
    {
      connected() {
        console.log(`Connected to export ${exportId}`)
        if (callbacks.connected) callbacks.connected()
      },

      disconnected() {
        console.log(`Disconnected from export ${exportId}`)
        if (callbacks.disconnected) callbacks.disconnected()
      },

      received(data) {
        console.log("Received data:", data)
        if (callbacks.received) callbacks.received(data)
      }
    }
  )
}
