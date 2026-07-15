export function eventToUpdate(event) {
  const properties = event?.properties ?? {}
  switch (event?.type) {
    case "session.created":
      return { event: "session-start", sessionID: properties.info?.id }
    case "session.status":
      if (properties.status?.type === "busy") return { event: "prompt", sessionID: properties.sessionID }
      if (properties.status?.type === "retry") return { event: "running", sessionID: properties.sessionID }
      return null
    case "permission.asked":
    case "permission.updated":
      return {
        event: properties.type === "question" ? "question" : "permission",
        sessionID: properties.sessionID,
      }
    case "session.error":
      return { event: "failure", sessionID: properties.sessionID, payload: properties }
    case "session.deleted":
      return { event: "session-end", sessionID: properties.info?.id, payload: { reason: "exit" } }
    default:
      return null
  }
}
