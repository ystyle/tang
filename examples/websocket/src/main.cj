package websocket

import tang.*
import tang.websocket.{websocket, WebSocketConn}

/// WebSocket 回显服务
///
/// 浏览器控制台里：
///   const ws = new WebSocket("ws://127.0.0.1:10000/ws")
///   ws.onmessage = e => console.log(e.data)
///   ws.onopen = () => ws.send("hello")
main() {
    let app = Tang([
        withHost("127.0.0.1"),
        withPort(10000u16),
        withShowBanner(),
        withShowRoutes()
    ])

    app.get("/ws", websocket({ conn: WebSocketConn =>
        conn.writeText("connected")
        while (true) {
            match (conn.readMessage()) {
                case Some(msg) => conn.writeText("echo:" + msg.text())
                case None => break
            }
        }
    }))

    app.listen()
}
