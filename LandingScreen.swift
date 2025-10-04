.task {
    // For device testing:
    // ReadARAPI.baseURL = URL(string: "http://192.168.1.23:5055")!

    let _ = await ReadARAPI.health()
    let _ = await ReadARAPI.features()
    let _ = await ReadARAPI.define("focus")
}
