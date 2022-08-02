import tang.*
from net import http.Server, http.ResponseWriteStream
from std import time.Duration

func debugHandle(w:ResponseWriteStream, r:Request) {
    w.writeStatusCode(200)
    w.write("hello world".toUtf8Array())
    ()
}

main() {
    let r = Router()
    r.group.withGroup("/api", {group =>
        group.get("/user/:id", debugHandle)
        // group.get("/user/current", debugHandle)
        group.get("/user/*path", debugHandle)
    })
    println("listening on http://localhost:10000")
    let srv = Server(r)
    srv.port = 10000
    srv.readTimeout = Duration.second(10) /* Secend */
    srv.writeTimeout = Duration.second(10) /* Secend */
    srv.listenAndServe()
}