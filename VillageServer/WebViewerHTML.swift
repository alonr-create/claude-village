/// Fallback embedded HTML when index.html is not found on disk
enum WebViewerHTML {
    static let content = "<!DOCTYPE html><html><head><meta charset=utf-8><title>Claude Village</title></head><body style='background:#1a2e1a;color:#fff;font-family:sans-serif;text-align:center;padding-top:100px'><h1>Claude Village Server</h1><p>Running! Place index.html in ./public/ for the full viewer.</p></body></html>"
}
