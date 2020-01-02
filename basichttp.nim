import asynchttpserver,
       asyncnet,
       asyncdispatch,
       htmlgen,
       httpcore,
       strutils,
       sequtils,
       json

type
  Route = object
    path: string
    name: string
    kind: HttpMethod
    fn: proc (req: Request, headers: Httpheaders): Response {.gcsafe.}
  Routes = array[4, Route]
  Response = (HttpCode, string, HttpHeaders)
  File = object
    name: string
    ext: string
    path: string
    size: int
    mime: string
    md5: string

var
  routes {.threadvar.}: Routes

proc uploadFile(req: Request): bool =
  false
  # writeFile("cats.txt", )
  # let lines = splitLines(req.body)
  # let f = open("cats.txt", fmWrite)
  # defer: f.close()

  # for i, line in pairs(lines):
  #     f.writeLine(line)
  

proc home(req: Request, headers: Httpheaders): Response =
  var
    data = form(
      input(type="file", name="file", id="file", multiple="multiple"),
      input(type="submit", name="upload", value="Upload"),
      `method`="POST",
      enctype="multipart/form-data",
      action="/upload"
    )
    headers = newHttpHeaders([("Content-Type", "text/html")])
  (Http200, data, headers)

proc parseMultiPartHeader(s: string): tuple =
  let p = s.split('=')
  (p[0], "--" & p[1])

proc parseFile(s: string): File =
  let lines = s.split("\r\n\r\n")

  for i, line in pairs(lines[0].splitLines):
    if i == 0: continue
    let head = parseHeader(line)
    

  result = File(
    name: "test",
    ext: ".txt",
    path: "text.txt",
    size: 1234,
    mime: "plain/text",
    md5: "32a2fa35bcdsg416b27asdSefgaf535t2a"
  )

proc parseMultiPartFiles(s: string, boundary: string): seq[int] =
  var lines = s.split(boundary)
  lines = lines[1..^2]

  var files: seq[File] = @[]

  echo parseFile(lines[0])

  # let f = open("cats.txt", fmWrite)
  # defer: f.close()

  # for i, line in pairs(lines):
    # echo line
    # break
    # f.writeLine(line)

  result = @[1,2,3]

proc upload(req: Request, headers: Httpheaders): Response =
  if not req.headers.hasKey("content-type"):
    return (Http400, "", headers)

  let (content, boundary) = parseMultiPartHeader(req.headers["content-type"])
  if  content != "multipart/form-data; boundary":
    return (Http400, "", headers)

  let files = parseMultiPartFiles(req.body, boundary)

  let ip = asyncnet.getPeerAddr(req.client)[0]
  let success = uploadFile(req)
  var data = `$`(%* {"upload": success})
  (Http201, data, headers)

proc fourohfour(req: Request, headers: Httpheaders): Response =
  var data = `$`(%* {"error": 404})
  (Http404, data, headers)

proc parseRoute(req: Request): Route =
  for r in routes:
    if r.path == req.url.path and r.kind == req.reqMethod:
      return r
  return routes[0]

proc processRequest(req: Request): Response =
  let
    route = parseRoute(req)
    headers = newHttpHeaders([("Content-Type","application/json")])
  route.fn(req, headers)

proc asyncHttpHandler(req: Request) {.async.} =
  let (status, data, headers) = processRequest(req)
  await req.respond(status, data, headers)

when isMainModule:
  routes = [
    Route(path: "/404",    name: "404",    kind: HttpGet,  fn: fourohfour),
    Route(path: "/",       name: "root",   kind: HttpGet,  fn: home),
    Route(path: "/home",   name: "home",   kind: HttpGet,  fn: home),
    Route(path: "/upload", name: "upload", kind: HttpPost, fn: upload)
  ]

  var server = newAsyncHttpServer()
  waitFor server.serve(Port(6000), asyncHttpHandler)
